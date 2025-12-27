import 'age_range_signals_platform_interface.dart';
import 'src/models/age_signals_result.dart';
import 'src/models/age_signals_mock_data.dart';

export 'src/models/age_signals_result.dart';
export 'src/models/age_signals_mock_data.dart';
export 'src/exceptions/age_signals_exception.dart';

/// Flutter plugin for age verification.
///
/// Supports Google Play Age Signals API on Android and Apple's
/// DeclaredAgeRange API on iOS 26+.
///
/// Example usage:
/// ```dart
/// // Initialize with age gates (iOS only, optional on Android)
/// await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
///
/// // Check age signals
/// try {
///   final result = await AgeRangeSignals.instance.checkAgeSignals();
///
///   switch (result.status) {
///     case AgeSignalsStatus.verified:
///       print('User is verified');
///       break;
///     case AgeSignalsStatus.supervised:
///       print('User is under supervision');
///       break;
///     case AgeSignalsStatus.declined:
///       print('User declined to share age');
///       break;
///     case AgeSignalsStatus.unknown:
///       print('Age information not available');
///       break;
///   }
/// } on AgeSignalsException catch (e) {
///   print('Error: $e');
/// }
/// ```
class AgeRangeSignals {
  /// Returns the singleton instance of [AgeRangeSignals].
  static AgeRangeSignals get instance => _instance;
  static final AgeRangeSignals _instance = AgeRangeSignals._();

  AgeRangeSignals._();

  /// Initializes the plugin with platform-specific configuration.
  ///
  /// On iOS, [ageGates] specifies the age thresholds to use for age verification.
  /// For example, `[13, 16, 18]` will allow the app to determine if the user is
  /// under 13, between 13-15, between 16-17, or 18+.
  ///
  /// **Testing with Mock Data (Android only)**
  ///
  /// Set [useMockData] to true to use fake/test data instead of real APIs.
  /// When [useMockData] is true, you can optionally provide [mockData] to
  /// customize the mock response using Google's official [FakeAgeSignalsManager].
  ///
  /// **IMPORTANT:** Mock data is only supported on Android. Apple does not provide
  /// official testing utilities for the DeclaredAgeRange API. On iOS, the
  /// [useMockData] and [mockData] parameters are ignored, and the real API is
  /// always used. iOS testing requires real iOS 26.2+ devices.
  ///
  /// Should be called before [checkAgeSignals].
  ///
  /// Example:
  /// ```dart
  /// // For testing with custom mock data (Android only)
  /// await AgeRangeSignals.instance.initialize(
  ///   useMockData: true,  // Ignored on iOS
  ///   mockData: AgeSignalsMockData(
  ///     status: AgeSignalsStatus.supervised,
  ///     ageLower: 16,
  ///     ageUpper: 17,
  ///   ),
  /// );
  ///
  /// // For production with real APIs
  /// await AgeRangeSignals.instance.initialize(
  ///   ageGates: [13, 16, 18],  // Required for iOS
  ///   useMockData: false,
  /// );
  /// ```
  Future<void> initialize({
    List<int>? ageGates,
    bool useMockData = false,
    AgeSignalsMockData? mockData,
  }) {
    return AgeRangeSignalsPlatform.instance.initialize(
      ageGates: ageGates,
      useMockData: useMockData,
      mockData: mockData,
    );
  }

  /// Checks the age signals for the current user.
  ///
  /// Returns an [AgeSignalsResult] containing the verification status and
  /// any available age information.
  ///
  /// On iOS, you must call [initialize] with age gates before calling this method.
  ///
  /// Throws [AgeSignalsException] if an error occurs during the check.
  Future<AgeSignalsResult> checkAgeSignals() {
    return AgeRangeSignalsPlatform.instance.checkAgeSignals();
  }
}
