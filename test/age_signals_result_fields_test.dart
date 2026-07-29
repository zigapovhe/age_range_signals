import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgeSignalsResult new fields', () {
    test(
      'fromMap parses activeParentalControls and significantChangeApprovalDate',
      () {
        final result = AgeSignalsResult.fromMap({
          'status': 'supervised',
          'ageLower': 13,
          'ageUpper': 15,
          'source': null,
          'installId': 'abc',
          'activeParentalControls': ['communicationSafety', 'webContentFilter'],
          'significantChangeApprovalDate': 1735689600000,
        });

        expect(result.activeParentalControls, [
          'communicationSafety',
          'webContentFilter',
        ]);
        expect(
          result.significantChangeApprovalDate,
          DateTime.fromMillisecondsSinceEpoch(1735689600000, isUtc: true),
        );
      },
    );

    test('fromMap parses ageRangeSource and significantChangeStatus', () {
      final result = AgeSignalsResult.fromMap({
        'status': 'supervisedApprovalPending',
        'ageLower': 13,
        'ageUpper': 15,
        'source': null,
        'installId': 'abc',
        'ageRangeSource': 'tierB',
        'significantChangeStatus': 'pending',
      });

      expect(result.ageRangeSource, AgeRangeSource.tierB);
      expect(result.significantChangeStatus, SignificantChangeStatus.pending);
    });

    test('fromMap leaves unknown tier and change-status names null', () {
      // Future Google additions must degrade gracefully, not crash the parse.
      final result = AgeSignalsResult.fromMap({
        'status': 'verified',
        'ageRangeSource': 'tierE',
        'significantChangeStatus': 'escalated',
      });

      expect(result.status, AgeSignalsStatus.verified);
      expect(result.ageRangeSource, isNull);
      expect(result.significantChangeStatus, isNull);
    });

    test('fromMap tolerates missing new keys (old native layer)', () {
      final result = AgeSignalsResult.fromMap({
        'status': 'verified',
        'ageLower': null,
        'ageUpper': null,
        'source': null,
        'installId': null,
      });

      expect(result.activeParentalControls, isNull);
      expect(result.ageRangeSource, isNull);
      expect(result.significantChangeStatus, isNull);
      expect(result.significantChangeApprovalDate, isNull);
    });

    test('toMap round-trips the new fields', () {
      final original = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
        activeParentalControls: const ['screenTime'],
        ageRangeSource: AgeRangeSource.tierB,
        significantChangeStatus: SignificantChangeStatus.approved,
        significantChangeApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
          isUtc: true,
        ),
      );

      final roundTripped = AgeSignalsResult.fromMap(original.toMap());
      expect(roundTripped, original);
    });

    test('equality compares approval date instants across time zones', () {
      final utc = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        significantChangeApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
          isUtc: true,
        ),
      );
      final local = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        significantChangeApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
        ),
      );

      // A mock configured with a local DateTime must equal the UTC value
      // parsed back from the channel; the instant matters, not the zone.
      expect(utc, local);
      expect(utc.hashCode, local.hashCode);
    });

    test('equality and copyWith cover the new fields', () {
      const a = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        activeParentalControls: ['screenTime'],
        ageRangeSource: AgeRangeSource.tierB,
      );
      final b = a.copyWith(
        significantChangeStatus: SignificantChangeStatus.pending,
      );

      expect(a == b, isFalse);
      expect(b.ageRangeSource, AgeRangeSource.tierB);
      expect(b.significantChangeStatus, SignificantChangeStatus.pending);
      expect(b.status, AgeSignalsStatus.supervised);
    });
  });

  group('AgeSignalsMockData 0.0.4 fields', () {
    test('toMap emits epoch milliseconds for the approval date', () {
      final mock = AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
        significantChangeApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
          isUtc: true,
        ),
      );

      expect(mock.toMap()['significantChangeApprovalDate'], 1735689600000);
    });

    test('toMap emits access status and explicit signal overrides', () {
      const mock = AgeSignalsMockData(
        status: AgeSignalsStatus.verified,
        accessStatus: AgeSignalsAccessStatus.verificationRequired,
        ageRangeSource: AgeRangeSource.tierD,
        significantChangeStatus: SignificantChangeStatus.approved,
      );

      final map = mock.toMap();
      expect(map['accessStatus'], 'verificationRequired');
      expect(map['ageRangeSource'], 'tierD');
      expect(map['significantChangeStatus'], 'approved');
    });

    test('toMap emits null for unset 0.0.4 fields', () {
      const mock = AgeSignalsMockData(status: AgeSignalsStatus.verified);

      final map = mock.toMap();
      expect(map['accessStatus'], isNull);
      expect(map['ageRangeSource'], isNull);
      expect(map['significantChangeStatus'], isNull);
      expect(map['significantChangeApprovalDate'], isNull);
    });
  });

  group('AgeSignalsAccessStatus', () {
    test('fromName parses every value and falls back to unknown', () {
      expect(
        AgeSignalsAccessStatus.fromName('shared'),
        AgeSignalsAccessStatus.shared,
      );
      expect(
        AgeSignalsAccessStatus.fromName('notShared'),
        AgeSignalsAccessStatus.notShared,
      );
      expect(
        AgeSignalsAccessStatus.fromName('verificationRequired'),
        AgeSignalsAccessStatus.verificationRequired,
      );
      expect(
        AgeSignalsAccessStatus.fromName('somethingNew'),
        AgeSignalsAccessStatus.unknown,
      );
    });
  });

  test('copyWith replaces activeParentalControls', () {
    const before = AgeSignalsResult(
      status: AgeSignalsStatus.supervised,
      activeParentalControls: ['communicationLimits'],
    );

    final after = before.copyWith(
      activeParentalControls: ['screenTime', 'other'],
    );

    expect(after.activeParentalControls, ['screenTime', 'other']);
  });
}
