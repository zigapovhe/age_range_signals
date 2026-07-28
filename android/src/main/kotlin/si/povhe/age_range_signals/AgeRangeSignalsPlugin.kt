package si.povhe.age_range_signals

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsAccessResult
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.model.AgeRangeSource
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.SignificantChangeStatus
import com.google.android.play.agesignals.testing.FakeAgeSignalsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Date

/**
 * Android implementation backed by the Play Age Signals API 0.0.4.
 *
 * 0.0.4 replaced the single `userStatus` verdict with three orthogonal facts:
 * a sharing status from [AgeSignalsManager.requestAgeSignalsAccess], an
 * assurance tier ([AgeRangeSource]) and an app-version approval state
 * ([SignificantChangeStatus]). This plugin derives the cross-platform
 * `status` from all three and passes the tier through as `source` so callers
 * that care about assurance level do not lose it.
 */
class AgeRangeSignalsPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var ageSignalsManager: AgeSignalsManager? = null
    private var activity: Activity? = null
    private var useFakeManager = false
    private var mockData: Map<String, Any?>? = null

    /// The age at or above which a user counts as `verified`. Taken from the
    /// caller's highest configured gate so Android and iOS agree; Play itself
    /// does not use age gates, and its open-ended top band starts at 18.
    private var adultThreshold = DEFAULT_ADULT_AGE

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "age_range_signals")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext

        try {
            ageSignalsManager = AgeSignalsManagerFactory.create(context)
            useFakeManager = false
        } catch (e: Exception) {
            // Manager initialization can fail if Play Services isn't available
            ageSignalsManager = null
            useFakeManager = false
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    /**
     * Whether mock data must be refused. Split out from [isDebuggable] so the
     * rule is unit-testable without an Android [Context].
     */
    internal fun shouldRejectMockData(
        useMockData: Boolean,
        debuggable: () -> Boolean
    ): Boolean = useMockData && !debuggable()

    private fun isDebuggable(): Boolean =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun createFakeManager(): AgeSignalsManager {
        val fakeManager = FakeAgeSignalsManager()
        fakeManager.setNextAgeSignalsAccessResult(buildMockAccessResult(mockData))
        fakeManager.setNextAgeSignalsResult(buildMockResult(mockData))
        return fakeManager
    }

    /**
     * Builds the [AgeSignalsAccessResult] the fake manager returns from the
     * first leg of the two-step flow. Mock statuses that describe a user who
     * never shared map to the matching access status; everything else is a
     * user who shared, so the mocked signals are reachable.
     */
    internal fun buildMockAccessResult(mockDataMap: Map<String, Any?>?): AgeSignalsAccessResult {
        val statusString = mockDataMap?.get("status") as? String ?: "supervised"
        val accessStatus = when (statusString) {
            "declined" -> AgeSignalsStatus.NOT_SHARED
            "unknown" -> AgeSignalsStatus.NOT_SHARED
            "verificationRequired" -> AgeSignalsStatus.VERIFICATION_REQUIRED
            else -> AgeSignalsStatus.SHARED
        }
        return AgeSignalsAccessResult.builder()
            .setAgeSignalsStatus(accessStatus)
            .build()
    }

    /**
     * Builds the [AgeSignalsResult] returned by the fake manager from the optional
     * mock data map. Extracted from [createFakeManager] so the mapping logic is
     * unit-testable without the async Task layer.
     *
     * IMPORTANT: Age ranges are determined by Google Play's parental control settings,
     * NOT by the app's configured age gates. Android ignores the ageGates parameter -
     * it's iOS-only. Google Play returns predefined bands: 0-12, 13-15, 16-17, 18+.
     */
    internal fun buildMockResult(mockDataMap: Map<String, Any?>?): AgeSignalsResult {
        // Default to a supervised user (13-15) for backwards compatibility when no
        // custom mock data is supplied.
        val statusString = mockDataMap?.get("status") as? String ?: "supervised"

        // The mocked status implies an assurance tier unless one is given
        // explicitly, so existing mocks keep behaving the way they read.
        val explicitSource = mockDataMap?.get("source") as? String
        val ageRangeSource = when (explicitSource) {
            "selfDeclared" -> AgeRangeSource.TIER_A
            "guardianDeclared" -> AgeRangeSource.TIER_B
            "estimated" -> AgeRangeSource.TIER_C
            "idVerified" -> AgeRangeSource.TIER_D
            else -> when (statusString) {
                "verified" -> AgeRangeSource.TIER_D
                "declared" -> AgeRangeSource.TIER_A
                else -> AgeRangeSource.TIER_B
            }
        }

        val significantChangeStatus = when (statusString) {
            "supervisedApprovalPending" -> SignificantChangeStatus.PENDING
            "supervisedApprovalDenied" -> SignificantChangeStatus.DECLINED
            else -> SignificantChangeStatus.APPROVED
        }

        val resultBuilder = AgeSignalsResult.builder()
            .setAgeRangeSource(ageRangeSource)
            .setSignificantChangeStatus(significantChangeStatus)

        // A verified (18+) mock has an open-ended top band; everything else
        // carries an explicit range.
        if (statusString == "verified") {
            val ageLowerRaw = mockDataMap?.get("ageLower") as? Int
            resultBuilder.setAgeLower(ageLowerRaw ?: 18)
            (mockDataMap?.get("ageUpper") as? Int)?.let { resultBuilder.setAgeUpper(it) }
        } else if (statusString != "unknown" && statusString != "declined") {
            val ageLowerRaw = mockDataMap?.get("ageLower") as? Int
            resultBuilder.setAgeLower(ageLowerRaw ?: 13)

            // Two cases produce a null ageUpper, distinguished by whether an explicit
            // lower bound was given (the only signal that survives the Dart->map
            // boundary, since toMap always includes the ageUpper key as null):
            //  - explicit ageLower + omitted ageUpper -> open-ended top bucket
            //    (e.g. ageLower=18, ageUpper=null), intentionally left unset
            //  - no ageLower (no mock data at all, or a partial mock omitting both
            //    bounds) -> apply the default supervised band (13-15)
            val ageUpperRaw = mockDataMap?.get("ageUpper") as? Int
            if (ageUpperRaw != null) {
                resultBuilder.setAgeUpper(ageUpperRaw)
            } else if (ageLowerRaw == null) {
                resultBuilder.setAgeUpper(15)
            }
        }

        // installId is set for supervised (guardian-attested) users.
        if (ageRangeSource == AgeRangeSource.TIER_B) {
            val installId = mockDataMap?.get("installId") as? String ?: "test_install_id_12345"
            resultBuilder.setInstallId(installId)
        }

        (mockDataMap?.get("significantChangeApprovalDate") as? Number)?.let {
            resultBuilder.setSignificantChangeApprovalDate(Date(it.toLong()))
        }

        return resultBuilder.build()
    }

    /**
     * Derives the cross-platform status from the 0.0.4 signals.
     *
     * `supervised` means "below the adult threshold" here, matching the iOS
     * meaning (a declared range that does not clear the configured gates), so
     * an unsupervised minor is reported as `supervised` with a `source` that
     * says how the age was established.
     */
    internal fun deriveStatus(
        accessStatus: Int?,
        result: AgeSignalsResult?,
        threshold: Int = adultThreshold
    ): String {
        when (accessStatus) {
            // Play uses NOT_SHARED both for a user who refused and for one who
            // was never asked because their region is out of scope. Those are
            // indistinguishable here, and reporting `declined` would assert an
            // intent the user may never have expressed, so this is `unknown`.
            AgeSignalsStatus.NOT_SHARED -> return "unknown"
            AgeSignalsStatus.VERIFICATION_REQUIRED -> return "verificationRequired"
            AgeSignalsStatus.UNSPECIFIED, null -> return "unknown"
        }

        if (result == null) return "unknown"

        // Only a guardian-attested user is supervised, and the app-version
        // approval state describes that guardian relationship, so it is read
        // inside this branch. Reading it first would let a pending approval
        // relabel an unsupervised adult as a supervised minor.
        if (result.ageRangeSource() == AgeRangeSource.TIER_B) {
            // An outstanding guardian decision is actionable whatever the age,
            // so it wins. Otherwise fall through to the same age comparison
            // every other tier uses: supervision is reported through `source`,
            // not by overriding the verdict, so one `status` check means the
            // same thing here as it does on iOS.
            when (result.significantChangeStatus()) {
                SignificantChangeStatus.PENDING -> return "supervisedApprovalPending"
                SignificantChangeStatus.DECLINED -> return "supervisedApprovalDenied"
            }
        }

        // Every other tier is unsupervised, including one this version does not
        // recognise. The verdict comes from the reported range and `source`
        // carries the assurance level, so a self-declared adult and an
        // ID-verified adult are both `verified` and the caller decides whether
        // the assurance is good enough.
        val lower = result.ageLower() ?: return "unknown"
        return if (lower >= threshold) "verified" else "supervised"
    }

    /** Maps the 0.0.4 assurance tier onto the cross-platform `source` value. */
    internal fun sourceToName(ageRangeSource: Int?): String? = when (ageRangeSource) {
        AgeRangeSource.TIER_A -> "selfDeclared"
        AgeRangeSource.TIER_B -> "guardianDeclared"
        AgeRangeSource.TIER_C -> "estimated"
        AgeRangeSource.TIER_D -> "idVerified"
        else -> null
    }

    /**
     * Maps a platform [AgeSignalsResult] to the channel map consumed by Dart.
     * Shared by the real and fake manager listeners so the two paths cannot
     * drift apart. iOS-only keys are present but always null on Android.
     */
    internal fun resultToMap(
        ageSignalsResult: AgeSignalsResult?,
        accessStatus: Int?
    ): Map<String, Any?> {
        return mapOf(
            "status" to deriveStatus(accessStatus, ageSignalsResult),
            "installId" to ageSignalsResult?.installId(),
            "ageLower" to ageSignalsResult?.ageLower(),
            "ageUpper" to ageSignalsResult?.ageUpper(),
            "source" to sourceToName(ageSignalsResult?.ageRangeSource()),
            "activeParentalControls" to null,
            "significantChangeApprovalDate" to
                ageSignalsResult?.significantChangeApprovalDate()?.time
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val useMockData = call.argument<Boolean>("useMockData") ?: false

                // FakeAgeSignalsManager forges age signals. Shipping a release
                // that can forge its own age gate is the failure mode this
                // plugin exists to prevent, so refuse rather than quietly
                // handing back fabricated signals to real users.
                if (shouldRejectMockData(useMockData, ::isDebuggable)) {
                    result.error(
                        "MOCK_DATA_NOT_ALLOWED",
                        "useMockData is only available in debuggable builds. " +
                            "FakeAgeSignalsManager forges age signals, so it must not " +
                            "be reachable by real users.",
                        null
                    )
                    return
                }

                useFakeManager = useMockData
                // Store mock data for use when creating fake manager
                mockData = call.argument<Map<String, Any?>>("mockData")
                // Play ignores age gates, but the caller's highest gate is what
                // iOS compares against, so honouring it here keeps one `status`
                // check from meaning two different things per platform.
                adultThreshold =
                    call.argument<List<Int>>("ageGates")?.maxOrNull() ?: DEFAULT_ADULT_AGE
                result.success(null)
            }
            "checkAgeSignals" -> {
                checkAgeSignals(result)
            }
            "getRequiredRegulatoryFeatures" -> {
                // Apple-only concept. Play Age Signals has no regulatory
                // feature flags; it limits itself to covered regions
                // implicitly, so there is never anything to report here.
                result.success(emptyList<String>())
            }
            "showSignificantUpdateAcknowledgment" -> {
                result.error(
                    "UNSUPPORTED_PLATFORM",
                    "Significant update acknowledgment is an iOS 26.4+ system sheet; Android has no equivalent",
                    null
                )
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun checkAgeSignals(result: Result) {
        // If the user explicitly requested mock data, use the fake manager.
        // This runs before the real-manager null check so mock mode works even
        // when Play Services / the real Age Signals API is unavailable.
        val manager = if (useFakeManager) createFakeManager() else ageSignalsManager

        if (manager == null) {
            result.error(
                "API_NOT_AVAILABLE",
                "Age Signals API is not available on this device",
                null
            )
            return
        }

        // AgeSignalsAccessRequest.Builder.build() throws IllegalStateException
        // ("Missing required properties: activity") when no Activity is set, so
        // this guard covers mock mode too even though the fake manager never
        // presents UI.
        val hostActivity = activity
        if (hostActivity == null) {
            result.error(
                "PRESENTATION_CONTEXT_UNAVAILABLE",
                "No Activity available to present the Play age sharing prompt",
                null
            )
            return
        }

        val accessRequest = AgeSignalsAccessRequest.builder()
            .setActivity(hostActivity)
            .build()

        // The second call is dispatched from a Task callback, outside the
        // synchronous onMethodCall body that Flutter wraps in try/catch, so a
        // throw there would strand the Dart Future. Guard it explicitly.
        manager.requestAgeSignalsAccess(accessRequest)
            .addOnSuccessListener { accessResult ->
                val accessStatus = accessResult.ageSignalsStatus()

                // Only a SHARED user has signals to read; anything else is
                // terminal and is reported from the access status alone.
                if (accessStatus != AgeSignalsStatus.SHARED) {
                    result.success(resultToMap(null, accessStatus))
                    return@addOnSuccessListener
                }

                try {
                    manager.checkAgeSignals(AgeSignalsRequest.builder().build())
                        .addOnSuccessListener { ageSignalsResult ->
                            result.success(resultToMap(ageSignalsResult, accessStatus))
                        }
                        .addOnFailureListener { exception -> reportFailure(result, exception) }
                } catch (e: Exception) {
                    // Nothing above us catches here, and an uncompleted Result
                    // leaves the Dart Future pending forever.
                    reportFailure(result, e)
                }
            }
            .addOnFailureListener { exception -> reportFailure(result, exception) }
    }

    private fun reportFailure(result: Result, exception: Exception) {
        val errorMessage = exception.message ?: "An error occurred while checking age signals"
        val errorCode = if (exception is AgeSignalsException) {
            when (exception.errorCode) {
                -1 -> "API_NOT_AVAILABLE"
                -2 -> "PLAY_SERVICES_ERROR"
                -3 -> "NETWORK_ERROR"
                -4 -> "PLAY_SERVICES_ERROR"
                -5 -> "PLAY_SERVICES_ERROR"
                -6 -> "PLAY_SERVICES_ERROR"
                -7 -> "PLAY_SERVICES_ERROR"
                -8 -> "API_ERROR"
                -9 -> "API_NOT_AVAILABLE"
                -10 -> "SDK_VERSION_OUTDATED"
                -100 -> "API_ERROR"
                else -> "API_ERROR"
            }
        } else {
            "API_ERROR"
        }

        result.error(
            errorCode,
            errorMessage,
            "Exception type: ${exception.javaClass.simpleName}"
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private companion object {
        /** Lower bound of Google Play's open-ended adult band. */
        const val DEFAULT_ADULT_AGE = 18
    }
}
