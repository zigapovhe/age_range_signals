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
  });

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

  /// The mock source of the age declaration.
  ///
  /// Not used on any platform currently (reserved for future use).
  final AgeDeclarationSource? source;

  /// Mock unique identifier for this app installation (Android only).
  ///
  /// Only used when testing Android scenarios.
  final String? installId;

  /// Converts this mock data to a map for platform channel.
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'ageLower': ageLower,
      'ageUpper': ageUpper,
      'source': source?.name,
      'installId': installId,
    };
  }

  /// Creates a copy of this mock data with the given fields replaced.
  AgeSignalsMockData copyWith({
    AgeSignalsStatus? status,
    int? ageLower,
    int? ageUpper,
    AgeDeclarationSource? source,
    String? installId,
  }) {
    return AgeSignalsMockData(
      status: status ?? this.status,
      ageLower: ageLower ?? this.ageLower,
      ageUpper: ageUpper ?? this.ageUpper,
      source: source ?? this.source,
      installId: installId ?? this.installId,
    );
  }

  @override
  String toString() {
    return 'AgeSignalsMockData(status: $status, ageLower: $ageLower, '
        'ageUpper: $ageUpper, source: $source, installId: $installId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AgeSignalsMockData &&
        other.status == status &&
        other.ageLower == ageLower &&
        other.ageUpper == ageUpper &&
        other.source == source &&
        other.installId == installId;
  }

  @override
  int get hashCode {
    return Object.hash(status, ageLower, ageUpper, source, installId);
  }
}
