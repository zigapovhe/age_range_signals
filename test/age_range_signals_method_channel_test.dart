import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:age_range_signals/age_range_signals_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAgeRangeSignals platform = MethodChannelAgeRangeSignals();
  const MethodChannel channel = MethodChannel('age_range_signals');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
