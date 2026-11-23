package si.povhe.age_range_signals

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.android.gms.tasks.Task
import com.google.android.play.agesignals.AgeSignalsAccessResult
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.ApplicableAgeFeaturesResult
import com.google.android.play.agesignals.model.AgeRangeSource
import com.google.android.play.agesignals.model.AgeSignalsErrorCode
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.ApplicableAgeFeature
import com.google.android.play.agesignals.model.SignificantChangeStatus
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import java.util.Date
import kotlin.test.Test
import kotlin.test.assertEquals

/** What each channel method does with Play's answer. Only Play is mocked. */
internal class PlayManagerTest {
    private val manager: AgeSignalsManager = Mockito.mock(AgeSignalsManager::class.java)
    private val plugin = AgeRangeSignalsPlugin().also { setField(it, "ageSignalsManager", manager) }

    // --- isEligibleForAgeFeatures ---

    @Test
    fun isEligible_mandatorySharing_isTrue() {
        playFeatures(setOf(ApplicableAgeFeature.MANDATORY_SHARING))
        Mockito.verify(call("isEligibleForAgeFeatures")).success(true)
    }

    @Test
    fun isEligible_noFeatures_isFalse() {
        playFeatures(emptySet())
        Mockito.verify(call("isEligibleForAgeFeatures")).success(false)
    }

    @Test
    fun isEligible_onlyAnUnknownFeature_isFalse() {
        playFeatures(setOf(99))
        Mockito.verify(call("isEligibleForAgeFeatures")).success(false)
    }

    // --- getRequiredRegulatoryFeatures ---

    @Test
    fun regulatoryFeatures_mandatorySharing_isDeclaredAgeRangeRequired() {
        playFeatures(setOf(ApplicableAgeFeature.MANDATORY_SHARING, 99))
        Mockito.verify(call("getRequiredRegulatoryFeatures"))
            .success(listOf("declaredAgeRangeRequired"))
    }

    @Test
    fun regulatoryFeatures_noFeatures_isAnEmptyListNotNull() {
        playFeatures(emptySet())
        Mockito.verify(call("getRequiredRegulatoryFeatures")).success(emptyList<String>())
    }

    // --- failures ---

    @Test
    fun everyPlayErrorCode_reachesDartAsTheDocumentedCode() {
        val expected = mapOf(
            AgeSignalsErrorCode.API_NOT_AVAILABLE to "API_NOT_AVAILABLE",
            AgeSignalsErrorCode.PLAY_STORE_NOT_FOUND to "PLAY_SERVICES_ERROR",
            AgeSignalsErrorCode.NETWORK_ERROR to "NETWORK_ERROR",
            AgeSignalsErrorCode.PLAY_SERVICES_NOT_FOUND to "PLAY_SERVICES_ERROR",
            AgeSignalsErrorCode.CANNOT_BIND_TO_SERVICE to "PLAY_SERVICES_ERROR",
            AgeSignalsErrorCode.PLAY_STORE_VERSION_OUTDATED to "PLAY_SERVICES_ERROR",
            AgeSignalsErrorCode.PLAY_SERVICES_VERSION_OUTDATED to "PLAY_SERVICES_ERROR",
            AgeSignalsErrorCode.CLIENT_TRANSIENT_ERROR to "API_ERROR",
            AgeSignalsErrorCode.APP_NOT_OWNED to "API_NOT_AVAILABLE",
            AgeSignalsErrorCode.SDK_VERSION_OUTDATED to "SDK_VERSION_OUTDATED",
            AgeSignalsErrorCode.DEVICE_NOT_SUPPORTED to "API_NOT_AVAILABLE",
            AgeSignalsErrorCode.INTERNAL_ERROR to "API_ERROR",
            -999 to "API_ERROR",
        )
        attachActivity()

        for ((playCode, channelCode) in expected) {
            playFails(AgeSignalsException(playCode))
            for (method in PLAY_METHODS) verifyOnlyError(call(method), channelCode, "$method $playCode")
        }
    }

    @Test
    fun aNonPlayFailure_isApiError() {
        attachActivity()
        playFails(IllegalStateException("boom"))
        for (method in PLAY_METHODS) verifyOnlyError(call(method), "API_ERROR", method)
    }

    // --- checkAgeSignals and requestAgeSignalsAccess ---

