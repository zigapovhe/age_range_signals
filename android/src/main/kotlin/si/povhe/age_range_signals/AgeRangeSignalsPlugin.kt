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

        // Use custom mock data if provided, otherwise use defaults for backwards compatibility
        // Default test result is for supervised user (13-15) to demonstrate age range functionality
        //
        // IMPORTANT: Age ranges are determined by Google Play's parental control settings,
        // NOT by your app's configured age gates. Android ignores the ageGates parameter - it's iOS-only.
        // Google Play returns predefined age bands: 0-12, 13-15, 16-17, 18+
        val mockDataMap = mockData

        // Extract status first
        val statusString = mockDataMap?.get("status") as? String ?: "supervised"

        // Parse status string to enum
        val userStatus = when (statusString) {
            "verified" -> AgeSignalsVerificationStatus.VERIFIED
            "supervised" -> AgeSignalsVerificationStatus.SUPERVISED
            "supervisedApprovalPending" -> AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING
            "supervisedApprovalDenied" -> AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED
            "declared" -> AgeSignalsVerificationStatus.DECLARED
            "unknown" -> AgeSignalsVerificationStatus.UNKNOWN
            else -> AgeSignalsVerificationStatus.SUPERVISED
        }

        // Build result with custom or default values
        val resultBuilder = AgeSignalsResult.builder().setUserStatus(userStatus)

        // Only set age range and installId if status is supervised (or similar states)
        // For verified status, these are typically null
        // Extract these values only when needed to avoid unnecessary work
        if (userStatus == AgeSignalsVerificationStatus.SUPERVISED ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED ||
            userStatus == AgeSignalsVerificationStatus.DECLARED) {
            val ageLower = mockDataMap?.get("ageLower") as? Int ?: 13
            resultBuilder.setAgeLower(ageLower)

            // Honor an explicitly-provided null ageUpper so the open-ended top
            // bucket (e.g. ageLower=18, ageUpper=null) is reproducible via mock data.
            // Only fall back to the default (15) when no custom mock data was supplied.
            val ageUpper = mockDataMap?.get("ageUpper") as? Int
            if (ageUpper != null) {
                resultBuilder.setAgeUpper(ageUpper)
            } else if (mockDataMap == null) {
                resultBuilder.setAgeUpper(15)
            }
            // else: custom mock data with a null ageUpper -> leave unset (null)
        }

        // installId is only set for supervised statuses, not for declared
        if (userStatus == AgeSignalsVerificationStatus.SUPERVISED ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING ||
            userStatus == AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED) {
            val installId = mockDataMap?.get("installId") as? String ?: "test_install_id_12345"
            resultBuilder.setInstallId(installId)
        }

        val fakeResult = resultBuilder.build()
        fakeManager.setNextAgeSignalsResult(fakeResult)
        return fakeManager
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
                    val status = when (fakeResult.userStatus()) {
                        AgeSignalsVerificationStatus.VERIFIED -> "verified"
                        AgeSignalsVerificationStatus.SUPERVISED -> "supervised"
                        AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> "supervisedApprovalPending"
                        AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> "supervisedApprovalDenied"
                        AgeSignalsVerificationStatus.DECLARED -> "declared"
                        AgeSignalsVerificationStatus.UNKNOWN -> "unknown"
                        else -> "unknown"
                    }

                    val resultMap = mapOf(
                        "status" to status,
                        "installId" to fakeResult.installId(),
                        "ageLower" to fakeResult.ageLower(),
                        "ageUpper" to fakeResult.ageUpper(),
                        "source" to null
                    )

                    result.success(resultMap)
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
                val status = when (ageSignalsResult.userStatus()) {
                    AgeSignalsVerificationStatus.VERIFIED -> "verified"
                    AgeSignalsVerificationStatus.SUPERVISED -> "supervised"
                    AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> "supervisedApprovalPending"
                    AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> "supervisedApprovalDenied"
                    AgeSignalsVerificationStatus.DECLARED -> "declared"
                    AgeSignalsVerificationStatus.UNKNOWN -> "unknown"
                    else -> "unknown"
                }

                val resultMap = mapOf(
                    "status" to status,
                    "installId" to ageSignalsResult.installId(),
                    "ageLower" to ageSignalsResult.ageLower(),
                    "ageUpper" to ageSignalsResult.ageUpper(),
                    "source" to null
                )

                result.success(resultMap)
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
