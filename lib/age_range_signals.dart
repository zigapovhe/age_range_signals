import 'age_range_signals_platform_interface.dart';
import 'src/exceptions/age_signals_exception.dart';
import 'src/models/age_regulatory_feature.dart';
import 'src/models/age_signals_result.dart';
import 'src/models/age_signals_mock_data.dart';

export 'src/models/age_signals_result.dart';
export 'src/models/age_signals_mock_data.dart';
export 'src/exceptions/age_signals_exception.dart';
export 'src/models/age_regulatory_feature.dart';

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
  /// Apple requires 1 to 3 gates and at least 2 years between consecutive
  /// gates (`[13, 14]` is rejected by the OS with an invalid-request error;
  /// `[13, 16, 18]` is fine).
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

  /// Returns the regulatory features Apple reports as required for the
  /// current user, based on their region and account settings (iOS 26.4+).
  ///
  /// Use this to decide whether you need to prompt at all: if the returned
  /// set does not contain [AgeRegulatoryFeature.declaredAgeRangeRequired],
  /// Apple imposes no obligation to request this user's age range.
  ///
  /// Returns an empty set on Android (the Play Age Signals API has no
  /// equivalent; it implicitly limits itself to regions where it is legally
  /// required) and on iOS below 26.4. Requires building with an Xcode that
  /// ships the iOS 26.4 SDK; on older SDKs the method also returns an empty
  /// set.
  ///
  /// Throws [AgeSignalsException] subclasses on API errors.
  Future<Set<AgeRegulatoryFeature>> getRequiredRegulatoryFeatures() {
    return AgeRangeSignalsPlatform.instance.getRequiredRegulatoryFeatures();
  }

  /// Shows Apple's system acknowledgment sheet for a significant app update
  /// (iOS 26.4+).
  ///
  /// Call this when [getRequiredRegulatoryFeatures] contains
  /// [AgeRegulatoryFeature.significantAppChangeRequiresAdultNotification]
  /// and you shipped a change that regulators consider significant.
  /// [updateDescription] is shown to the user inside the system sheet.
  ///
  /// Throws [UnsupportedPlatformException] on Android and on iOS below
  /// 26.4. This is deliberate: silently succeeding would let an app believe
  /// it satisfied a notification duty when no sheet was ever shown.
  Future<void> showSignificantUpdateAcknowledgment({
    required String updateDescription,
  }) {
    return AgeRangeSignalsPlatform.instance.showSignificantUpdateAcknowledgment(
      updateDescription: updateDescription,
    );
  }
}
