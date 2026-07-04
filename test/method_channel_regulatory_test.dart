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

  group('getRequiredRegulatoryFeatures', () {
    test('maps known names to enum values and drops unknown ones', () async {
      setHandler(
        (call) => <String>[
          'declaredAgeRangeRequired',
          'significantAppChangeRequiresParentalConsent',
          'someFutureFeature',
        ],
      );

      final features = await platform.getRequiredRegulatoryFeatures();

      expect(log.single.method, 'getRequiredRegulatoryFeatures');
      expect(features, {
        AgeRegulatoryFeature.declaredAgeRangeRequired,
        AgeRegulatoryFeature.significantAppChangeRequiresParentalConsent,
      });
    });

    test('returns empty set for an empty native list', () async {
      setHandler((call) => <String>[]);
      expect(await platform.getRequiredRegulatoryFeatures(), isEmpty);
    });

    test('maps UNSUPPORTED_PLATFORM to UnsupportedPlatformException', () async {
      setHandler(
        (call) => throw PlatformException(
          code: 'UNSUPPORTED_PLATFORM',
          message: 'nope',
        ),
      );

      expect(
        () => platform.getRequiredRegulatoryFeatures(),
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
        () => platform.getRequiredRegulatoryFeatures(),
        throwsA(isA<ApiNotAvailableException>()),
      );

      setHandler(
        (call) =>
            throw PlatformException(code: 'API_ERROR', message: 'timed out'),
      );
      expect(
        () => platform.getRequiredRegulatoryFeatures(),
        throwsA(isA<ApiErrorException>()),
      );
    });
  });

  group('showSignificantUpdateAcknowledgment', () {
    test('forwards updateDescription', () async {
      setHandler((call) => null);

      await platform.showSignificantUpdateAcknowledgment(
        updateDescription: 'We added social features.',
      );

      expect(log.single.method, 'showSignificantUpdateAcknowledgment');
      expect(log.single.arguments, {
        'updateDescription': 'We added social features.',
      });
    });

    test('maps UNSUPPORTED_PLATFORM to UnsupportedPlatformException', () async {
      setHandler(
        (call) => throw PlatformException(
          code: 'UNSUPPORTED_PLATFORM',
          message: 'android',
        ),
      );

      expect(
        () => platform.showSignificantUpdateAcknowledgment(
          updateDescription: 'x',
        ),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('maps dismissal, cancellation, and presentation errors', () async {
      setHandler(
        (call) => throw PlatformException(
          code: 'API_NOT_AVAILABLE',
          message: 'unavailable or dismissed',
        ),
      );
      expect(
        () => platform.showSignificantUpdateAcknowledgment(
          updateDescription: 'x',
        ),
        throwsA(isA<ApiNotAvailableException>()),
      );

      setHandler(
        (call) => throw PlatformException(
          code: 'USER_CANCELLED',
          message: 'cancelled',
        ),
      );
      expect(
        () => platform.showSignificantUpdateAcknowledgment(
          updateDescription: 'x',
        ),
        throwsA(isA<UserCancelledException>()),
      );

      setHandler(
        (call) => throw PlatformException(
          code: 'PRESENTATION_CONTEXT_UNAVAILABLE',
          message: 'no scene',
        ),
      );
      expect(
        () => platform.showSignificantUpdateAcknowledgment(
          updateDescription: 'x',
        ),
        throwsA(isA<ApiErrorException>()),
      );
    });
  });
}
