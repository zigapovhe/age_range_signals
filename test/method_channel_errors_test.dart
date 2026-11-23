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

  final methods = <String, Future<Object?> Function()>{
    'initialize': () => platform.initialize(),
    'requestAgeSignalsAccess': () => platform.requestAgeSignalsAccess(),
    'checkAgeSignals': () => platform.checkAgeSignals(),
    'isEligibleForAgeFeatures': () => platform.isEligibleForAgeFeatures(),
    'getRequiredRegulatoryFeatures': () =>
        platform.getRequiredRegulatoryFeatures(),
    'showSignificantUpdateAcknowledgment': () =>
        platform.showSignificantUpdateAcknowledgment(updateDescription: 'x'),
  };

  const expected = <String, Type>{
    'API_NOT_AVAILABLE': ApiNotAvailableException,
    'UNSUPPORTED_PLATFORM': UnsupportedPlatformException,
    'MOCK_DATA_NOT_ALLOWED': MockDataNotAllowedException,
    'NOT_INITIALIZED': NotInitializedException,
    'PRESENTATION_CONTEXT_UNAVAILABLE': ApiErrorException,
    'MISSING_ENTITLEMENT': MissingEntitlementException,
    'API_ERROR': ApiErrorException,
    'PLAY_SERVICES_ERROR': PlayServicesException,
    'SDK_VERSION_OUTDATED': PlayServicesException,
    'NETWORK_ERROR': NetworkErrorException,
    'USER_NOT_SIGNED_IN': UserNotSignedInException,
    'USER_CANCELLED': UserCancelledException,
    'SOMETHING_NEW': AgeSignalsException,
  };

  methods.forEach((name, invoke) {
    expected.forEach((code, type) {
      test('$name maps $code to $type', () async {
        setHandler(
          (call) => throw PlatformException(
            code: code,
            message: 'native message',
            details: 'native details',
          ),
        );

        Object? thrown;
        try {
          await invoke();
        } catch (e) {
          thrown = e;
        }

        expect(log.single.method, name);
        // isA would also pass for a subclass, so compare the exact type.
        expect(thrown.runtimeType, type);
        thrown as AgeSignalsException;
        expect(thrown.code, code);
        expect(thrown.message, 'native message');
        expect(thrown.details, 'native details');
      });
    });
  });

  test('checkAgeSignals rejects a null platform result', () async {
    setHandler((call) => null);
    await expectLater(
      platform.checkAgeSignals(),
      throwsA(isA<AgeSignalsException>()),
    );
  });

  test('initialize forwards the gates and every mock field', () async {
    setHandler((call) => null);

    await platform.initialize(
      ageGates: [13, 18],
      useMockData: true,
      mockData: AgeSignalsMockData(
        status: AgeSignalsStatus.verified,
        ageLower: 18,
        ageUpper: 20,
        installId: 'id',
        accessStatus: AgeSignalsAccessStatus.notShared,
        ageRangeSource: AgeRangeSource.tierA,
        significantChangeStatus: SignificantChangeStatus.approved,
        mandatorySharing: false,
        significantChangeApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
        ),
      ),
    );

    expect(log.single.method, 'initialize');
    expect(log.single.arguments, {
      'ageGates': [13, 18],
      'useMockData': true,
      'mockData': {
        'status': 'verified',
        'ageLower': 18,
        'ageUpper': 20,
        'source': null,
        'installId': 'id',
        'accessStatus': 'notShared',
        'ageRangeSource': 'tierA',
        'significantChangeStatus': 'approved',
        'mandatorySharing': false,
        'significantChangeApprovalDate': 1735689600000,
      },
    });
  });

  test('initialize defaults to the real API without mock data', () async {
    setHandler((call) => null);
    await platform.initialize();

    expect(log.single.arguments, {
      'ageGates': null,
      'useMockData': false,
      'mockData': null,
    });
  });
}