    @Test
    fun check_mapsPlaysResult() {
        val task = succeeded(
            AgeSignalsResult.builder()
                .setAgeRangeSource(AgeRangeSource.TIER_A)
                .setAgeLower(18)
                .build(),
        )
        Mockito.`when`(manager.checkAgeSignals(Mockito.any())).thenReturn(task)

        Mockito.verify(call("checkAgeSignals")).success(
            mapOf(
                "status" to "verified",
                "installId" to null,
                "ageLower" to 18,
                "ageUpper" to null,
                "ageRangeSource" to "tierA",
                "significantChangeStatus" to null,
                "source" to null,
                "activeParentalControls" to null,
                "significantChangeApprovalDate" to null,
            ),
        )
    }

    @Test
    fun check_mapsEveryResponseGoogleDocuments() {
        // The examples on Google's "Understand age signals responses" page.
        val adult = mapOf("status" to "verified", "ageLower" to 18, "ageUpper" to null, "installId" to null)
        val teen = mapOf("status" to "supervised", "ageLower" to 13, "ageUpper" to 15)
        val examples = listOf(
            signals(AgeRangeSource.TIER_D, 18) to adult + ("ageRangeSource" to "tierD"),
            signals(AgeRangeSource.TIER_C, 18) to adult + ("ageRangeSource" to "tierC"),
            signals(AgeRangeSource.TIER_A, 18) to adult + ("ageRangeSource" to "tierA"),
            signals(AgeRangeSource.TIER_B, 13, 15) to teen + ("ageRangeSource" to "tierB"),
            AgeSignalsResult.builder() to
                mapOf("status" to "unknown", "ageRangeSource" to null, "ageLower" to null, "ageUpper" to null),
            signals(AgeRangeSource.TIER_B, 13, 15)
                .setSignificantChangeStatus(SignificantChangeStatus.APPROVED)
                .setSignificantChangeApprovalDate(Date(1768435200000L))
                .setInstallId("abc123xyz789") to
                teen + mapOf(
                    "ageRangeSource" to "tierB",
                    "significantChangeStatus" to "approved",
                    "significantChangeApprovalDate" to 1768435200000L,
                    "installId" to "abc123xyz789",
                ),
        )

        for ((playResult, expected) in examples) {
            val task = succeeded(playResult.build())
            Mockito.`when`(manager.checkAgeSignals(Mockito.any())).thenReturn(task)

            Mockito.verify(call("checkAgeSignals"), Mockito.description("$expected")).success(
                Mockito.argThat<Any> { actual ->
                    actual is Map<*, *> && expected.all { (key, value) -> actual[key] == value }
                },
            )
        }
    }

    @Test
    fun requestAccess_mapsPlaysStatus() {
        attachActivity()
        val task = succeeded(
            AgeSignalsAccessResult.builder()
                .setAgeSignalsStatus(AgeSignalsStatus.NOT_SHARED)
                .build(),
        )
        Mockito.`when`(manager.requestAgeSignalsAccess(Mockito.any())).thenReturn(task)

        Mockito.verify(call("requestAgeSignalsAccess")).success("notShared")
    }

    @Test
    fun requestAccess_afterTheActivityIsGone_doesNotReachPlay() {
        attachActivity()
        plugin.onDetachedFromActivity()

        verifyOnlyError(
            call("requestAgeSignalsAccess"),
            "PRESENTATION_CONTEXT_UNAVAILABLE",
            "detached",
        )
        Mockito.verifyNoInteractions(manager)
    }

    // --- mock data ---

    @Test
    fun mockData_inAReleaseBuild_isRefusedAndPlayStillAnswers() {
        useBuildWithFlags(0)
        playFeatures(emptySet())

        verifyOnlyError(
            call("initialize", mapOf("useMockData" to true)),
            "MOCK_DATA_NOT_ALLOWED",
            "initialize",
        )
        // The mock default would say true, so false can only come from Play.
        Mockito.verify(call("isEligibleForAgeFeatures")).success(false)
    }

    @Test
    fun mockData_refusedInARelease_stillAppliesTheGates() {
        useBuildWithFlags(0)
        call("initialize", mapOf("useMockData" to true, "ageGates" to listOf(13, 21)))

        assertEquals("supervised", plugin.deriveStatus(AgeRangeSource.TIER_A, null, 18))
        assertEquals("verified", plugin.deriveStatus(AgeRangeSource.TIER_A, null, 21))
    }

    @Test
    fun mockData_inADebuggableBuild_isAccepted() {
        useBuildWithFlags(ApplicationInfo.FLAG_DEBUGGABLE)
        Mockito.verify(call("initialize", mapOf("useMockData" to true))).success(null)
    }

