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
            // Note: useMockData and mockData are ignored on iOS
            // Apple provides no official testing utilities for DeclaredAgeRange API
            // mockData is only supported on Android via Google's FakeAgeSignalsManager
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
            // Check if user is eligible for age features (iOS 26.2+)
            // Returns unknown status if user is outside applicable region
            if #available(iOS 26.2, *) {
                do {
                    let isEligible = try await AgeRangeService.shared.isEligibleForAgeFeatures
                    if !isEligible {
                        result([
                            "status": "unknown",
                            "ageLower": NSNull(),
                            "ageUpper": NSNull(),
                            "source": NSNull(),
                            "installId": NSNull()
                        ])
                        return
                    }
                } catch {
                    // If eligibility check fails (missing entitlement, error, etc.),
                    // continue to main API call which will provide appropriate error
                }
            }

            do {
                let response: AgeRangeService.Response
                switch self.ageGates.count {
                case 1:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: self.ageGates[0],
                        in: presenter
                    )
                case 2:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: self.ageGates[0],
                        self.ageGates[1],
                        in: presenter
                    )
                case 3:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: self.ageGates[0],
                        self.ageGates[1],
                        self.ageGates[2],
                        in: presenter
                    )
                default:
                    throw NSError(domain: "AgeRangeSignals", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "DeclaredAgeRange supports 1 to 3 age gates"
                    ])
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
                    switch range.ageRangeDeclaration {
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
                let nsError = error as NSError
                let errorMessage = error.localizedDescription
                let errorDomain = nsError.domain
                let errorCode = nsError.code

                // Check for specific error types
                let isDeclaredAgeRangeError = errorDomain.contains("DeclaredAgeRange") ||
                                             errorDomain.contains("AgeRangeService")

                // User cancelled the prompt
                if errorDomain == NSCocoaErrorDomain && errorCode == 3072 ||
                   errorMessage.lowercased().contains("cancel") ||
                   errorMessage.lowercased().contains("user abort") {
                    result(FlutterError(
                        code: "USER_CANCELLED",
                        message: "User cancelled the age verification prompt",
                        details: "Error: \(errorMessage) | Domain: \(errorDomain) | Code: \(errorCode)"
                    ))
                    return
                }

                // Entitlement error (error code 0 with DeclaredAgeRange domain)
                let likelyEntitlementError = (errorCode == 0 && isDeclaredAgeRangeError) ||
                                            errorMessage.lowercased().contains("entitlement") ||
                                            errorMessage.lowercased().contains("not entitled")

                if likelyEntitlementError {
                    result(FlutterError(
                        code: "MISSING_ENTITLEMENT",
                        message: "DeclaredAgeRange API error (likely missing entitlement). Ensure the 'com.apple.developer.declared-age-range' entitlement is added to your app and approved by Apple.",
                        details: "Error: \(errorMessage) | Domain: \(errorDomain) | Code: \(errorCode)"
                    ))
                    return
                }

                // Network errors
                if errorDomain == NSURLErrorDomain ||
                   errorMessage.lowercased().contains("network") ||
                   errorMessage.lowercased().contains("connection") {
                    result(FlutterError(
                        code: "NETWORK_ERROR",
                        message: "Network error: \(errorMessage)",
                        details: "Domain: \(errorDomain) | Code: \(errorCode)"
                    ))
                    return
                }

                // Generic API error
                result(FlutterError(
                    code: "API_ERROR",
                    message: "DeclaredAgeRange API error: \(errorMessage)",
                    details: "Domain: \(errorDomain) | Code: \(errorCode)"
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
