import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgeSignalsResult new fields', () {
    test(
      'fromMap parses activeParentalControls and mostRecentApprovalDate',
      () {
        final result = AgeSignalsResult.fromMap({
          'status': 'supervised',
          'ageLower': 13,
          'ageUpper': 15,
          'source': null,
          'installId': 'abc',
          'activeParentalControls': ['communicationSafety', 'webContentFilter'],
          'mostRecentApprovalDate': 1735689600000,
        });

        expect(result.activeParentalControls, [
          'communicationSafety',
          'webContentFilter',
        ]);
        expect(
          result.mostRecentApprovalDate,
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
      expect(result.mostRecentApprovalDate, isNull);
    });

    test('toMap round-trips the new fields', () {
      final original = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
        activeParentalControls: const ['screenTime'],
        mostRecentApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
          isUtc: true,
        ),
      );

      final roundTripped = AgeSignalsResult.fromMap(original.toMap());
      expect(roundTripped, original);
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

  group('AgeSignalsMockData mostRecentApprovalDate', () {
    test('toMap emits epoch milliseconds', () {
      final mock = AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
        ageLower: 13,
        ageUpper: 15,
        mostRecentApprovalDate: DateTime.fromMillisecondsSinceEpoch(
          1735689600000,
          isUtc: true,
        ),
      );

      expect(mock.toMap()['mostRecentApprovalDate'], 1735689600000);
    });

    test('toMap emits null when unset', () {
      const mock = AgeSignalsMockData(status: AgeSignalsStatus.verified);
      expect(mock.toMap()['mostRecentApprovalDate'], isNull);
    });
  });
}