    @Test
    fun mockData_accessNotShared_reportsUnknownWithoutPlay() {
        useBuildWithFlags(ApplicationInfo.FLAG_DEBUGGABLE)
        call(
            "initialize",
            mapOf(
                "useMockData" to true,
                "mockData" to mapOf("status" to "verified", "accessStatus" to "notShared"),
            ),
        )

        Mockito.verify(call("checkAgeSignals")).success(
            Mockito.argThat { it is Map<*, *> && it["status"] == "unknown" && it["ageLower"] == null },
        )
        Mockito.verifyNoInteractions(manager)
    }

    // --- tier A mocks need a bound to be an adult ---

    @Test
    fun tierAMock_isOnlyVerifiedWithAnExplicitAdultBound() {
        val unbounded = mapOf("status" to "verified", "ageRangeSource" to "tierA")
        val adult = unbounded + ("ageLower" to 18)

        assertEquals("supervised", plugin.resultToMap(plugin.buildMockResult(unbounded))["status"])
        assertEquals("verified", plugin.resultToMap(plugin.buildMockResult(adult))["status"])
    }

    // --- helpers ---

    private fun call(method: String, arguments: Any? = null): MethodChannel.Result {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall(method, arguments), result)
        return result
    }

    private fun verifyOnlyError(result: MethodChannel.Result, code: String, label: String) {
        Mockito.verify(result, Mockito.description(label))
            .error(Mockito.eq(code), Mockito.any(), Mockito.any())
        Mockito.verifyNoMoreInteractions(result)
    }

    private fun playFeatures(features: Set<Int>) {
        val task = succeeded(ApplicableAgeFeaturesResult.builder().setFeatures(features).build())
        Mockito.`when`(manager.getApplicableAgeFeatures(Mockito.any())).thenReturn(task)
    }

    private fun playFails(e: Exception) {
        val features = failed<ApplicableAgeFeaturesResult>(e)
        val signals = failed<AgeSignalsResult>(e)
        val access = failed<AgeSignalsAccessResult>(e)
        Mockito.`when`(manager.getApplicableAgeFeatures(Mockito.any())).thenReturn(features)
        Mockito.`when`(manager.checkAgeSignals(Mockito.any())).thenReturn(signals)
        Mockito.`when`(manager.requestAgeSignalsAccess(Mockito.any())).thenReturn(access)
    }

    private fun signals(tier: Int, lower: Int, upper: Int? = null): AgeSignalsResult.Builder {
        val builder = AgeSignalsResult.builder().setAgeRangeSource(tier).setAgeLower(lower)
        upper?.let { builder.setAgeUpper(it) }
        return builder
    }

    private fun attachActivity() {
        val binding = Mockito.mock(ActivityPluginBinding::class.java)
        Mockito.`when`(binding.activity).thenReturn(Mockito.mock(Activity::class.java))
        plugin.onAttachedToActivity(binding)
    }

    private fun useBuildWithFlags(flags: Int) {
        val context = Mockito.mock(Context::class.java)
        Mockito.`when`(context.applicationInfo)
            .thenReturn(ApplicationInfo().apply { this.flags = flags })
        setField(plugin, "context", context)
    }

    // Real tasks post to the main looper, which JVM tests don't have.
    @Suppress("UNCHECKED_CAST")
    private fun <T> succeeded(value: T): Task<T> {
        val task = Mockito.mock(Task::class.java) as Task<T>
        Mockito.`when`(task.addOnSuccessListener(Mockito.any<OnSuccessListener<in T>>())).thenAnswer {
            (it.arguments[0] as OnSuccessListener<T>).onSuccess(value)
            task
        }
        Mockito.`when`(task.addOnFailureListener(Mockito.any<OnFailureListener>())).thenReturn(task)
        return task
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> failed(e: Exception): Task<T> {
        val task = Mockito.mock(Task::class.java) as Task<T>
        Mockito.`when`(task.addOnSuccessListener(Mockito.any<OnSuccessListener<in T>>()))
            .thenReturn(task)
        Mockito.`when`(task.addOnFailureListener(Mockito.any<OnFailureListener>())).thenAnswer {
            (it.arguments[0] as OnFailureListener).onFailure(e)
            task
        }
        return task
    }

    private fun setField(target: AgeRangeSignalsPlugin, name: String, value: Any) {
        AgeRangeSignalsPlugin::class.java.getDeclaredField(name)
            .apply { isAccessible = true }
            .set(target, value)
    }

    private companion object {
        val PLAY_METHODS = listOf(
            "checkAgeSignals",
            "requestAgeSignalsAccess",
            "isEligibleForAgeFeatures",
            "getRequiredRegulatoryFeatures",
        )
    }
}
