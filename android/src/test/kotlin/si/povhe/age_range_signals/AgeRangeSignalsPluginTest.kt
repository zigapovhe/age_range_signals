package si.povhe.age_range_signals

import android.app.Activity
import com.google.android.play.agesignals.model.AgeRangeSource
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.SignificantChangeStatus
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.test.assertNull

internal class AgeRangeSignalsPluginTest {
    @Test
    fun initialize_returnsSuccess() {
        val plugin = AgeRangeSignalsPlugin()

        val call = MethodCall("initialize", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(null)
    }

    // --- Mock data band logic (regression coverage for 0.6.0) ---

    @Test
    fun buildMockResult_noMockData_usesDefaultSupervised13to15() {
        val result = AgeRangeSignalsPlugin().buildMockResult(null)

        assertEquals(AgeRangeSource.TIER_B, result.ageRangeSource())
        assertEquals(13, result.ageLower())
        assertEquals(15, result.ageUpper())
    }

    @Test
    fun buildMockResult_partialMockOmittingAges_usesDefault13to15() {
        // toMap() always serializes ageLower/ageUpper (null when unset), so a mock
        // that sets only `status` arrives as ageLower=null, ageUpper=null. It must
        // fall back to the documented default band, not an open-ended 13/null band.
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervised", "ageLower" to null, "ageUpper" to null),
        )

        assertEquals(13, result.ageLower())
        assertEquals(15, result.ageUpper())
    }

    @Test
    fun buildMockResult_explicitLowerWithNullUpper_keepsOpenEndedTopBucket() {
        // An explicit lower bound with an omitted upper bound is the intentional
        // open-ended top bucket (e.g. 18+); ageUpper must stay null.
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervised", "ageLower" to 18, "ageUpper" to null),
        )

