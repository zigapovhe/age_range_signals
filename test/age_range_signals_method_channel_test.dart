import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelAgeRangeSignals();
  const channel = MethodChannel('age_range_signals');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'initialize':
            return null;
          case 'checkAgeSignals':
            // Mock VERIFIED user (18+) - age values should be null
            return {
              'status': 'verified',
              'ageLower': null,
              'ageUpper': null,
              'source': 'selfDeclared',
              'installId': null,
            };
          default:
            throw PlatformException(
              code: 'UNIMPLEMENTED',
              message: 'Method not implemented',
            );
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize completes without error', () async {
    await expectLater(
      platform.initialize(ageGates: [13, 16, 18]),
      completes,
    );
  });

  test('checkAgeSignals returns verified result with null ages', () async {
    final result = await platform.checkAgeSignals();

    expect(result.status, AgeSignalsStatus.verified);
    expect(result.ageLower, null); // VERIFIED users have null age values
    expect(result.ageUpper, null); // VERIFIED users have null age values
    expect(result.source, AgeDeclarationSource.selfDeclared);
    expect(result.installId,
        null); // VERIFIED users typically don't have installId
  });

  test('checkAgeSignals returns supervised result with age ranges', () async {
    // Mock SUPERVISED user (Android) with age ranges
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkAgeSignals') {
          return {
            'status': 'supervised',
            'ageLower': 13,
            'ageUpper': 15,
            'source': null,
            'installId': 'test-install-id',
          };
        }
        return null;
      },
    );

    final result = await platform.checkAgeSignals();

    expect(result.status, AgeSignalsStatus.supervised);
    expect(result.ageLower, 13); // SUPERVISED users have age ranges
    expect(result.ageUpper, 15); // SUPERVISED users have age ranges
    expect(result.source, null); // Android doesn't have source
    expect(result.installId, 'test-install-id'); // Android has installId
  });

  test('checkAgeSignals handles API_NOT_AVAILABLE error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        throw PlatformException(
          code: 'API_NOT_AVAILABLE',
          message: 'API not available',
        );
      },
    );

    expect(
      () => platform.checkAgeSignals(),
      throwsA(isA<ApiNotAvailableException>()),
    );
  });

  test('checkAgeSignals handles UNSUPPORTED_PLATFORM error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        throw PlatformException(
          code: 'UNSUPPORTED_PLATFORM',
          message: 'Unsupported platform',
        );
      },
    );

    expect(
      () => platform.checkAgeSignals(),
      throwsA(isA<UnsupportedPlatformException>()),
    );
  });

  test('checkAgeSignals handles NOT_INITIALIZED error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'Not initialized',
        );
      },
    );

    expect(
      () => platform.checkAgeSignals(),
      throwsA(isA<NotInitializedException>()),
    );
  });

  test('checkAgeSignals handles generic error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        throw PlatformException(
          code: 'UNKNOWN_ERROR',
          message: 'Unknown error',
        );
      },
    );

    expect(
      () => platform.checkAgeSignals(),
      throwsA(isA<AgeSignalsException>()),
    );
  });
}
