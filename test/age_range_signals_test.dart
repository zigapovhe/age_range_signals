import 'package:flutter_test/flutter_test.dart';
import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_platform_interface.dart';
import 'package:age_range_signals/age_range_signals_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAgeRangeSignalsPlatform
    with MockPlatformInterfaceMixin
    implements AgeRangeSignalsPlatform {
  bool _initialized = false;
  List<int>? _ageGates;

  @override
  Future<void> initialize(
      {List<int>? ageGates, bool useMockData = false}) async {
    _initialized = true;
    _ageGates = ageGates;
  }

  @override
  Future<AgeSignalsResult> checkAgeSignals() async {
    if (!_initialized) {
      throw const NotInitializedException('Not initialized');
    }
    return const AgeSignalsResult(
      status: AgeSignalsStatus.verified,
      ageLower: 18,
      ageUpper: 99,
      source: AgeDeclarationSource.selfDeclared,
    );
  }
}

void main() {
  final AgeRangeSignalsPlatform initialPlatform =
      AgeRangeSignalsPlatform.instance;

  test('$MethodChannelAgeRangeSignals is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAgeRangeSignals>());
  });

  group('AgeRangeSignals', () {
    late MockAgeRangeSignalsPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockAgeRangeSignalsPlatform();
      AgeRangeSignalsPlatform.instance = mockPlatform;
    });

    test('initialize sets age gates', () async {
      await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
      expect(mockPlatform._initialized, true);
      expect(mockPlatform._ageGates, [13, 16, 18]);
    });

    test('checkAgeSignals returns result when initialized', () async {
      await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.verified);
      expect(result.ageLower, 18);
      expect(result.ageUpper, 99);
      expect(result.source, AgeDeclarationSource.selfDeclared);
    });

    test('checkAgeSignals throws when not initialized', () async {
      expect(
        () => AgeRangeSignals.instance.checkAgeSignals(),
        throwsA(isA<NotInitializedException>()),
      );
    });
  });

  group('AgeSignalsResult', () {
    test('creates from map correctly', () {
      final map = {
        'status': 'verified',
        'ageLower': 13,
        'ageUpper': 17,
        'source': 'guardianDeclared',
        'installId': 'test-install-id',
      };

      final result = AgeSignalsResult.fromMap(map);

      expect(result.status, AgeSignalsStatus.verified);
      expect(result.ageLower, 13);
      expect(result.ageUpper, 17);
      expect(result.source, AgeDeclarationSource.guardianDeclared);
      expect(result.installId, 'test-install-id');
    });

    test('creates from map with supervisedApprovalPending status', () {
      final map = {
        'status': 'supervisedApprovalPending',
        'ageLower': null,
        'ageUpper': null,
        'source': null,
        'installId': 'test-install-id',
      };

      final result = AgeSignalsResult.fromMap(map);

      expect(result.status, AgeSignalsStatus.supervisedApprovalPending);
      expect(result.ageLower, null);
      expect(result.ageUpper, null);
      expect(result.source, null);
      expect(result.installId, 'test-install-id');
    });

    test('creates from map with supervisedApprovalDenied status', () {
      final map = {
        'status': 'supervisedApprovalDenied',
        'ageLower': null,
        'ageUpper': null,
        'source': null,
        'installId': 'test-install-id',
      };

      final result = AgeSignalsResult.fromMap(map);

      expect(result.status, AgeSignalsStatus.supervisedApprovalDenied);
      expect(result.ageLower, null);
      expect(result.ageUpper, null);
      expect(result.source, null);
      expect(result.installId, 'test-install-id');
    });

    test('toMap converts correctly', () {
      const result = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        ageLower: 10,
        ageUpper: 12,
        source: AgeDeclarationSource.selfDeclared,
        installId: 'test-id',
      );

      final map = result.toMap();

      expect(map['status'], 'supervised');
      expect(map['ageLower'], 10);
      expect(map['ageUpper'], 12);
      expect(map['source'], 'selfDeclared');
      expect(map['installId'], 'test-id');
    });

    test('toMap converts supervisedApprovalPending correctly', () {
      const result = AgeSignalsResult(
        status: AgeSignalsStatus.supervisedApprovalPending,
        installId: 'test-id',
      );

      final map = result.toMap();

      expect(map['status'], 'supervisedApprovalPending');
      expect(map['ageLower'], null);
      expect(map['ageUpper'], null);
      expect(map['source'], null);
      expect(map['installId'], 'test-id');
    });

    test('toMap converts supervisedApprovalDenied correctly', () {
      const result = AgeSignalsResult(
        status: AgeSignalsStatus.supervisedApprovalDenied,
        installId: 'test-id',
      );

      final map = result.toMap();

      expect(map['status'], 'supervisedApprovalDenied');
      expect(map['ageLower'], null);
      expect(map['ageUpper'], null);
      expect(map['source'], null);
      expect(map['installId'], 'test-id');
    });

    test('equality works correctly', () {
      const result1 = AgeSignalsResult(
        status: AgeSignalsStatus.verified,
        ageLower: 18,
      );
      const result2 = AgeSignalsResult(
        status: AgeSignalsStatus.verified,
        ageLower: 18,
      );
      const result3 = AgeSignalsResult(
        status: AgeSignalsStatus.declined,
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('copyWith creates correct copy', () {
      const original = AgeSignalsResult(
        status: AgeSignalsStatus.verified,
        ageLower: 13,
      );

      final copy = original.copyWith(ageUpper: 17);

      expect(copy.status, AgeSignalsStatus.verified);
      expect(copy.ageLower, 13);
      expect(copy.ageUpper, 17);
    });
  });

  group('AgeSignalsException', () {
    test('formats message correctly with code', () {
      const exception = AgeSignalsException('Test message', 'TEST_CODE');
      expect(
          exception.toString(), 'AgeSignalsException(TEST_CODE): Test message');
    });

    test('formats message correctly without code', () {
      const exception = AgeSignalsException('Test message');
      expect(exception.toString(), 'AgeSignalsException: Test message');
    });

    test('ApiNotAvailableException is AgeSignalsException', () {
      const exception = ApiNotAvailableException('API not available');
      expect(exception, isA<AgeSignalsException>());
    });

    test('UnsupportedPlatformException is AgeSignalsException', () {
      const exception = UnsupportedPlatformException('Unsupported');
      expect(exception, isA<AgeSignalsException>());
    });

    test('NotInitializedException is AgeSignalsException', () {
      const exception = NotInitializedException('Not initialized');
      expect(exception, isA<AgeSignalsException>());
    });
  });
}
