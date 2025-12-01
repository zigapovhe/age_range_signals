
import 'age_range_signals_platform_interface.dart';

class AgeRangeSignals {
  Future<String?> getPlatformVersion() {
    return AgeRangeSignalsPlatform.instance.getPlatformVersion();
  }
}
