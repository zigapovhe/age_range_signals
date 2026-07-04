package si.povhe.age_range_signals

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ResultMapTest {
    private val plugin = AgeRangeSignalsPlugin()

    @Test
    fun resultToMap_includesApprovalDateMillis() {
        val result = plugin.buildMockResult(
            mapOf(
                "status" to "supervised",
                "ageLower" to 13,
                "ageUpper" to 15,
                "installId" to "test_id",
                "mostRecentApprovalDate" to 1735689600000L,
            )
        )
        val map = plugin.resultToMap(result)

        assertEquals("supervised", map["status"])
        assertEquals(1735689600000L, map["mostRecentApprovalDate"])
        // iOS-only key must exist and be null so the Dart map shape is stable
        assertNull(map["activeParentalControls"])
    }

    @Test
    fun resultToMap_omittedApprovalDateIsNull() {
        val result = plugin.buildMockResult(mapOf("status" to "verified"))
        val map = plugin.resultToMap(result)

        assertEquals("verified", map["status"])
        assertNull(map["mostRecentApprovalDate"])
    }
}
