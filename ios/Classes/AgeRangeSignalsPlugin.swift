import Flutter
import UIKit

#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

public class AgeRangeSignalsPlugin: NSObject, FlutterPlugin {
    private var ageGates: [Int] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "age_range_signals", binaryMessenger: registrar.messenger())
        let instance = AgeRangeSignalsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "checkAgeSignals":
            handleCheckAgeSignals(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let gates = args["ageGates"] as? [Int] {
            ageGates = gates.sorted()
        }
        result(nil)
    }

    private func handleCheckAgeSignals(result: @escaping FlutterResult) {
        if #available(iOS 26.0, *) {
            #if canImport(DeclaredAgeRange)
            checkDeclaredAgeRange(result: result)
            #else
            result(FlutterError(
                code: "UNSUPPORTED_PLATFORM",
                message: "DeclaredAgeRange API requires iOS 26.0 or later",
                details: nil
            ))
            #endif
        } else {
            result(FlutterError(
                code: "UNSUPPORTED_PLATFORM",
                message: "This feature requires iOS 26.0 or later",
                details: nil
            ))
        }
    }

    @available(iOS 26.0, *)
    private func checkDeclaredAgeRange(result: @escaping FlutterResult) {
        #if canImport(DeclaredAgeRange)
        guard !ageGates.isEmpty else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Age gates not configured. Call initialize() first with age gates.",
                details: nil
            ))
            return
        }

        Task {
            do {
                let response = try await requestAgeRange(ageGates: ageGates)

                switch response {
                case .declinedSharing:
                    await MainActor.run {
                        result([
                            "status": "declined",
                            "ageLower": NSNull(),
                            "ageUpper": NSNull(),
                            "source": NSNull(),
                            "installId": NSNull()
                        ])
                    }

                case .sharing(let range):
                    let source: String
                    switch range.source {
                    case .selfDeclared:
                        source = "selfDeclared"
                    case .guardianDeclared:
                        source = "guardianDeclared"
                    @unknown default:
                        source = "selfDeclared"
                    }

                    let highestGate = ageGates.max() ?? 0
                    let status = range.lowerBound >= highestGate ? "verified" : "supervised"

                    await MainActor.run {
                        result([
                            "status": status,
                            "ageLower": range.lowerBound,
                            "ageUpper": range.upperBound,
                            "source": source,
                            "installId": NSNull()
                        ])
                    }
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "UNKNOWN_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
        #else
        result(FlutterError(
            code: "UNSUPPORTED_PLATFORM",
            message: "DeclaredAgeRange not available",
            details: nil
        ))
        #endif
    }

    @available(iOS 26.0, *)
    private func requestAgeRange(ageGates: [Int]) async throws -> DeclaredAgeRangeResponse {
        #if canImport(DeclaredAgeRange)
        return try await DeclaredAgeRange.requestAgeRange(ageGates: ageGates)
        #else
        throw NSError(domain: "AgeRangeSignals", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "DeclaredAgeRange not available"
        ])
        #endif
    }
}
