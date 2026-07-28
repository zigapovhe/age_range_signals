/// The platform interface that federated implementations of
/// `age_range_signals` extend.
///
/// Application code should import `package:age_range_signals/age_range_signals.dart`
/// instead. This library exists so alternative platform implementations, and
/// tests that need to stub the plugin, can hook into it.
library;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'age_range_signals_method_channel.dart';
import 'src/exceptions/age_signals_exception.dart';
import 'src/models/age_regulatory_feature.dart';
import 'src/models/age_signals_access_status.dart';
import 'src/models/age_signals_result.dart';
import 'src/models/age_signals_mock_data.dart';

/// The interface every `age_range_signals` platform implementation extends.
///
/// The default implementation, [MethodChannelAgeRangeSignals], talks to the
/// Play Age Signals API on Android and the DeclaredAgeRange API on iOS over a
/// method channel. Replace [instance] to stub the plugin in tests.
///
/// Do not call this from application code. [instance] bypasses the argument
/// validation performed by the public `AgeRangeSignals` wrapper, so use that
/// instead.
abstract class AgeRangeSignalsPlatform extends PlatformInterface {
  /// Constructs a AgeRangeSignalsPlatform.
  AgeRangeSignalsPlatform() : super(token: _token);
  static final Object _token = Object();

  static AgeRangeSignalsPlatform _instance = MethodChannelAgeRangeSignals();

  /// The default instance of [AgeRangeSignalsPlatform] to use.
  ///
  /// Defaults to [MethodChannelAgeRangeSignals].
  static AgeRangeSignalsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AgeRangeSignalsPlatform] when
  /// they register themselves.
  static set instance(AgeRangeSignalsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes the plugin with platform-specific configuration.
  ///
  /// [ageGates] specifies the age thresholds. iOS requires them; Play ignores them, but Android uses the highest gate as the bar for `verified`, falling back to 18.
  /// For example, [13, 16, 18] will allow the app to determine if the user is
  /// under 13, between 13-15, between 16-17, or 18+.
  ///
  /// Set [useMockData] to true to use fake/test data instead of real APIs.
  /// This is useful for testing before APIs are available or in development.
  /// When [useMockData] is true, you can optionally provide [mockData] to
  /// customize the mock response. If not provided, default mock data will be used.
  ///
  /// Should be called before [checkAgeSignals].
  Future<void> initialize({
    List<int>? ageGates,
    bool useMockData = false,
    AgeSignalsMockData? mockData,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Requests access to the current user's age signals (Android).
  ///
  /// May show Google Play's in-app age sharing prompt. Returns
  /// [AgeSignalsAccessStatus.shared] on iOS, where consent is gathered by
  /// [checkAgeSignals] itself.
  ///
  /// Throws [AgeSignalsException] if an error occurs during the request.
  Future<AgeSignalsAccessStatus> requestAgeSignalsAccess() {
    throw UnimplementedError(
      'requestAgeSignalsAccess() has not been implemented.',
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
    throw UnimplementedError('checkAgeSignals() has not been implemented.');
  }

  /// Returns the regulatory features Apple reports as required for the
  /// current user (iOS 26.4+).
  ///
  /// Returns an empty set on Android. Throws [UnsupportedPlatformException]
  /// on iOS below 26.4 and in apps built with a pre-26.4 SDK.
  Future<Set<AgeRegulatoryFeature>> getRequiredRegulatoryFeatures() {
    throw UnimplementedError(
      'getRequiredRegulatoryFeatures() has not been implemented.',
    );
  }

  /// Shows Apple's system acknowledgment sheet for a significant app update
  /// (iOS 26.4+).
  ///
  /// Throws [UnsupportedPlatformException] on Android and on iOS below 26.4.
  Future<void> showSignificantUpdateAcknowledgment({
    required String updateDescription,
  }) {
    throw UnimplementedError(
      'showSignificantUpdateAcknowledgment() has not been implemented.',
    );
  }
}