        assertEquals(18, result.ageLower())
        assertNull(result.ageUpper())
    }

    @Test
    fun buildMockResult_explicitBand_isHonored() {
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervised", "ageLower" to 16, "ageUpper" to 17),
        )

        assertEquals(16, result.ageLower())
        assertEquals(17, result.ageUpper())
    }

    @Test
    fun buildMockResult_verified_carriesTheOpenEndedAdultBand() {
        // The verdict is derived from the band, so a verified mock has to carry
        // one. Real Play reports the open-ended 18+ band for these users.
        val result = AgeRangeSignalsPlugin().buildMockResult(mapOf("status" to "verified"))

        assertEquals(AgeRangeSource.TIER_C, result.ageRangeSource())
        assertEquals(18, result.ageLower())
        assertNull(result.ageUpper())
    }

    @Test
    fun buildMockResult_verifiedWithExplicitLower_reportsOpenEnded18Plus() {
        // A real verified response carries the open-ended 18+ band; explicit
        // bounds apply to verified mocks, only the 13-15 default is
        // supervised/declared-specific.
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "verified", "ageLower" to 18),
        )

        assertEquals(18, result.ageLower())
        assertNull(result.ageUpper())
    }

    // --- Status to tier/change-status derivation ---

    @Test
    fun buildMockResult_pendingStatus_derivesTierBWithPendingChange() {
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervisedApprovalPending"),
        )

        assertEquals(AgeRangeSource.TIER_B, result.ageRangeSource())
        assertEquals(SignificantChangeStatus.PENDING, result.significantChangeStatus())
    }

    @Test
    fun buildMockResult_deniedStatus_derivesTierBWithDeclinedChange() {
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervisedApprovalDenied"),
        )

        assertEquals(AgeRangeSource.TIER_B, result.ageRangeSource())
        assertEquals(SignificantChangeStatus.DECLINED, result.significantChangeStatus())
    }

    @Test
    fun buildMockResult_declaredStatus_derivesTierA() {
        val result = AgeRangeSignalsPlugin().buildMockResult(mapOf("status" to "declared"))

        assertEquals(AgeRangeSource.TIER_A, result.ageRangeSource())
        // Self-declared users have an age band but no install id.
        assertEquals(13, result.ageLower())
        assertNull(result.installId())
    }

    @Test
    fun buildMockResult_unknownStatus_leavesSignalsUnset() {
        val result = AgeRangeSignalsPlugin().buildMockResult(mapOf("status" to "unknown"))

        assertNull(result.ageRangeSource())
        assertNull(result.significantChangeStatus())
        assertNull(result.ageLower())
        assertNull(result.installId())
    }

    @Test
    fun buildMockResult_explicitTier_winsOverStatus() {
        // A mock pinning the tier is authoritative; the status shorthand only
        // fills in what was not stated explicitly.
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "verified", "ageRangeSource" to "tierD"),
        )

        assertEquals(AgeRangeSource.TIER_D, result.ageRangeSource())
    }

    @Test
    fun buildMockResult_explicitChangeStatus_isHonored() {
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervised", "significantChangeStatus" to "approved"),
        )

        assertEquals(AgeRangeSource.TIER_B, result.ageRangeSource())
        assertEquals(SignificantChangeStatus.APPROVED, result.significantChangeStatus())
    }

    // --- Access request mocking (new in 0.0.4) ---

    @Test
    fun buildMockAccessResult_defaultsToShared() {
        val result = AgeRangeSignalsPlugin().buildMockAccessResult(null)

        assertEquals(AgeSignalsStatus.SHARED, result.ageSignalsStatus())
    }

    @Test
    fun buildMockAccessResult_explicitStatus_isHonored() {
        val plugin = AgeRangeSignalsPlugin()

        val notShared = plugin.buildMockAccessResult(mapOf("accessStatus" to "notShared"))
        assertEquals(AgeSignalsStatus.NOT_SHARED, notShared.ageSignalsStatus())

        val verification =
            plugin.buildMockAccessResult(mapOf("accessStatus" to "verificationRequired"))
        assertEquals(AgeSignalsStatus.VERIFICATION_REQUIRED, verification.ageSignalsStatus())

        // "unknown" round-trips through UNSPECIFIED rather than falling into
        // the shared default.
        val unknown = plugin.buildMockAccessResult(mapOf("accessStatus" to "unknown"))
        assertEquals(AgeSignalsStatus.UNSPECIFIED, unknown.ageSignalsStatus())
    }

    @Test
    fun requestAgeSignalsAccess_withoutActivity_reportsPresentationContextUnavailable() {
        val plugin = AgeRangeSignalsPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("requestAgeSignalsAccess", null), mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("PRESENTATION_CONTEXT_UNAVAILABLE"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun requestAgeSignalsAccess_withActivityButNoManager_reportsApiNotAvailable() {
        val plugin = AgeRangeSignalsPlugin()
        val binding = Mockito.mock(ActivityPluginBinding::class.java)
        Mockito.`when`(binding.activity).thenReturn(Mockito.mock(Activity::class.java))
        plugin.onAttachedToActivity(binding)

        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("requestAgeSignalsAccess", null), mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("API_NOT_AVAILABLE"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun accessStatusName_mapsEveryKnownValueAndFallsBackToUnknown() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals("shared", plugin.accessStatusName(AgeSignalsStatus.SHARED))
        assertEquals("notShared", plugin.accessStatusName(AgeSignalsStatus.NOT_SHARED))
        assertEquals(
            "verificationRequired",
            plugin.accessStatusName(AgeSignalsStatus.VERIFICATION_REQUIRED),
        )
        assertEquals("unknown", plugin.accessStatusName(AgeSignalsStatus.UNSPECIFIED))
        assertEquals("unknown", plugin.accessStatusName(null))
    }

    // --- Mock data is refused outside debuggable builds ---

    @Test
    fun shouldRejectMockData_onlyBlocksMockDataInReleaseBuilds() {
        val plugin = AgeRangeSignalsPlugin()

        // The case that matters: a shipped build that would otherwise forge
        // its own age gate for real users.
        assertTrue(plugin.shouldRejectMockData(useMockData = true) { false })

        assertFalse(plugin.shouldRejectMockData(useMockData = true) { true })
        assertFalse(plugin.shouldRejectMockData(useMockData = false) { false })
        assertFalse(plugin.shouldRejectMockData(useMockData = false) { true })
    }

    @Test
    fun shouldRejectMockData_doesNotProbeTheBuildTypeWhenMockDataIsOff() {
        // isDebuggable() reads the Android Context, so it must not be consulted
        // on the common path where no mock data was requested.
        val plugin = AgeRangeSignalsPlugin()
        var probed = false

        plugin.shouldRejectMockData(useMockData = false) { probed = true; true }

        assertFalse(probed)
    }
}
