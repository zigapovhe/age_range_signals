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
  Future<void> initialize({
    List<int>? ageGates,
    bool useMockData = false,
    AgeSignalsMockData? mockData,
  }) async {
    _initialized = true;
    _ageGates = ageGates;
  }

  @override
  Future<AgeSignalsResult> checkAgeSignals() async {
    if (!_initialized) {
      throw const NotInitializedException('Not initialized');
    }
    // Mock VERIFIED user (18+) - age values should be null
    return const AgeSignalsResult(
      status: AgeSignalsStatus.verified,
      ageLower: null,
      ageUpper: null,
      source: AgeDeclarationSource.selfDeclared,
    );
  }
}

class MockAgeRangeSignalsPlatformSupervised
    with MockPlatformInterfaceMixin
    implements AgeRangeSignalsPlatform {
  bool _initialized = false;

  @override
  Future<void> initialize({
    List<int>? ageGates,
    bool useMockData = false,
    AgeSignalsMockData? mockData,
  }) async {
    _initialized = true;
  }

  @override
  Future<AgeSignalsResult> checkAgeSignals() async {
    if (!_initialized) {
      throw const NotInitializedException('Not initialized');
    }
    // Mock SUPERVISED user (Android) - age ranges are populated
    return const AgeSignalsResult(
      status: AgeSignalsStatus.supervised,
      ageLower: 13,
      ageUpper: 15,
      installId: 'test-install-id',
    );
  }
}

