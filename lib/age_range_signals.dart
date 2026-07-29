/// Age verification for Flutter, backed by the platform's own age signals.
///
/// This is the entry point most apps need. Import it and call
/// [AgeRangeSignals.instance]; the method channel and platform interface
/// libraries are plumbing and should not be imported directly.
library;

import 'age_range_signals_platform_interface.dart';
import 'src/exceptions/age_signals_exception.dart';
import 'src/models/age_regulatory_feature.dart';
import 'src/models/age_signals_access_status.dart';
import 'src/models/age_signals_result.dart';
import 'src/models/age_signals_mock_data.dart';

export 'src/models/age_signals_result.dart';
export 'src/models/age_signals_access_status.dart';
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
/// // Initialize with age gates (required on iOS, and used on Android as the bar for `verified`)
/// await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
///
/// // Request access, then check age signals
/// try {
///   final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
///   if (access != AgeSignalsAccessStatus.shared) {
///     print('No age signals to read: $access');
///     return;
///   }
///
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
  /// customize the mock response using Google's official `FakeAgeSignalsManager`.
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
  ///   ageGates: [13, 16, 18],  // Both platforms
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

  /// Requests access to the current user's age signals (Android).
  ///
  /// Since age-signals 0.0.4, Google Play splits age signals across two
  /// calls: this one asks for access - showing Play's in-app age sharing
  /// prompt when the user's Play settings call for asking first - and
  /// [checkAgeSignals] then reads the signals. Call this before
  /// [checkAgeSignals] and only read signals once access is
  /// [AgeSignalsAccessStatus.shared]:
  ///
  /// ```dart
  /// final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
  /// if (access == AgeSignalsAccessStatus.shared) {
  ///   final result = await AgeRangeSignals.instance.checkAgeSignals();
  /// }
  /// ```
  ///
  /// A refusal is not an error: it returns
  /// [AgeSignalsAccessStatus.notShared]. In regions with mandatory
  /// verification laws Play skips the prompt entirely: already-verified and
  /// supervised users come back [AgeSignalsAccessStatus.shared], while
  /// unverified users come back
  /// [AgeSignalsAccessStatus.verificationRequired] and complete
  /// verification in the Play Store app before signals become available.
  ///
  /// On iOS this returns [AgeSignalsAccessStatus.shared] without showing
  /// anything, because Apple gathers consent inside [checkAgeSignals]
  /// itself and a refusal surfaces there as [AgeSignalsStatus.declined].
  /// Returning shared keeps a single call sequence working on both
  /// platforms. It is not unconditional, though: iOS throws rather than
  /// reporting access it could not honour, so this call also acts as a
  /// pre-flight there.
  ///
  /// Throws [AgeSignalsException] subclasses on API errors:
  ///
  /// * [ApiErrorException] with code `PRESENTATION_CONTEXT_UNAVAILABLE`
  ///   when no activity is available to present the prompt on (Android).
  /// * [UnsupportedPlatformException] on iOS below 26.0, where
  ///   [checkAgeSignals] could not succeed anyway.
  /// * [NotInitializedException] on iOS when [initialize] has not supplied
  ///   age gates. Android has no such guard, so call [initialize] first on
  ///   both platforms.
  Future<AgeSignalsAccessStatus> requestAgeSignalsAccess() {
    return AgeRangeSignalsPlatform.instance.requestAgeSignalsAccess();
  }

  /// Checks the age signals for the current user.
  ///
  /// Returns an [AgeSignalsResult] containing the verification status and
  /// any available age information.
  ///
  /// On Android, call [requestAgeSignalsAccess] first; without shared
  /// access the Play Age Signals API returns no signals and the status is
  /// [AgeSignalsStatus.unknown].
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
  /// Use this to decide whether you need to prompt at all: an empty set
  /// means Apple affirmatively reports that no regulatory action is
  /// required for this user. If the set does not contain
  /// [AgeRegulatoryFeature.declaredAgeRangeRequired], Apple imposes no
  /// obligation to request this user's age range.
  ///
  /// Returns an empty set on Android: the Play Age Signals API has no
  /// equivalent concept and implicitly limits itself to regions where it
  /// is legally required, so "nothing to report" is the true answer there.
  ///
  /// Throws [UnsupportedPlatformException] on iOS below 26.4 and in apps
  /// built with an SDK older than iOS 26.4 (Xcode < 26.4), where the
  /// requirement cannot be checked. This keeps the empty set unambiguous;
  /// keep your own regional logic for those devices. Throws other
  /// [AgeSignalsException] subclasses on API errors.
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
  /// Completing normally means the person acknowledged the sheet. Every
  /// other outcome is an exception:
  ///
  /// * [ArgumentError] if [updateDescription] is empty.
  /// * [UnsupportedPlatformException] on Android and on iOS below 26.4.
  ///   This is deliberate: silently succeeding would let an app believe it
  ///   satisfied a notification duty when no sheet was ever shown.
  /// * [ApiNotAvailableException] when Apple reports the acknowledgment is
  ///   not available. Apple uses the same error when the person dismisses
  ///   the sheet, so do not treat this as proof the sheet never appeared.
  /// * [UserCancelledException] when the system reports an explicit
  ///   cancellation.
  /// * [ApiErrorException] for other API failures, including when no window
  ///   scene is available to present on.
  Future<void> showSignificantUpdateAcknowledgment({
    required String updateDescription,
  }) {
    if (updateDescription.trim().isEmpty) {
      throw ArgumentError.value(
        updateDescription,
        'updateDescription',
        'must not be empty; it is shown to the user inside the system sheet',
      );
    }
    return AgeRangeSignalsPlatform.instance.showSignificantUpdateAcknowledgment(
      updateDescription: updateDescription,
    );
  }
}
