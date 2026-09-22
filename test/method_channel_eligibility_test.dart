import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelAgeRangeSignals();
  final log = <MethodCall>[];

  void setHandler(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (call) async {
          log.add(call);
          return handler(call);
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);
    log.clear();
  });

  group('isEligibleForAgeFeatures', () {
    test('returns the native boolean', () async {
      setHandler((call) => true);
      expect(await platform.isEligibleForAgeFeatures(), isTrue);
      expect(log.single.method, 'isEligibleForAgeFeatures');
      expect(log.single.arguments, isNull);

      setHandler((call) => false);
      expect(await platform.isEligibleForAgeFeatures(), isFalse);
    });

    test('rejects a null native result instead of reporting false', () async {
      setHandler((call) => null);
      expect(
        () => platform.isEligibleForAgeFeatures(),
        throwsA(isA<AgeSignalsException>()),
      );
    });

    test('maps UNSUPPORTED_PLATFORM to UnsupportedPlatformException', () async {
      setHandler(
        (call) => throw PlatformException(
          code: 'UNSUPPORTED_PLATFORM',
          message: 'iOS 26.2 required',
        ),
      );

      expect(
        () => platform.isEligibleForAgeFeatures(),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('maps API_NOT_AVAILABLE and API_ERROR to typed exceptions', () async {
      setHandler(
        (call) => throw PlatformException(
          code: 'API_NOT_AVAILABLE',
          message: 'service unavailable',
        ),
      );
      expect(
        () => platform.isEligibleForAgeFeatures(),
        throwsA(isA<ApiNotAvailableException>()),
      );

      setHandler(
        (call) =>
            throw PlatformException(code: 'API_ERROR', message: 'timed out'),
      );
      expect(
        () => platform.isEligibleForAgeFeatures(),
        throwsA(isA<ApiErrorException>()),
      );
    });
  });
}
