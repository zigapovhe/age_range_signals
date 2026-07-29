import 'age_signals_access_status.dart';
import 'age_signals_result.dart';

/// Configuration for mock/test data used when `useMockData` is true.
///
/// **Android only** - Uses Google's official `FakeAgeSignalsManager` for testing.
/// Apple does not provide testing utilities for DeclaredAgeRange API, so mock
/// data is not supported on iOS.
///
/// Allows customizing the mock response from Dart without modifying
/// native platform code. Useful for testing different scenarios
/// and automated testing on Android.
///
/// Example (Android only):
/// ```dart
/// await AgeRangeSignals.instance.initialize(
///   useMockData: true,  // Ignored on iOS
///   mockData: AgeSignalsMockData(
///     status: AgeSignalsStatus.supervised,
///     ageLower: 16,
///     ageUpper: 17,
///   ),
/// );
/// ```
class AgeSignalsMockData {
  /// Creates mock data configuration.
  const AgeSignalsMockData({
    required this.status,
    this.ageLower,
    this.ageUpper,
    @Deprecated(
      'Unused on every platform. Use ageRangeSource to select the Play tier. '
      'This field will be removed in a future release.',
    )
    this.source,
    this.installId,
    this.accessStatus,
    this.ageRangeSource,
    this.significantChangeStatus,
    DateTime? significantChangeApprovalDate,
    @Deprecated(
      'Use significantChangeApprovalDate instead. '
      'This alias will be removed in a future release.',
    )
    DateTime? mostRecentApprovalDate,
  }) : significantChangeApprovalDate =
           significantChangeApprovalDate ?? mostRecentApprovalDate;

  /// The mock verification status to return.
  final AgeSignalsStatus status;

  /// The mock lower bound of the user's age range.
  ///
  /// Should be provided for supervised status on Android.
  /// Can be null for verified status.
  final int? ageLower;

  /// The mock upper bound of the user's age range.
  ///
  /// Should be provided for supervised status on Android.
  /// Can be null for verified status.
  final int? ageUpper;

  /// Unused. `AgeDeclarationSource` is an iOS concept, and mock data is
  /// Android only, so nothing reads this. Use [ageRangeSource] to select the
  /// Play tier the fake manager reports.
  @Deprecated(
    'Unused on every platform. Use ageRangeSource to select the Play tier. '
    'This field will be removed in a future release.',
  )
  final AgeDeclarationSource? source;

  /// Mock unique identifier for this app installation (Android only).
  ///
  /// Only used when testing Android scenarios.
  final String? installId;

  /// The mock outcome of `requestAgeSignalsAccess()` (Android only).
  ///
  /// Defaults to [AgeSignalsAccessStatus.shared] when null, so mocked
  /// flows proceed straight into `checkAgeSignals()`. Set
  /// [AgeSignalsAccessStatus.notShared] or
  /// [AgeSignalsAccessStatus.verificationRequired] to exercise the paths
  /// where no age signals may be requested.
  final AgeSignalsAccessStatus? accessStatus;

  /// Explicit mock [AgeRangeSource] tier (Android only).
  ///
  /// When null, the tier is derived from [status] (verified maps to tierC,
  /// declared to tierA, the supervised family to tierB). The result's
  /// status is always re-derived from the resulting age band measured against
  /// your highest age gate (plus the supervised approval short-circuit),
  /// exactly as with real API responses, so an explicit tier wins over a
  /// contradictory [status]. Set it to pin a specific tier, e.g. verified
  /// via [AgeRangeSource.tierD].
  final AgeRangeSource? ageRangeSource;

  /// Explicit mock [SignificantChangeStatus] (Android only).
  ///
  /// When null, it is derived from [status]
  /// (supervisedApprovalPending maps to pending, supervisedApprovalDenied
  /// to declined, otherwise unset).
  final SignificantChangeStatus? significantChangeStatus;

  /// Mock significant change approval date (Android only).
  ///
  /// Maps to the `significantChangeApprovalDate` reported by the Play Age
  /// Signals API for supervised users.
  final DateTime? significantChangeApprovalDate;

  /// Renamed to [significantChangeApprovalDate] in 0.8.0, following Play
  /// age-signals 0.0.4, which renamed the underlying field.
  @Deprecated(
    'Use significantChangeApprovalDate instead. '
    'This alias will be removed in a future release.',
  )
  DateTime? get mostRecentApprovalDate => significantChangeApprovalDate;

  /// Converts this mock data to a map for platform channel.
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'ageLower': ageLower,
      'ageUpper': ageUpper,
      'source': source?.name,
      'installId': installId,
      'accessStatus': accessStatus?.name,
      'ageRangeSource': ageRangeSource?.name,
      'significantChangeStatus': significantChangeStatus?.name,
      'significantChangeApprovalDate':
          significantChangeApprovalDate?.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this mock data with the given fields replaced.
  AgeSignalsMockData copyWith({
    AgeSignalsStatus? status,
    int? ageLower,
    int? ageUpper,
    @Deprecated(
      'Unused on every platform. Use ageRangeSource to select the Play tier. '
      'This field will be removed in a future release.',
    )
    AgeDeclarationSource? source,
    String? installId,
    AgeSignalsAccessStatus? accessStatus,
    AgeRangeSource? ageRangeSource,
    SignificantChangeStatus? significantChangeStatus,
    DateTime? significantChangeApprovalDate,
    @Deprecated(
      'Use significantChangeApprovalDate instead. '
      'This alias will be removed in a future release.',
    )
    DateTime? mostRecentApprovalDate,
  }) {
    return AgeSignalsMockData(
      status: status ?? this.status,
      ageLower: ageLower ?? this.ageLower,
      ageUpper: ageUpper ?? this.ageUpper,
      source: source ?? this.source,
      installId: installId ?? this.installId,
      accessStatus: accessStatus ?? this.accessStatus,
      ageRangeSource: ageRangeSource ?? this.ageRangeSource,
      significantChangeStatus:
          significantChangeStatus ?? this.significantChangeStatus,
      significantChangeApprovalDate:
          significantChangeApprovalDate ??
          mostRecentApprovalDate ??
          this.significantChangeApprovalDate,
    );
  }

  @override
  String toString() {
    return 'AgeSignalsMockData(status: $status, ageLower: $ageLower, '
        'ageUpper: $ageUpper, source: $source, installId: $installId, '
        'accessStatus: $accessStatus, ageRangeSource: $ageRangeSource, '
        'significantChangeStatus: $significantChangeStatus, '
        'significantChangeApprovalDate: $significantChangeApprovalDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AgeSignalsMockData &&
        other.status == status &&
        other.ageLower == ageLower &&
        other.ageUpper == ageUpper &&
        other.source == source &&
        other.installId == installId &&
        other.accessStatus == accessStatus &&
        other.ageRangeSource == ageRangeSource &&
        other.significantChangeStatus == significantChangeStatus &&
        other.significantChangeApprovalDate?.millisecondsSinceEpoch ==
            significantChangeApprovalDate?.millisecondsSinceEpoch;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      ageLower,
      ageUpper,
      source,
      installId,
      accessStatus,
      ageRangeSource,
      significantChangeStatus,
      significantChangeApprovalDate?.millisecondsSinceEpoch,
    );
  }
}
