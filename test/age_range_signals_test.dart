import 'package:flutter_test/flutter_test.dart';
import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_platform_interface.dart';
import 'package:age_range_signals/age_range_signals_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAgeRangeSignalsPlatform
    with MockPlatformInterfaceMixin
    implements AgeRangeSignalsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AgeRangeSignalsPlatform initialPlatform = AgeRangeSignalsPlatform.instance;

  test('$MethodChannelAgeRangeSignals is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAgeRangeSignals>());
  });

  test('getPlatformVersion', () async {
    AgeRangeSignals ageRangeSignalsPlugin = AgeRangeSignals();
    MockAgeRangeSignalsPlatform fakePlatform = MockAgeRangeSignalsPlatform();
    AgeRangeSignalsPlatform.instance = fakePlatform;

    expect(await ageRangeSignalsPlugin.getPlatformVersion(), '42');
  });
}