class MockAgeRangeSignalsPlatformWithMockData
    with MockPlatformInterfaceMixin
    implements AgeRangeSignalsPlatform {
  bool _initialized = false;
  AgeSignalsMockData? _mockData;

  @override
  Future<void> initialize({
    List<int>? ageGates,
    bool useMockData = false,
    AgeSignalsMockData? mockData,
  }) async {
    _initialized = true;
    _mockData = mockData;
  }

  @override
  Future<AgeSignalsResult> checkAgeSignals() async {
    if (!_initialized) {
      throw const NotInitializedException('Not initialized');
    }

    // Return custom mock data if provided, otherwise defaults
    if (_mockData != null) {
      return AgeSignalsResult(
        status: _mockData!.status,
        ageLower: _mockData!.ageLower,
        ageUpper: _mockData!.ageUpper,
        source: _mockData!.source,
        installId: _mockData!.installId,
      );
    }

    // Default: supervised 13-15
    return const AgeSignalsResult(
      status: AgeSignalsStatus.supervised,
      ageLower: 13,
      ageUpper: 15,
      installId: 'test_install_id_12345',
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

    test('checkAgeSignals returns verified result with null ages', () async {
      await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.verified);
      expect(result.ageLower, null); // VERIFIED users have null age values
      expect(result.ageUpper, null); // VERIFIED users have null age values
      expect(result.source, AgeDeclarationSource.selfDeclared);
    });

    test('checkAgeSignals throws when not initialized', () async {
      expect(
        () => AgeRangeSignals.instance.checkAgeSignals(),
        throwsA(isA<NotInitializedException>()),
      );
    });
  });

  group('AgeRangeSignals - Android behavior', () {
    late MockAgeRangeSignalsPlatformSupervised mockPlatform;

    setUp(() {
      mockPlatform = MockAgeRangeSignalsPlatformSupervised();
      AgeRangeSignalsPlatform.instance = mockPlatform;
    });

    test('SUPERVISED user returns age range values', () async {
      await AgeRangeSignals.instance.initialize();
      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.supervised);
      expect(result.ageLower, 13); // SUPERVISED users have age ranges
      expect(result.ageUpper, 15); // SUPERVISED users have age ranges
      expect(result.installId, 'test-install-id');
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

  group('AgeRangeSignals - mockData parameter', () {
    late MockAgeRangeSignalsPlatformWithMockData mockPlatform;

    setUp(() {
      mockPlatform = MockAgeRangeSignalsPlatformWithMockData();
      AgeRangeSignalsPlatform.instance = mockPlatform;
    });

    test('initialize with custom mockData returns custom supervised result',
        () async {
      await AgeRangeSignals.instance.initialize(
        useMockData: true,
        mockData: AgeSignalsMockData(
          status: AgeSignalsStatus.supervised,
          ageLower: 16,
          ageUpper: 17,
          installId: 'custom_id',
        ),
      );

      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.supervised);
      expect(result.ageLower, 16);
      expect(result.ageUpper, 17);
      expect(result.installId, 'custom_id');
    });

    test('initialize with verified mockData returns null ages', () async {
      await AgeRangeSignals.instance.initialize(
        useMockData: true,
        mockData: const AgeSignalsMockData(
          status: AgeSignalsStatus.verified,
        ),
      );

      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.verified);
      expect(result.ageLower, null);
      expect(result.ageUpper, null);
      expect(result.installId, null);
    });

    test('initialize with supervisedApprovalPending mockData works', () async {
      await AgeRangeSignals.instance.initialize(
        useMockData: true,
        mockData: AgeSignalsMockData(
          status: AgeSignalsStatus.supervisedApprovalPending,
          ageLower: 13,
          ageUpper: 15,
          installId: 'pending_id',
        ),
      );

      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.supervisedApprovalPending);
      expect(result.ageLower, 13);
      expect(result.ageUpper, 15);
      expect(result.installId, 'pending_id');
    });

    test('initialize with unknown mockData returns null ages', () async {
      await AgeRangeSignals.instance.initialize(
        useMockData: true,
        mockData: const AgeSignalsMockData(
          status: AgeSignalsStatus.unknown,
        ),
      );

      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.unknown);
      expect(result.ageLower, null);
      expect(result.ageUpper, null);
    });

    test('initialize without mockData uses defaults (supervised 13-15)',
        () async {
      await AgeRangeSignals.instance.initialize(
        useMockData: true,
        // No mockData parameter
      );

      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.supervised);
      expect(result.ageLower, 13);
      expect(result.ageUpper, 15);
      expect(result.installId, 'test_install_id_12345');
    });

    test('initialize with mockData including source field', () async {
      await AgeRangeSignals.instance.initialize(
        useMockData: true,
        mockData: const AgeSignalsMockData(
          status: AgeSignalsStatus.supervised,
          ageLower: 13,
          ageUpper: 15,
          source: AgeDeclarationSource.guardianDeclared,
        ),
      );

      final result = await AgeRangeSignals.instance.checkAgeSignals();

      expect(result.status, AgeSignalsStatus.supervised);
      expect(result.ageLower, 13);
      expect(result.ageUpper, 15);
      expect(result.source, AgeDeclarationSource.guardianDeclared);
    });
  });

  group('AgeSignalsMockData', () {
    test('toMap converts correctly', () {
      const mockData = AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
        ageLower: 16,
        ageUpper: 17,
        source: AgeDeclarationSource.selfDeclared,
        installId: 'custom_id',
      );

      final map = mockData.toMap();

      expect(map['status'], 'supervised');
      expect(map['ageLower'], 16);
      expect(map['ageUpper'], 17);
      expect(map['source'], 'selfDeclared');
      expect(map['installId'], 'custom_id');
    });

    test('toMap converts verified status correctly', () {
      const mockData = AgeSignalsMockData(
        status: AgeSignalsStatus.verified,
      );

      final map = mockData.toMap();

      expect(map['status'], 'verified');
      expect(map['ageLower'], null);
      expect(map['ageUpper'], null);
      expect(map['source'], null);
      expect(map['installId'], null);
    });

    test('copyWith creates correct copy', () {
      const original = AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
      );

      final copy = original.copyWith(
        ageLower: 16,
        ageUpper: 17,
      );

      expect(copy.status, AgeSignalsStatus.supervised);
      expect(copy.ageLower, 16);
      expect(copy.ageUpper, 17);
    });

    test('equality works correctly', () {
      const mockData1 = AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
      );
      const mockData2 = AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
      );
      const mockData3 = AgeSignalsMockData(
        status: AgeSignalsStatus.verified,
      );

      expect(mockData1, equals(mockData2));
      expect(mockData1, isNot(equals(mockData3)));
    });
  });
}
