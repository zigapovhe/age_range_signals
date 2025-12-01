import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'age_range_signals_method_channel.dart';

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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
