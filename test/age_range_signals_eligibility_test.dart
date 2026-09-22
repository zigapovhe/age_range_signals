import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends AgeRangeSignalsPlatform
    with MockPlatformInterfaceMixin {
  bool eligible = false;
  int calls = 0;

  @override
  Future<bool> isEligibleForAgeFeatures() async {
    calls++;
    return eligible;
  }
}

void main() {
  test('isEligibleForAgeFeatures delegates to the platform', () async {
    final fake = _FakePlatform()..eligible = true;
    AgeRangeSignalsPlatform.instance = fake;

    expect(await AgeRangeSignals.instance.isEligibleForAgeFeatures(), isTrue);
    expect(fake.calls, 1);
  });

  test('isEligibleForAgeFeatures passes false through unchanged', () async {
    final fake = _FakePlatform()..eligible = false;
    AgeRangeSignalsPlatform.instance = fake;

    expect(await AgeRangeSignals.instance.isEligibleForAgeFeatures(), isFalse);
  });
}
