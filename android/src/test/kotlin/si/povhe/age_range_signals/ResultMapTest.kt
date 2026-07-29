package si.povhe.age_range_signals

import com.google.android.play.agesignals.model.AgeRangeSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import com.google.android.play.agesignals.model.SignificantChangeStatus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
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

    @Test
    fun deriveStatus_unspecifiedTierIsUnknown() {
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "unknown",
            plugin.deriveStatus(AgeRangeSource.UNSPECIFIED, SignificantChangeStatus.APPROVED, 18, 18),
        )
    }

    @Test
    fun deriveStatus_unrecognisedTierWithBoundsStillJudgesByAge() {
        // A tier a future library version adds must not collapse to `unknown`
        // while a real age band is available.
        val plugin = AgeRangeSignalsPlugin()
        val futureTier = 99

        assertEquals(
            "verified",
            plugin.deriveStatus(futureTier, SignificantChangeStatus.APPROVED, 18, 18),
        )
        assertEquals(
            "supervised",
            plugin.deriveStatus(futureTier, SignificantChangeStatus.APPROVED, 13, 18),
        )
    }

    @Test
    fun deriveStatus_guardianAttestedAdultIsVerifiedLikeOnIos() {
        // Supervision is reported through `ageRangeSource`, not by overriding
        // the verdict. iOS returns `verified` for the same user.
        val plugin = AgeRangeSignalsPlugin()

        assertEquals(
            "verified",
            plugin.deriveStatus(AgeRangeSource.TIER_B, SignificantChangeStatus.APPROVED, 18, 18),
        )
    }

    // --- mock shorthand stays faithful at non-default gates ---

    @Test
    fun mockShorthand_holdsAtANonDefaultHighGate() {
        // With ageGates: [21] a `verified` mock must still derive `verified`.
        // Pinning the implied band to 18 would derive `supervised` (18 < 21).
        val plugin = AgeRangeSignalsPlugin()
        plugin.onMethodCall(
            MethodCall("initialize", mapOf("ageGates" to listOf(21))),
            Mockito.mock(MethodChannel.Result::class.java),
        )

        val map = plugin.resultToMap(plugin.buildMockResult(mapOf("status" to "verified")))
        assertEquals("verified", map["status"])
    }

    @Test
    fun mockShorthand_holdsAtANonDefaultLowGate() {
        // With ageGates: [13] the default supervised band must still derive
        // `supervised`. A fixed 13-15 band would clear the gate (13 >= 13).
        val plugin = AgeRangeSignalsPlugin()
        plugin.onMethodCall(
            MethodCall("initialize", mapOf("ageGates" to listOf(13))),
            Mockito.mock(MethodChannel.Result::class.java),
        )

        val map = plugin.resultToMap(plugin.buildMockResult(mapOf("status" to "supervised")))
        assertEquals("supervised", map["status"])
    }

    @Test
    fun initialize_storesTheHighestGateAsTheVerifiedBar() {
        val plugin = AgeRangeSignalsPlugin()
        plugin.onMethodCall(
            MethodCall("initialize", mapOf("ageGates" to listOf(13, 16, 18))),
            Mockito.mock(MethodChannel.Result::class.java),
        )

        val band17 = plugin.buildMockResult(
            mapOf("status" to "supervised", "ageLower" to 17, "ageUpper" to 17),
        )
        assertEquals("supervised", plugin.resultToMap(band17)["status"])

        val band18 = plugin.buildMockResult(mapOf("status" to "supervised", "ageLower" to 18))
        assertEquals("verified", plugin.resultToMap(band18)["status"])
    }

    // --- mock bands must be shapes Play can actually return ---

    @Test
    fun mockBands_areAlwaysRealPlayBands() {
        val plugin = AgeRangeSignalsPlugin()

        // Never an inverted or single-year band invented by arithmetic.
        for (gate in listOf(0, 1, 13, 14, 15, 16, 18, 21)) {
            val (low, high) = plugin.supervisedBandBelow(gate)
            assertTrue(low >= 0, "band lower bound went negative at gate $gate")
            assertTrue(high >= low, "inverted band at gate $gate")
            assertTrue(
                (low to high) == (0 to 12) || (low to high) == (13 to 15),
                "band $low-$high at gate $gate is not one Play returns",
            )
        }
    }

    @Test
    fun mockBand_explicitUpperNeverInvertsTheRange() {
        val plugin = AgeRangeSignalsPlugin()
        val result = plugin.buildMockResult(
            mapOf("status" to "supervised", "ageUpper" to 12),
        )

        val low = result.ageLower()!!
        val high = result.ageUpper()!!
        assertTrue(high >= low, "mock produced an inverted band $low-$high")
    }

    @Test
    fun mockBand_explicitUpperSurvivesOnUnsupervisedTiers() {
        val plugin = AgeRangeSignalsPlugin()
        val result = plugin.buildMockResult(
            mapOf("status" to "verified", "ageUpper" to 20),
        )

        assertEquals(20, result.ageUpper())
    }

    @Test
    fun initialize_withoutGatesKeepsThePreviouslyConfiguredBar() {
        // iOS keeps its gates when a later initialize() omits them; Android
        // must not silently reset the bar to 18.
        val plugin = AgeRangeSignalsPlugin()
        val ok = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("initialize", mapOf("ageGates" to listOf(21))), ok)
        plugin.onMethodCall(MethodCall("initialize", mapOf("useMockData" to false)), ok)

        val band18 = plugin.buildMockResult(mapOf("status" to "supervised", "ageLower" to 18))
        assertEquals("supervised", plugin.resultToMap(band18)["status"])
    }
}
