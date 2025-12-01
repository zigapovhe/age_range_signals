import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'age_range_signals_platform_interface.dart';

/// An implementation of [AgeRangeSignalsPlatform] that uses method channels.
class MethodChannelAgeRangeSignals extends AgeRangeSignalsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('age_range_signals');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
