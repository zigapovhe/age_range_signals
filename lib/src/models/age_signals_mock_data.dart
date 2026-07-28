import 'age_signals_result.dart';

/// Configuration for mock/test data used when [useMockData] is true.
///
/// **Android only** - Uses Google's official [FakeAgeSignalsManager] for testing.
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
    this.source,
    this.installId,
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
  /// Play reports a band for adults too, so a `verified` mock defaults to 18
  /// rather than null. Supply a value below your adult threshold and the mock
  /// comes back as `supervised`, matching how the real API is interpreted.
  final int? ageLower;

  /// The mock upper bound of the user's age range.
  ///
  /// Null represents the open-ended top band (e.g. `ageLower: 18` with no
  /// upper bound), which is what a `verified` mock produces by default.
  final int? ageUpper;

  /// The mock assurance tier to report.
  ///
  /// Android only, and load-bearing: it selects the Play `AgeRangeSource`
  /// tier the fake manager returns, which in turn decides the derived
  /// [AgeSignalsStatus] and whether `installId` is populated. When omitted,
  /// the tier is inferred from [status]. Ignored on iOS.
  final AgeDeclarationSource? source;

  /// Mock unique identifier for this app installation (Android only).
  ///
  /// Only used when testing Android scenarios.
  final String? installId;

  /// Mock guardian approval date (Android only).
  ///
  /// Maps to the `significantChangeApprovalDate` reported by the Play Age Signals
  /// API for supervised users.
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
      'significantChangeApprovalDate':
          significantChangeApprovalDate?.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this mock data with the given fields replaced.
  AgeSignalsMockData copyWith({
    AgeSignalsStatus? status,
    int? ageLower,
    int? ageUpper,
    AgeDeclarationSource? source,
    String? installId,
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
      significantChangeApprovalDate?.millisecondsSinceEpoch,
    );
  }
}
