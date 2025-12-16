package si.povhe.age_range_signals

import android.content.Context
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
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

        // Set up a default test result for verified user (18+)
        // Verified users typically have null age ranges since they're adults
        val fakeResult = AgeSignalsResult.builder()
            .setUserStatus(AgeSignalsVerificationStatus.VERIFIED)
            .setInstallId("test_install_id_12345")
            .setAgeLower(null)
            .setAgeUpper(null)
            .build()

        fakeManager.setNextAgeSignalsResult(fakeResult)
        return fakeManager
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val useMockData = call.argument<Boolean>("useMockData") ?: false
                useFakeManager = useMockData
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
        var manager = ageSignalsManager
        if (manager == null) {
            result.error(
                "API_NOT_AVAILABLE",
                "Age Signals API is not available on this device",
                null
            )
            return
        }

        // If user explicitly requested mock data, use fake manager
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
        val request = AgeSignalsRequest.builder().build()

        manager.checkAgeSignals(request)
            .addOnSuccessListener { ageSignalsResult ->
                val status = when (ageSignalsResult.userStatus()) {
                    AgeSignalsVerificationStatus.VERIFIED -> "verified"
                    AgeSignalsVerificationStatus.SUPERVISED -> "supervised"
                    AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> "supervisedApprovalPending"
                    AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> "supervisedApprovalDenied"
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
                // Parse exception to provide more specific error codes
                val errorMessage = exception.message ?: "An error occurred while checking age signals"
                val errorCode = when {
                    // Google Play Services related errors
                    errorMessage.contains("GooglePlayServices", ignoreCase = true) ||
                    errorMessage.contains("Play Services", ignoreCase = true) -> "PLAY_SERVICES_ERROR"

                    // Network related errors
                    errorMessage.contains("network", ignoreCase = true) ||
                    errorMessage.contains("connection", ignoreCase = true) ||
                    errorMessage.contains("timeout", ignoreCase = true) -> "NETWORK_ERROR"

                    // User not signed in
                    errorMessage.contains("not signed in", ignoreCase = true) ||
                    errorMessage.contains("authentication", ignoreCase = true) -> "USER_NOT_SIGNED_IN"

                    // Regional availability
                    errorMessage.contains("not available", ignoreCase = true) ||
                    errorMessage.contains("region", ignoreCase = true) -> "API_NOT_AVAILABLE"

                    // User cancelled
                    errorMessage.contains("cancel", ignoreCase = true) ||
                    errorMessage.contains("abort", ignoreCase = true) -> "USER_CANCELLED"

                    else -> "API_ERROR"
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
