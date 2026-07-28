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

    test('fromMap tolerates missing new keys (old native layer)', () {
      final result = AgeSignalsResult.fromMap({
        'status': 'verified',
        'ageLower': null,
        'ageUpper': null,
        'source': null,
        'installId': null,
      });

      expect(result.activeParentalControls, isNull);
      expect(result.significantChangeApprovalDate, isNull);
    });

    test('toMap round-trips the new fields', () {
      final original = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
        activeParentalControls: const ['screenTime'],
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
      );
      final b = a.copyWith(activeParentalControls: ['screenTime', 'other']);

      expect(a == b, isFalse);
      expect(b.activeParentalControls, ['screenTime', 'other']);
      expect(b.status, AgeSignalsStatus.supervised);
    });
  });

  group('AgeSignalsMockData significantChangeApprovalDate', () {
    test('toMap emits epoch milliseconds', () {
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

    test('toMap emits null when unset', () {
      const mock = AgeSignalsMockData(status: AgeSignalsStatus.verified);
      expect(mock.toMap()['significantChangeApprovalDate'], isNull);
    });
  });
}
