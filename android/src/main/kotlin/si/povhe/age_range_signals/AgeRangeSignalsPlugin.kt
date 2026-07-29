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

class AgeRangeSignalsPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var ageSignalsManager: AgeSignalsManager? = null
    private var useFakeManager = false
    private var mockData: Map<String, Any?>? = null

    /** Highest configured age gate; the bar `verified` is measured against. */
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

    private fun createFakeManager(): AgeSignalsManager {
        val fakeManager = FakeAgeSignalsManager()
        fakeManager.setNextAgeSignalsResult(buildMockResult(mockData))
        fakeManager.setNextAgeSignalsAccessResult(buildMockAccessResult(mockData))
        return fakeManager
    }

    /**
     * Builds the [AgeSignalsResult] returned by the fake manager from the optional
     * mock data map. Extracted from [createFakeManager] so the mapping logic is
     * unit-testable without the async Task layer.
     *
     * The mock `status` string is translated into the [AgeRangeSource] tier and
     * [SignificantChangeStatus] pair that [resultToMap] derives that status back
     * from. Most scenarios round-trip, but `declared` does not: the verdict
     * comes from the age band, so a self-declared mock on its default band
     * returns `supervised`. Explicit `ageRangeSource` /
     * `significantChangeStatus` entries win over the derived pair, for tests
     * that target a specific tier (e.g. verified via tierD rather than the
     * default tierC).
     *
     * IMPORTANT: the band *values* are Google Play's, not the app's: Play
     * returns predefined bands (0-12, 13-15, 16-17, 18+) from the account's
     * settings. The configured age gates do not change those bands, but the
     * highest gate is the bar the band is measured against, so the implied
     * mock bands here track [adultThreshold] rather than a fixed 18.
     */
    internal fun buildMockResult(mockDataMap: Map<String, Any?>?): AgeSignalsResult {
        // Default to a supervised user for backwards compatibility when no
        // custom mock data is supplied.
        val statusString = mockDataMap?.get("status") as? String ?: "supervised"

        val derivedSource = when (statusString) {
            "verified" -> AgeRangeSource.TIER_C
            "declared" -> AgeRangeSource.TIER_A
            "unknown" -> null
            else -> AgeRangeSource.TIER_B
        }
        val derivedChangeStatus = when (statusString) {
            "supervisedApprovalPending" -> SignificantChangeStatus.PENDING
            "supervisedApprovalDenied" -> SignificantChangeStatus.DECLINED
            else -> null
        }

        val ageRangeSource =
            ageRangeSourceFromName(mockDataMap?.get("ageRangeSource") as? String) ?: derivedSource
        val changeStatus =
            significantChangeStatusFromName(mockDataMap?.get("significantChangeStatus") as? String)
                ?: derivedChangeStatus

        val resultBuilder = AgeSignalsResult.builder()
        ageRangeSource?.let { resultBuilder.setAgeRangeSource(it) }
        changeStatus?.let { resultBuilder.setSignificantChangeStatus(it) }

        // Explicit mock bounds apply to any tier. Without them the band is
        // implied by the tier, chosen from Play's real bands relative to
        // [adultThreshold]: the status is derived by comparing the band
        // against that threshold, so a band fixed at 18 would make the
        // `status` shorthand lie for any other gate.
        if (ageRangeSource != null) {
            val ageLowerRaw = mockDataMap?.get("ageLower") as? Int
            val ageUpperRaw = mockDataMap?.get("ageUpper") as? Int
            val unsupervisedAdultTier = ageRangeSource == AgeRangeSource.TIER_C ||
                ageRangeSource == AgeRangeSource.TIER_D

            if (ageLowerRaw != null) {
                resultBuilder.setAgeLower(ageLowerRaw)

                // An explicit lower bound with an omitted upper bound is the
                // intentional open-ended top bucket (e.g. ageLower=18,
                // ageUpper=null); ageUpper stays unset.
                if (ageUpperRaw != null) {
                    resultBuilder.setAgeUpper(ageUpperRaw)
                }
            } else if (unsupervisedAdultTier) {
                // Real Play reports the open-ended adult band here, which
                // starts at the threshold so the mock derives `verified`. An
                // explicit upper bound still wins, so the band is not silently
                // reopened.
                resultBuilder.setAgeLower(adultThreshold)
                ageUpperRaw?.let { resultBuilder.setAgeUpper(it) }
            } else {
                // No explicit lower bound: use the highest real Play band that
                // sits entirely below the threshold, so the mock derives
                // `supervised` without inventing a band Play never returns.
                val (low, high) = supervisedBandBelow(adultThreshold)
                resultBuilder.setAgeLower(low)
                // An explicit upper bound wins, but never below the lower
                // bound: an inverted range is not a shape Play can produce.
                resultBuilder.setAgeUpper(ageUpperRaw?.coerceAtLeast(low) ?: high)
            }
        }

        // installId is set for supervised installs, not for declared/verified.
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
     * Builds the [AgeSignalsAccessResult] the fake manager answers
     * requestAgeSignalsAccess with. Defaults to SHARED so mocked flows
     * proceed straight into checkAgeSignals; notShared and
     * verificationRequired exercise the gated paths.
     */
    internal fun buildMockAccessResult(mockDataMap: Map<String, Any?>?): AgeSignalsAccessResult {
        val status = when (mockDataMap?.get("accessStatus") as? String) {
            "notShared" -> AgeSignalsStatus.NOT_SHARED
            "verificationRequired" -> AgeSignalsStatus.VERIFICATION_REQUIRED
            // UNSPECIFIED maps back to "unknown", so the unrecognized-state
            // fallback can be mocked like every other outcome.
            "unknown" -> AgeSignalsStatus.UNSPECIFIED
            else -> AgeSignalsStatus.SHARED
        }
        return AgeSignalsAccessResult.builder().setAgeSignalsStatus(status).build()
    }

    /**
     * Derives the cross-platform status.
     *
     * [ageRangeSource] says how the age was established, not what it is: a
     * `TIER_D` result means an ID was checked, and that ID can read 12. The
     * verdict therefore comes from the reported band compared against the
     * caller's highest age gate, the same comparison the iOS side makes, so
     * one `status` check means the same thing on both platforms.
     */
    internal fun deriveStatus(
        ageRangeSource: Int?,
        changeStatus: Int?,
        ageLower: Int?,
        threshold: Int = adultThreshold
    ): String {
        // A guardian-attested account with an outstanding decision is
        // actionable whatever the age, so that wins.
        if (ageRangeSource == AgeRangeSource.TIER_B) {
            when (changeStatus) {
                SignificantChangeStatus.PENDING -> return "supervisedApprovalPending"
                SignificantChangeStatus.DECLINED -> return "supervisedApprovalDenied"
            }
        }

        if (ageRangeSource == null || ageRangeSource == AgeRangeSource.UNSPECIFIED) {
            return "unknown"
        }

        val lower = ageLower ?: return "unknown"
        return if (lower >= threshold) "verified" else "supervised"
    }

    /**
     * Maps a platform [AgeSignalsResult] to the channel map consumed by Dart.
     * Shared by the real and fake manager listeners so the two paths cannot
     * drift apart. iOS-only keys are present but always null on Android, so
     * both platforms emit the same shape.
     */
    internal fun resultToMap(ageSignalsResult: AgeSignalsResult): Map<String, Any?> {
        val ageRangeSource = ageSignalsResult.ageRangeSource()
        val changeStatus = ageSignalsResult.significantChangeStatus()

        val status = deriveStatus(
            ageRangeSource,
            changeStatus,
            ageSignalsResult.ageLower(),
        )

        return mapOf(
            "status" to status,
            "installId" to ageSignalsResult.installId(),
            "ageLower" to ageSignalsResult.ageLower(),
            "ageUpper" to ageSignalsResult.ageUpper(),
            "ageRangeSource" to ageRangeSourceName(ageRangeSource),
            "significantChangeStatus" to significantChangeStatusName(changeStatus),
            "source" to null,
            "activeParentalControls" to null,
            "significantChangeApprovalDate" to ageSignalsResult.significantChangeApprovalDate()?.time
        )
    }

    private fun ageRangeSourceFromName(name: String?): Int? = when (name) {
        "tierA" -> AgeRangeSource.TIER_A
        "tierB" -> AgeRangeSource.TIER_B
        "tierC" -> AgeRangeSource.TIER_C
        "tierD" -> AgeRangeSource.TIER_D
        else -> null
    }

    private fun ageRangeSourceName(source: Int?): String? = when (source) {
        AgeRangeSource.TIER_A -> "tierA"
        AgeRangeSource.TIER_B -> "tierB"
        AgeRangeSource.TIER_C -> "tierC"
        AgeRangeSource.TIER_D -> "tierD"
        else -> null
    }

    private fun significantChangeStatusFromName(name: String?): Int? = when (name) {
        "approved" -> SignificantChangeStatus.APPROVED
        "pending" -> SignificantChangeStatus.PENDING
        "declined" -> SignificantChangeStatus.DECLINED
        else -> null
    }

    private fun significantChangeStatusName(status: Int?): String? = when (status) {
        SignificantChangeStatus.APPROVED -> "approved"
        SignificantChangeStatus.PENDING -> "pending"
        SignificantChangeStatus.DECLINED -> "declined"
        else -> null
    }

    internal fun accessStatusName(status: Int?): String = when (status) {
        AgeSignalsStatus.SHARED -> "shared"
        AgeSignalsStatus.NOT_SHARED -> "notShared"
        AgeSignalsStatus.VERIFICATION_REQUIRED -> "verificationRequired"
        else -> "unknown"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val useMockData = call.argument<Boolean>("useMockData") ?: false

                // Gates are independent of mock data, so apply them before any
                // refusal below, and only when supplied: a later initialize()
                // that omits them must not silently reset the bar back to 18.
                // iOS keeps its gates the same way.
                call.argument<List<Int>>("ageGates")?.maxOrNull()?.let {
                    adultThreshold = it
                }

                // FakeAgeSignalsManager forges age signals. A shipped release
                // that reaches it hands a fabricated age gate to real users,
                // which is the failure this plugin exists to prevent.
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
                result.success(null)
            }
            "requestAgeSignalsAccess" -> {
                requestAgeSignalsAccess(result)
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

    private fun requestAgeSignalsAccess(result: Result) {
        // Play renders the age sharing prompt over the current activity, so
        // the request cannot be built from the application context alone.
        val activity = this.activity
        if (activity == null) {
            result.error(
                "PRESENTATION_CONTEXT_UNAVAILABLE",
                "No foreground activity to present the age sharing prompt on",
                null
            )
            return
        }

        // Like checkAgeSignals, an explicit mock request runs against the
        // fake manager even when the real API is unavailable.
        val manager = if (useFakeManager) createFakeManager() else ageSignalsManager
        if (manager == null) {
            result.error(
                "API_NOT_AVAILABLE",
                "Age Signals API is not available on this device",
                null
            )
            return
        }

        val request = AgeSignalsAccessRequest.builder().setActivity(activity).build()

        manager.requestAgeSignalsAccess(request)
            .addOnSuccessListener { accessResult ->
                result.success(accessStatusName(accessResult.ageSignalsStatus()))
            }
            .addOnFailureListener { exception ->
                result.error(
                    channelErrorCode(exception),
                    exception.message ?: "An error occurred while requesting age signals access",
                    "Exception type: ${exception.javaClass.simpleName}"
                )
            }
    }

    private fun checkAgeSignals(result: Result) {
        // If the user explicitly requested mock data, use the fake manager.
        // This runs before the real-manager null check so mock mode works even
        // when Play Services / the real Age Signals API is unavailable.
        if (useFakeManager) {
            // Real Play returns no signals when access was not granted. The
            // fake manager does not model that, so honour the mocked access
            // outcome here or a `notShared` mock would still hand back a band.
            if (buildMockAccessResult(mockData).ageSignalsStatus() != AgeSignalsStatus.SHARED) {
                result.success(resultToMap(AgeSignalsResult.builder().build()))
                return
            }

            val fakeManager = createFakeManager()
            val request = AgeSignalsRequest.builder().build()

            fakeManager.checkAgeSignals(request)
                .addOnSuccessListener { fakeResult ->
                    result.success(resultToMap(fakeResult))
                }
                .addOnFailureListener { fakeException ->
                    result.error(
                        "API_ERROR",
                        fakeException.message ?: "An error occurred in fake manager",
                        "Exception type: ${fakeException.javaClass.simpleName}"
                    )
                }
            return
        }

        // Use real API
        val manager = ageSignalsManager
        if (manager == null) {
            result.error(
                "API_NOT_AVAILABLE",
                "Age Signals API is not available on this device",
                null
            )
            return
        }

        val request = AgeSignalsRequest.builder().build()

        manager.checkAgeSignals(request)
            .addOnSuccessListener { ageSignalsResult ->
                result.success(resultToMap(ageSignalsResult))
            }
            .addOnFailureListener { exception ->
                result.error(
                    channelErrorCode(exception),
                    exception.message ?: "An error occurred while checking age signals",
                    "Exception type: ${exception.javaClass.simpleName}"
                )
            }
    }

    /**
     * Maps a Play library failure onto the channel's error codes; the numeric
     * values are the library's AgeSignalsErrorCode constants. A declined
     * sharing prompt is not a failure - it arrives as a notShared access
     * result, never through this path.
     */
    private fun channelErrorCode(exception: Exception): String {
        if (exception !is AgeSignalsException) return "API_ERROR"
        return when (exception.errorCode) {
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
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    /**
     * Whether mock data must be refused. Split from [isDebuggable] so the rule
     * is unit-testable without an Android [Context], and lazy so the common
     * path never touches the Context.
     */
    internal fun shouldRejectMockData(
        useMockData: Boolean,
        debuggable: () -> Boolean
    ): Boolean = useMockData && !debuggable()

    /**
     * The highest of Play's documented bands (0-12, 13-15, 16-17) that sits
     * entirely below [threshold]. Used for implied mock bands so the harness
     * only ever emits ranges the real API could return.
     */
    internal fun supervisedBandBelow(threshold: Int): Pair<Int, Int> = when {
        threshold > 15 -> 13 to 15
        else -> 0 to 12
    }

    private fun isDebuggable(): Boolean =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private companion object {
        /** Lower bound of Google Play's open-ended adult band. */
        const val DEFAULT_ADULT_AGE = 18

    }
}
