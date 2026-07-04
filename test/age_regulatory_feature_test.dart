import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgeRegulatoryFeature.fromName', () {
    test('parses all known names', () {
      expect(
        AgeRegulatoryFeature.fromName('declaredAgeRangeRequired'),
        AgeRegulatoryFeature.declaredAgeRangeRequired,
      );
      expect(
        AgeRegulatoryFeature.fromName(
          'significantAppChangeRequiresAdultNotification',
        ),
        AgeRegulatoryFeature.significantAppChangeRequiresAdultNotification,
      );
      expect(
        AgeRegulatoryFeature.fromName(
          'significantAppChangeRequiresParentalConsent',
        ),
        AgeRegulatoryFeature.significantAppChangeRequiresParentalConsent,
      );
    });

    test('returns null for unknown names', () {
      expect(AgeRegulatoryFeature.fromName('someFutureFeature'), isNull);
      expect(AgeRegulatoryFeature.fromName(''), isNull);
    });
  });
}
