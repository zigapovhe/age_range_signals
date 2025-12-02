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
        if let args = call.arguments as? [String: Any] {
            if let gates = args["ageGates"] as? [Int] {
                ageGates = gates.sorted()
            }
            // useMockData parameter is ignored on iOS (no mock implementation yet)
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

        guard let presenter = presentationViewController() else {
            result(FlutterError(
                code: "PRESENTATION_CONTEXT_UNAVAILABLE",
                message: "Unable to find a view controller to present age verification",
                details: nil
            ))
            return
        }

        Task { @MainActor in
            do {
                let response: AgeRangeService.Response

                switch ageGates.count {
                case 1:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: ageGates[0],
                        in: presenter
                    )
                case 2:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: ageGates[0],
                        ageGates[1],
                        in: presenter
                    )
                case 3:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: ageGates[0],
                        ageGates[1],
                        ageGates[2],
                        in: presenter
                    )
                default:
                    result(FlutterError(
                        code: "INVALID_AGE_GATES",
                        message: "DeclaredAgeRange supports 1 to 3 age gates",
                        details: nil
                    ))
                    return
                }

                switch response {
                case .declinedSharing:
                    result([
                        "status": "declined",
                        "ageLower": NSNull(),
                        "ageUpper": NSNull(),
                        "source": NSNull(),
                        "installId": NSNull()
                    ])

                case .sharing(let range):
                    let source: String?
                    switch range.source {
                    case .selfDeclared:
                        source = "selfDeclared"
                    case .guardianDeclared:
                        source = "guardianDeclared"
                    default:
                        source = nil
                    }

                    // Determine status based on highest configured age gate
                    let highestGate = ageGates.max() ?? 0
                    let lowerBound = range.lowerBound ?? 0

                    // User is verified if they meet or exceed the highest age gate
                    // Otherwise supervised (may be under supervision or below threshold)
                    let status = lowerBound >= highestGate ? "verified" : "supervised"

                    result([
                        "status": status,
                        "ageLower": range.lowerBound as Any? ?? NSNull(),
                        "ageUpper": range.upperBound as Any? ?? NSNull(),
                        "source": source as Any? ?? NSNull(),
                        "installId": NSNull()
                    ])

                @unknown default:
                    result(FlutterError(
                        code: "UNKNOWN_ERROR",
                        message: "Unknown DeclaredAgeRange response",
                        details: nil
                    ))
                }
            } catch {
                result(FlutterError(
                    code: "UNKNOWN_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
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

    /// Finds a view controller suitable for presenting the age range prompt.
    private func presentationViewController() -> UIViewController? {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        if let root = UIApplication.shared.keyWindow?.rootViewController {
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        return nil
    }
}
