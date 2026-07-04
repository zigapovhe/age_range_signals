package si.povhe.age_range_signals

import android.content.Context
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.model.AgeSignalsVerificationStatus
import com.google.android.play.agesignals.testing.FakeAgeSignalsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Date

class AgeRangeSignalsPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var ageSignalsManager: AgeSignalsManager? = null
    private var useFakeManager = false
    private var mockData: Map<String, Any?>? = null

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
        return fakeManager
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

        val userStatus = when (statusString) {
            "verified" -> AgeSignalsVerificationStatus.VERIFIED
            "supervised" -> AgeSignalsVerificationStatus.SUPERVISED
            "supervisedApprovalPending" -> AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING
            "supervisedApprovalDenied" -> AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED
            "declared" -> AgeSignalsVerificationStatus.DECLARED
            "unknown" -> AgeSignalsVerificationStatus.UNKNOWN
            else -> AgeSignalsVerificationStatus.SUPERVISED
        }

        val resultBuilder = AgeSignalsResult.builder().setUserStatus(userStatus)

        // Age range only applies to supervised-like states (verified is 18+, no range).
        if (userStatus == AgeSignalsVerificationStatus.SUPERVISED ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED ||
            userStatus == AgeSignalsVerificationStatus.DECLARED) {
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

        // installId is set for supervised statuses, not for declared/verified.
        if (userStatus == AgeSignalsVerificationStatus.SUPERVISED ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED) {
            val installId = mockDataMap?.get("installId") as? String ?: "test_install_id_12345"
            resultBuilder.setInstallId(installId)
        }

        (mockDataMap?.get("mostRecentApprovalDate") as? Number)?.let {
            resultBuilder.setMostRecentApprovalDate(Date(it.toLong()))
        }

        return resultBuilder.build()
    }

    /**
     * Maps a platform [AgeSignalsResult] to the channel map consumed by Dart.
     * Shared by the real and fake manager listeners so the two paths cannot
     * drift apart. iOS-only keys are present but always null on Android.
     */
    internal fun resultToMap(ageSignalsResult: AgeSignalsResult): Map<String, Any?> {
        val status = when (ageSignalsResult.userStatus()) {
            AgeSignalsVerificationStatus.VERIFIED -> "verified"
            AgeSignalsVerificationStatus.SUPERVISED -> "supervised"
            AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> "supervisedApprovalPending"
            AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> "supervisedApprovalDenied"
            AgeSignalsVerificationStatus.DECLARED -> "declared"
            AgeSignalsVerificationStatus.UNKNOWN -> "unknown"
            else -> "unknown"
        }

        return mapOf(
            "status" to status,
            "installId" to ageSignalsResult.installId(),
            "ageLower" to ageSignalsResult.ageLower(),
            "ageUpper" to ageSignalsResult.ageUpper(),
            "source" to null,
            "activeParentalControls" to null,
            "mostRecentApprovalDate" to ageSignalsResult.mostRecentApprovalDate()?.time
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val useMockData = call.argument<Boolean>("useMockData") ?: false
                useFakeManager = useMockData
                // Store mock data for use when creating fake manager
                mockData = call.argument<Map<String, Any?>>("mockData")
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
        if (useFakeManager) {
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
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
