package si.povhe.age_range_signals

import com.google.android.play.agesignals.model.AgeRangeSource
import com.google.android.play.agesignals.model.SignificantChangeStatus
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
            "unknown",
        )
        for (status in statuses) {
            val map = plugin.resultToMap(plugin.buildMockResult(mapOf("status" to status)))
            assertEquals(status, map["status"])
        }

        // `declared` is the one status that no longer round-trips: the verdict
        // now comes from the age band, so a self-declared adult is `verified`
        // and the tier is read from ageRangeSource instead.
        val declared = plugin.resultToMap(plugin.buildMockResult(mapOf("status" to "declared")))
        assertEquals("supervised", declared["status"])
        assertEquals("tierA", declared["ageRangeSource"])
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

    // --- the verdict comes from the age, not the tier ---

    @Test
    fun deriveStatus_idVerifiedMinorIsNotVerified() {
        // TIER_D means an ID was checked, and that ID can read 12. Treating the
        // tier as the verdict would let a minor clear an adult gate.
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "supervised",
            plugin.deriveStatus(AgeRangeSource.TIER_D, SignificantChangeStatus.APPROVED, 13, 18),
        )
        assertEquals(
            "verified",
            plugin.deriveStatus(AgeRangeSource.TIER_D, SignificantChangeStatus.APPROVED, 18, 18),
        )
    }

    @Test
    fun deriveStatus_estimatedMinorIsNotVerified() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "supervised",
            plugin.deriveStatus(AgeRangeSource.TIER_C, SignificantChangeStatus.APPROVED, 16, 18),
        )
    }

    @Test
    fun deriveStatus_selfDeclaredAdultClearsTheGate() {
        // TIER_A is unsupervised, so the age decides. Short-circuiting it to
        // `declared` would block a self-declared adult while the stronger
        // TIER_C passed automatically.
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "verified",
            plugin.deriveStatus(AgeRangeSource.TIER_A, SignificantChangeStatus.APPROVED, 18, 18),
        )
    }

    @Test
    fun deriveStatus_honoursTheCallersHighestGate() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "verified",
            plugin.deriveStatus(AgeRangeSource.TIER_D, SignificantChangeStatus.APPROVED, 16, 13),
        )
        assertEquals(
            "supervised",
            plugin.deriveStatus(AgeRangeSource.TIER_D, SignificantChangeStatus.APPROVED, 16, 18),
        )
    }

    @Test
    fun deriveStatus_guardianApprovalStatesWinOverAge() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "supervisedApprovalPending",
            plugin.deriveStatus(AgeRangeSource.TIER_B, SignificantChangeStatus.PENDING, 18, 18),
        )
    }

    @Test
    fun deriveStatus_missingTierOrBandIsUnknown() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "unknown",
            plugin.deriveStatus(null, SignificantChangeStatus.APPROVED, 18, 18),
        )
        assertEquals(
            "unknown",
            plugin.deriveStatus(AgeRangeSource.TIER_D, SignificantChangeStatus.APPROVED, null, 18),
        )
    }
}
