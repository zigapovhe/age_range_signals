package si.povhe.age_range_signals

import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.model.AgeSignalsStatus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ResultMapTest {
    private val plugin = AgeRangeSignalsPlugin()

    // Mirrors checkAgeSignals: only a SHARED user has signals to read, so a
    // non-SHARED access status must be paired with a null result the way
    // production does, not with a mock result production could never emit.
    private fun mapFor(mock: Map<String, Any?>): Map<String, Any?> {
        val access = plugin.buildMockAccessResult(mock).ageSignalsStatus()
        val result = if (access == AgeSignalsStatus.SHARED) {
            plugin.buildMockResult(mock)
        } else {
            null
        }
        return plugin.resultToMap(result, access)
    }

    @Test
    fun resultToMap_includesApprovalDateMillis() {
        val map = mapFor(
            mapOf(
                "status" to "supervised",
                "ageLower" to 13,
                "ageUpper" to 15,
                "installId" to "test_id",
                "significantChangeApprovalDate" to 1735689600000L,
            )
        )

        assertEquals("supervised", map["status"])
        assertEquals(1735689600000L, map["significantChangeApprovalDate"])
        // iOS-only key must exist and be null so the Dart map shape is stable
        assertNull(map["activeParentalControls"])
    }

    @Test
    fun resultToMap_omittedApprovalDateIsNull() {
        val map = mapFor(mapOf("status" to "verified"))

        assertEquals("verified", map["status"])
        assertNull(map["significantChangeApprovalDate"])
    }

    // --- status derivation from the 0.0.4 signals ---

    @Test
    fun deriveStatus_notSharedIsUnknownNotDeclined() {
        // Play returns NOT_SHARED both for a refusal and for an out-of-scope
        // region, so it must not be reported as a deliberate decline.
        assertEquals("unknown", plugin.deriveStatus(AgeSignalsStatus.NOT_SHARED, null))
    }

    @Test
    fun deriveStatus_verificationRequiredIsSurfaced() {
        assertEquals(
            "verificationRequired",
            plugin.deriveStatus(AgeSignalsStatus.VERIFICATION_REQUIRED, null),
        )
    }

    @Test
    fun deriveStatus_unspecifiedAndNullAreUnknown() {
        assertEquals("unknown", plugin.deriveStatus(AgeSignalsStatus.UNSPECIFIED, null))
        assertEquals("unknown", plugin.deriveStatus(null, null))
    }

    @Test
    fun deriveStatus_guardianAttestedMinorIsSupervised() {
        assertEquals("supervised", mapFor(mapOf("status" to "supervised"))["status"])
    }

    @Test
    fun deriveStatus_guardianAttestedAdultIsVerifiedLikeOnIos() {
        // Supervision is reported through `source`, not by overriding the
        // verdict. iOS returns `verified` for the same user, and one `status`
        // check has to mean the same thing on both platforms.
        val adult = plugin.buildMockResult(
            mapOf("status" to "supervised", "ageLower" to 18, "ageUpper" to null),
        )

        assertEquals("verified", plugin.deriveStatus(AgeSignalsStatus.SHARED, adult, 18))
        assertEquals("guardianDeclared", plugin.sourceToName(adult.ageRangeSource()))
    }

    @Test
    fun deriveStatus_guardianApprovalStatesWinOverAge() {
        // An outstanding guardian decision is actionable whatever the age.
        val pendingAdult = plugin.buildMockResult(
            mapOf("status" to "supervisedApprovalPending", "ageLower" to 18),
        )

        assertEquals(
            "supervisedApprovalPending",
            plugin.deriveStatus(AgeSignalsStatus.SHARED, pendingAdult, 18),
        )
    }

    @Test
    fun deriveStatus_selfDeclaredAdultIsVerifiedNotBlocked() {
        // TIER_A is unsupervised, so the verdict comes from the age. Reporting
        // `declared` here would stop a self-declared adult clearing a gate that
        // the weaker `estimated` tier can clear.
        val map = mapFor(mapOf("status" to "declared", "ageLower" to 18))

        assertEquals("verified", map["status"])
        assertEquals("selfDeclared", map["source"])
    }

    @Test
    fun deriveStatus_pendingApprovalDoesNotDowngradeAnUnsupervisedAdult() {
        // significantChangeStatus describes the guardian relationship, so it
        // must not relabel an ID-verified adult as a supervised minor.
        val map = mapFor(
            mapOf(
                "status" to "supervisedApprovalPending",
                "source" to "idVerified",
                "ageLower" to 18,
            )
        )

        assertEquals("verified", map["status"])
    }

    @Test
    fun deriveStatus_unrecognisedTierWithBoundsStillJudgesByAge() {
        // A tier this version does not know must not produce `unknown` while
        // resultToMap forwards a real age band.
        val noTier = AgeSignalsResult.builder()
            .setAgeLower(13)
            .setAgeUpper(15)
            .build()

        assertEquals("supervised", plugin.deriveStatus(AgeSignalsStatus.SHARED, noTier, 18))
    }

    @Test
    fun deriveStatus_sharedWithNoBoundsIsUnknown() {
        val empty = AgeSignalsResult.builder().build()

        assertEquals("unknown", plugin.deriveStatus(AgeSignalsStatus.SHARED, empty, 18))
    }

    @Test
    fun deriveStatus_honoursTheCallersHighestAgeGate() {
        // iOS compares against the caller's highest gate; Android must agree.
        val sixteen = plugin.buildMockResult(
            mapOf("status" to "verified", "source" to "idVerified", "ageLower" to 16),
        )
        assertEquals("supervised", plugin.deriveStatus(AgeSignalsStatus.SHARED, sixteen, 18))
        assertEquals("verified", plugin.deriveStatus(AgeSignalsStatus.SHARED, sixteen, 13))
    }

    @Test
    fun deriveStatus_pendingAndDeclinedVersionApproval() {
        assertEquals(
            "supervisedApprovalPending",
            mapFor(mapOf("status" to "supervisedApprovalPending"))["status"],
        )
        assertEquals(
            "supervisedApprovalDenied",
            mapFor(mapOf("status" to "supervisedApprovalDenied"))["status"],
        )
    }

    @Test
    fun deriveStatus_unsupervisedAdultIsVerified() {
        val map = mapFor(mapOf("status" to "verified"))

        assertEquals("verified", map["status"])
        assertEquals("idVerified", map["source"])
    }

    @Test
    fun deriveStatus_unsupervisedMinorIsSupervised() {
        // TIER_C/TIER_D describe assurance, not supervision. A minor there is
        // still below the adult threshold, which is what `supervised` means
        // cross-platform, and `source` keeps the distinction visible.
        val map = mapFor(
            mapOf(
                "status" to "verified",
                "source" to "estimated",
                "ageLower" to 16,
                "ageUpper" to 17,
            )
        )

        assertEquals("supervised", map["status"])
        assertEquals("estimated", map["source"])
    }
}
