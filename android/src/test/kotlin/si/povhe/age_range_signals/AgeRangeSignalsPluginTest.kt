package si.povhe.age_range_signals

import com.google.android.play.agesignals.model.AgeRangeSource
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

    // --- Mock data is refused outside debuggable builds ---

    @Test
    fun shouldRejectMockData_onlyBlocksMockDataInReleaseBuilds() {
        val plugin = AgeRangeSignalsPlugin()

        // The case that matters: a shipped build that would otherwise forge
        // its own age gate for real users.
        assertTrue(plugin.shouldRejectMockData(useMockData = true) { false })

        // Everything else must keep working.
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

    // --- 0.0.4 model ---

    @Test
    fun buildMockResult_verified_isOpenEndedAdultBand() {
        // 0.0.3 reported verified with no range at all. 0.0.4 has no status
        // field, so "verified" is now carried by an open-ended 18+ band from an
        // unsupervised, ID-verified source.
        val result = AgeRangeSignalsPlugin().buildMockResult(mapOf("status" to "verified"))

        assertEquals(AgeRangeSource.TIER_D, result.ageRangeSource())
        assertEquals(18, result.ageLower())
        assertNull(result.ageUpper())
    }

    @Test
    fun buildMockResult_declared_usesSelfDeclaredTier() {
        val result = AgeRangeSignalsPlugin().buildMockResult(mapOf("status" to "declared"))

        assertEquals(AgeRangeSource.TIER_A, result.ageRangeSource())
    }

    @Test
    fun buildMockResult_explicitSourceOverridesStatusImpliedTier() {
        val result = AgeRangeSignalsPlugin().buildMockResult(
            mapOf("status" to "supervised", "source" to "estimated"),
        )

        assertEquals(AgeRangeSource.TIER_C, result.ageRangeSource())
    }

    @Test
    fun buildMockAccessResult_mapsNonSharingStatuses() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            com.google.android.play.agesignals.model.AgeSignalsStatus.NOT_SHARED,
            plugin.buildMockAccessResult(mapOf("status" to "declined")).ageSignalsStatus(),
        )
        assertEquals(
            com.google.android.play.agesignals.model.AgeSignalsStatus.VERIFICATION_REQUIRED,
            plugin.buildMockAccessResult(mapOf("status" to "verificationRequired"))
                .ageSignalsStatus(),
        )
        assertEquals(
            com.google.android.play.agesignals.model.AgeSignalsStatus.SHARED,
            plugin.buildMockAccessResult(mapOf("status" to "supervised")).ageSignalsStatus(),
        )
    }
}
