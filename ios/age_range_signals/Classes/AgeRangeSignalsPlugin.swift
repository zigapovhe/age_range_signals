import Flutter
import Synchronization
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
        case "getRequiredRegulatoryFeatures":
            handleGetRequiredRegulatoryFeatures(result: result)
        case "showSignificantUpdateAcknowledgment":
            handleShowSignificantUpdateAcknowledgment(call: call, result: result)
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
            // Note: we deliberately do NOT gate on AgeRangeService.isEligibleForAgeFeatures
            // (iOS 26.2+). In the current OS window that property is unreliable — it can
            // hang indefinitely (with no timeout the whole call would hang) and it returns
            // false before the user has ever accepted a prompt, only updating on a later
            // relaunch (reported on the Apple Developer Forums, threads 807906 & 809829).
            // Apple's own guidance is to call requestAgeRange() directly, which is the
            // source of truth, so that is what we do here.
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
                        "installId": NSNull(),
                        "activeParentalControls": NSNull(),
                        "mostRecentApprovalDate": NSNull()
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

                    let parentalControls = self.parentalControlNames(range.activeParentalControls)

                    result([
                        "status": status,
                        "ageLower": range.lowerBound as Any? ?? NSNull(),
                        "ageUpper": range.upperBound as Any? ?? NSNull(),
                        "source": source as Any? ?? NSNull(),
                        "installId": NSNull(),
                        "activeParentalControls": parentalControls.isEmpty
                            ? NSNull() : parentalControls,
                        "mostRecentApprovalDate": NSNull()
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

    #if canImport(DeclaredAgeRange)
    /// Translates Apple's ParentalControls option set into stable string
    /// identifiers for the channel. Flags this build does not know about are
    /// passed through via their description so they are not silently dropped.
    @available(iOS 26.0, *)
    private func parentalControlNames(_ controls: AgeRangeService.ParentalControls) -> [String] {
        var names: [String] = []
        var known: AgeRangeService.ParentalControls = [.communicationLimits]
        if controls.contains(.communicationLimits) {
            names.append("communicationLimits")
        }
        #if compiler(>=6.3)
        // Deprecated in the 26.4 SDK in favor of requiredRegulatoryFeatures,
        // but still the only source of this signal on iOS 26.2 and 26.3
        // devices, so we keep reporting it.
        if #available(iOS 26.2, *) {
            known.insert(.significantAppChangeApprovalRequired)
            if controls.contains(.significantAppChangeApprovalRequired) {
                names.append("significantAppChangeApprovalRequired")
            }
        }
        #endif
        let unknown = controls.subtracting(known)
        if !unknown.isEmpty {
            names.append(unknown.description)
        }
        return names
    }
    #endif

    /// Races an async operation against a deadline. Apple's age-assurance
    /// properties have a history of hanging (isEligibleForAgeFeatures on
    /// 26.2, Apple forums threads 807906 & 809829), so every non-UI call we
    /// make gets a deadline instead of trusting the OS to return.
    ///
    /// Deliberately NOT a task group race: a throwing task group awaits all
    /// children before propagating the timeout error, so a hung Apple call
    /// that ignores cancellation would hang the group too (verified on the
    /// iOS 26.4 simulator). The continuation resumes on whichever side
    /// finishes first and abandons the loser.
    @available(iOS 26.0, *)
    private func withDeadline<T: Sendable>(
        seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
            let resumed = Mutex(false)
            @Sendable func resumeOnce(_ resume: () -> Void) {
                let isFirst = resumed.withLock { alreadyResumed -> Bool in
                    if alreadyResumed { return false }
                    alreadyResumed = true
                    return true
                }
                if isFirst { resume() }
            }

            let operationTask = Task {
                do {
                    let value = try await operation()
                    resumeOnce { continuation.resume(returning: value) }
                } catch {
                    resumeOnce { continuation.resume(throwing: error) }
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                resumeOnce {
                    operationTask.cancel()
                    continuation.resume(throwing: NSError(domain: "AgeRangeSignals", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Timed out after \(seconds)s"
                    ]))
                }
            }
        }
    }

    private func handleGetRequiredRegulatoryFeatures(result: @escaping FlutterResult) {
        #if canImport(DeclaredAgeRange) && compiler(>=6.3)
        if #available(iOS 26.4, *) {
            Task { @MainActor in
                do {
                    let features = try await self.withDeadline(seconds: 10) {
                        try await AgeRangeService.shared.requiredRegulatoryFeatures
                    }
                    let names: [String] = features.map { feature in
                        switch feature {
                        case .declaredAgeRangeRequired:
                            return "declaredAgeRangeRequired"
                        case .significantAppChangeRequiresAdultNotification:
                            return "significantAppChangeRequiresAdultNotification"
                        case .significantAppChangeRequiresParentalConsent:
                            return "significantAppChangeRequiresParentalConsent"
                        @unknown default:
                            return String(describing: feature)
                        }
                    }
                    result(names)
                } catch AgeRangeService.Error.notAvailable {
                    // Documented: "notAvailable if the regulatory feature's
                    // service is unavailable."
                    result(FlutterError(
                        code: "API_NOT_AVAILABLE",
                        message: "The regulatory features service is unavailable",
                        details: nil
                    ))
                } catch {
                    let nsError = error as NSError
                    result(FlutterError(
                        code: "API_ERROR",
                        message: "requiredRegulatoryFeatures failed: \(error.localizedDescription)",
                        details: "Domain: \(nsError.domain) | Code: \(nsError.code)"
                    ))
                }
            }
            return
        }
        #endif
        // Below iOS 26.4, or built with an SDK that predates the API:
        // nothing is required, by definition of "we cannot know". Returning
        // an empty list (not an error) keeps the Dart contract simple.
        result([String]())
    }

    private func handleShowSignificantUpdateAcknowledgment(call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if canImport(DeclaredAgeRange) && compiler(>=6.3)
        if #available(iOS 26.4, *) {
            guard let args = call.arguments as? [String: Any],
                  let updateDescription = args["updateDescription"] as? String,
                  !updateDescription.isEmpty else {
                result(FlutterError(
                    code: "API_ERROR",
                    message: "updateDescription must be a non-empty string",
                    details: nil
                ))
                return
            }
            guard let windowScene = activeWindowScene() else {
                result(FlutterError(
                    code: "PRESENTATION_CONTEXT_UNAVAILABLE",
                    message: "Unable to find an active window scene to present the acknowledgment sheet",
                    details: nil
                ))
                return
            }
            Task { @MainActor in
                do {
                    try await AgeRangeService.shared.showSignificantUpdateAcknowledgment(
                        in: windowScene,
                        updateDescription: updateDescription
                    )
                    result(nil)
                } catch is CancellationError {
                    result(FlutterError(
                        code: "USER_CANCELLED",
                        message: "The acknowledgment was cancelled",
                        details: nil
                    ))
                } catch AgeRangeService.Error.notAvailable {
                    // Apple documents no cancellation error for this sheet;
                    // its pattern elsewhere in the framework is to surface a
                    // person's refusal as notAvailable, so this can mean
                    // either "service unavailable" or "person dismissed it".
                    result(FlutterError(
                        code: "API_NOT_AVAILABLE",
                        message: "The acknowledgment is unavailable or the person dismissed it",
                        details: nil
                    ))
                } catch {
                    let nsError = error as NSError
                    if error.localizedDescription.lowercased().contains("cancel") {
                        result(FlutterError(
                            code: "USER_CANCELLED",
                            message: "User dismissed the acknowledgment sheet",
                            details: "Domain: \(nsError.domain) | Code: \(nsError.code)"
                        ))
                    } else {
                        result(FlutterError(
                            code: "API_ERROR",
                            message: "showSignificantUpdateAcknowledgment failed: \(error.localizedDescription)",
                            details: "Domain: \(nsError.domain) | Code: \(nsError.code)"
                        ))
                    }
                }
            }
            return
        }
        #endif
        result(FlutterError(
            code: "UNSUPPORTED_PLATFORM",
            message: "Significant update acknowledgment requires iOS 26.4 and an app built with the iOS 26.4 SDK",
            details: nil
        ))
    }

    /// Finds the foreground-active window scene; the significant update
    /// acknowledgment sheet presents on a scene, not a view controller.
    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
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
