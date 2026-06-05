package si.povhe.age_range_signals

import com.google.android.play.agesignals.model.AgeSignalsVerificationStatus
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
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

        assertEquals(AgeSignalsVerificationStatus.SUPERVISED, result.userStatus())
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
    fun buildMockResult_verified_hasNoAgeRange() {
        val result = AgeRangeSignalsPlugin().buildMockResult(mapOf("status" to "verified"))

        assertEquals(AgeSignalsVerificationStatus.VERIFIED, result.userStatus())
        assertNull(result.ageLower())
        assertNull(result.ageUpper())
    }
}
