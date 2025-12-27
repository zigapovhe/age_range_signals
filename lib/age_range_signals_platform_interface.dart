import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'age_range_signals_method_channel.dart';
import 'src/models/age_signals_result.dart';
import 'src/models/age_signals_mock_data.dart';

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
  /// On iOS, [ageGates] specifies the age thresholds to use for age verification.
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
}
