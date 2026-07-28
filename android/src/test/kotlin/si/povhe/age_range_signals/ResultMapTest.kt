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
                "significantChangeApprovalDate" to 1735689600000L,
            )
        )
        val map = plugin.resultToMap(result)

        assertEquals("supervised", map["status"])
        assertEquals(1735689600000L, map["significantChangeApprovalDate"])
        // iOS-only key must exist and be null so the Dart map shape is stable
        assertNull(map["activeParentalControls"])
    }

    @Test
    fun resultToMap_omittedApprovalDateIsNull() {
        val result = plugin.buildMockResult(mapOf("status" to "verified"))
        val map = plugin.resultToMap(result)

        assertEquals("verified", map["status"])
        assertNull(map["significantChangeApprovalDate"])
    }

    // --- Status derivation from ageRangeSource + significantChangeStatus ---

    @Test
    fun resultToMap_statusRoundTripsForEveryMockStatus() {
        // buildMockResult translates a status into the tier/change-status pair
        // and resultToMap derives it back; the two mappings must stay inverse
        // or mocked scenarios silently shift meaning.
        val statuses = listOf(
            "supervised",
            "supervisedApprovalPending",
            "supervisedApprovalDenied",
            "verified",
            "declared",
            "unknown",
        )
        for (status in statuses) {
            val map = plugin.resultToMap(plugin.buildMockResult(mapOf("status" to status)))
            assertEquals(status, map["status"])
        }
    }

    @Test
    fun resultToMap_exposesTierAndChangeStatus() {
        val map = plugin.resultToMap(
            plugin.buildMockResult(mapOf("status" to "supervisedApprovalPending")),
        )

        assertEquals("supervisedApprovalPending", map["status"])
        assertEquals("tierB", map["ageRangeSource"])
        assertEquals("pending", map["significantChangeStatus"])
    }

    @Test
    fun resultToMap_tierBApproved_reportsSupervisedWithApprovedChange() {
        // APPROVED must not shift the status: only pending/declined refine the
        // supervised family.
        val map = plugin.resultToMap(
            plugin.buildMockResult(
                mapOf("status" to "supervised", "significantChangeStatus" to "approved"),
            ),
        )

        assertEquals("supervised", map["status"])
        assertEquals("tierB", map["ageRangeSource"])
        assertEquals("approved", map["significantChangeStatus"])
    }

    @Test
    fun resultToMap_tierDVerified_reportsVerifiedWithExplicitTier() {
        val result = plugin.buildMockResult(
            mapOf("status" to "verified", "ageRangeSource" to "tierD"),
        )
        val map = plugin.resultToMap(result)

        assertEquals("verified", map["status"])
        assertEquals("tierD", map["ageRangeSource"])
    }

    @Test
    fun resultToMap_unknown_hasNullTierAndChangeStatus() {
        val map = plugin.resultToMap(plugin.buildMockResult(mapOf("status" to "unknown")))

        assertEquals("unknown", map["status"])
        assertNull(map["ageRangeSource"])
        assertNull(map["significantChangeStatus"])
    }
}
