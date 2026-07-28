// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_test/flutter_test.dart';
import 'package:age_range_signals/age_range_signals.dart';

/// 0.8.0 renamed `mostRecentApprovalDate` to `significantChangeApprovalDate`,
/// following Play age-signals 0.0.4. The changelog promises the old name keeps
/// working, so every surface that accepted it must still accept it.
void main() {
  final date = DateTime.utc(2026, 1, 1);

  group('mostRecentApprovalDate deprecation alias', () {
    test('AgeSignalsResult constructor accepts the old name', () {
      final result = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        mostRecentApprovalDate: date,
      );

      expect(result.significantChangeApprovalDate, date);
      expect(result.mostRecentApprovalDate, date);
    });

    test('the new name wins when both are supplied', () {
      final newer = DateTime.utc(2026, 6, 1);
      final result = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
        significantChangeApprovalDate: newer,
        mostRecentApprovalDate: date,
      );

      expect(result.significantChangeApprovalDate, newer);
    });

    test('AgeSignalsResult.copyWith accepts the old name', () {
      final result = AgeSignalsResult(
        status: AgeSignalsStatus.supervised,
      ).copyWith(mostRecentApprovalDate: date);

      expect(result.significantChangeApprovalDate, date);
    });

    test('AgeSignalsMockData constructor accepts the old name', () {
      const status = AgeSignalsStatus.supervised;
      final mock = AgeSignalsMockData(
        status: status,
        mostRecentApprovalDate: date,
      );

      expect(mock.significantChangeApprovalDate, date);
      // The getter is the surface a 0.7.x caller reads, and the one the
      // first version of this test forgot to assert.
      expect(mock.mostRecentApprovalDate, date);
      expect(
        mock.toMap()['significantChangeApprovalDate'],
        date.millisecondsSinceEpoch,
      );
    });

    test('AgeSignalsMockData.copyWith accepts the old name', () {
      final mock = const AgeSignalsMockData(
        status: AgeSignalsStatus.supervised,
      ).copyWith(mostRecentApprovalDate: date);

      expect(mock.significantChangeApprovalDate, date);
    });

    test('fromMap still accepts a result persisted under 0.7.x', () {
      final restored = AgeSignalsResult.fromMap({
        'status': 'supervised',
        'mostRecentApprovalDate': date.millisecondsSinceEpoch,
      });

      expect(restored.significantChangeApprovalDate, date);
    });

    test('the new key wins over the old one in fromMap', () {
      final newer = DateTime.utc(2026, 6, 1);
      final restored = AgeSignalsResult.fromMap({
        'status': 'supervised',
        'significantChangeApprovalDate': newer.millisecondsSinceEpoch,
        'mostRecentApprovalDate': date.millisecondsSinceEpoch,
      });

      expect(restored.significantChangeApprovalDate, newer);
    });
  });
}
