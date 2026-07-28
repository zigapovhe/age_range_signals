import Flutter
import UIKit

#if canImport(Synchronization)
import Synchronization
#endif

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
        case "requestAgeSignalsAccess":
            // Play's separate access grant has no Apple counterpart: consent
            // is gathered by requestAgeRange() inside checkAgeSignals, and a
            // refusal surfaces there as the "declined" status. "shared" is
            // the honest answer and keeps one call sequence working on both
            // platforms.
            result("shared")
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
                    result(self.ageRangeResultMap(status: "declined"))

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

                    result(self.ageRangeResultMap(
                        status: status,
                        ageLower: range.lowerBound,
                        ageUpper: range.upperBound,
                        source: source,
                        activeParentalControls: parentalControls.isEmpty ? nil : parentalControls
                    ))

                @unknown default:
                    result(FlutterError(
                        code: "UNKNOWN_ERROR",
                        message: "Unknown DeclaredAgeRange response",
                        details: nil
                    ))
                }
            } catch AgeRangeService.Error.notAvailable {
                // Apple throws this when age range sharing is not available
                // for the user, region, or account state; unentitled apps
                // can surface it too. Earlier versions guessed
                // MISSING_ENTITLEMENT from its raw error code (0), which
                // misled on correctly entitled devices.
                result(FlutterError(
                    code: "API_NOT_AVAILABLE",
                    message: "Age range sharing is not available for this user or region. If you expected it to be available, confirm the app is signed with the declared-age-range entitlement.",
                    details: nil
                ))
            } catch {
                let nsError = error as NSError
                let errorMessage = error.localizedDescription
                let errorDomain = nsError.domain
                let errorCode = nsError.code

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

                let likelyEntitlementError = errorMessage.lowercased().contains("entitlement") ||
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

    /// Builds the channel map for a checkAgeSignals response. Single place
    /// that owns the map shape, so the response variants cannot drift apart
    /// (Android has the same guarantee via resultToMap). Android-only keys
    /// are present but always NSNull on iOS.
    private func ageRangeResultMap(
        status: String,
        ageLower: Int? = nil,
        ageUpper: Int? = nil,
        source: String? = nil,
        activeParentalControls: [String]? = nil
    ) -> [String: Any] {
        return [
            "status": status,
            "ageLower": ageLower as Any? ?? NSNull(),
            "ageUpper": ageUpper as Any? ?? NSNull(),
            "source": source as Any? ?? NSNull(),
            "installId": NSNull(),
            "activeParentalControls": activeParentalControls as Any? ?? NSNull(),
            "ageRangeSource": NSNull(),
            "significantChangeStatus": NSNull(),
            "significantChangeApprovalDate": NSNull()
        ]
    }

    #if canImport(DeclaredAgeRange)
    /// Translates Apple's ParentalControls option set into stable string
    /// identifiers for the channel. Flags this plugin version does not know
    /// are omitted; an OptionSet has no stable name for unknown bits, so
    /// passing them through would leak an unstable debug description.
    @available(iOS 26.0, *)
    private func parentalControlNames(_ controls: AgeRangeService.ParentalControls) -> [String] {
        var names: [String] = []
        if controls.contains(.communicationLimits) {
            names.append("communicationLimits")
        }
        // The flag exists from the iOS 26.2 SDK; Xcode 26.2 is the first to
        // ship Swift 6.2.3, so this guard compiles it in on Xcode 26.2+ and
        // out on 26.0/26.1 whose SDKs lack the symbol. Deprecated in the
        // 26.4 SDK in favor of requiredRegulatoryFeatures, but still the
        // only source of this signal on iOS 26.2 and 26.3 devices, so we
        // keep reporting it.
        #if compiler(>=6.2.3)
        if #available(iOS 26.2, *) {
            if controls.contains(.significantAppChangeApprovalRequired) {
                names.append("significantAppChangeApprovalRequired")
            }
        }
        #endif
        return names
    }
    #endif

    #if canImport(Synchronization)
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
            // Resumes the continuation at most once; the signature guarantees
            // every winner resumes, so the continuation cannot leak.
            @Sendable func resumeOnce(with result: Result<T, any Error>) -> Bool {
                let isFirst = resumed.withLock { alreadyResumed -> Bool in
                    if alreadyResumed { return false }
                    alreadyResumed = true
                    return true
                }
                if isFirst { continuation.resume(with: result) }
                return isFirst
            }

            // The sleeper starts first so the operation can always cancel it
            // the moment it wins, instead of letting it hold the continuation
            // machinery for the full deadline.
            let operationTaskBox = Mutex<Task<Void, Never>?>(nil)
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let timeout = NSError(domain: "AgeRangeSignals", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Timed out after \(seconds)s"
                ])
                if resumeOnce(with: .failure(timeout)) {
                    operationTaskBox.withLock { $0?.cancel() }
                }
            }
            let operationTask = Task {
                let outcome: Result<T, any Error>
                do {
                    outcome = .success(try await operation())
                } catch {
                    outcome = .failure(error)
                }
                if resumeOnce(with: outcome) {
                    timeoutTask.cancel()
                }
            }
            operationTaskBox.withLock { $0 = operationTask }
        }
    }
    #endif

    private func handleGetRequiredRegulatoryFeatures(result: @escaping FlutterResult) {
        #if canImport(DeclaredAgeRange) && compiler(>=6.3)
        if #available(iOS 26.4, *) {
            Task { @MainActor in
                do {
                    let features = try await self.withDeadline(seconds: 10) {
                        try await AgeRangeService.shared.requiredRegulatoryFeatures
                    }
                    let names: [String] = features.compactMap { feature in
                        switch feature {
                        case .declaredAgeRangeRequired:
                            return "declaredAgeRangeRequired"
                        case .significantAppChangeRequiresAdultNotification:
                            return "significantAppChangeRequiresAdultNotification"
                        case .significantAppChangeRequiresParentalConsent:
                            return "significantAppChangeRequiresParentalConsent"
                        @unknown default:
                            // Dart maps these names onto a closed enum and
                            // drops anything it does not know, so omitting
                            // future cases here keeps the two layers agreed.
                            return nil
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
        // Below iOS 26.4, or built with an SDK that predates the API, we
        // cannot know what is required. Erroring keeps "empty set" reserved
        // for Apple affirmatively reporting that nothing is required, so a
        // compliance flow can never mistake "could not check" for "none".
        result(FlutterError(
            code: "UNSUPPORTED_PLATFORM",
            message: "Regulatory features require iOS 26.4 and an app built with the iOS 26.4 SDK",
            details: nil
        ))
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
        if let scene = activeWindowScene(),
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
