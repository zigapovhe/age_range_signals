import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:age_range_signals_example/main.dart';

/// Taps the example's mock scenarios through the real Android plugin.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapText(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  }

  const supervised = 'Supervised (User may be under age threshold)';
  const verified = 'Verified (User is above age threshold)';
  const unknown = 'Unknown (Age information not available)';
  const mandatory = 'sharing is mandatory for this user';
  const notMandatory = 'sharing is not mandatory for this user';

  final scenarios = <String, (String, String)>{
    'Default (Supervised 13-15)': (supervised, mandatory),
    'Supervised 16-17': (supervised, mandatory),
    'Verified (18+)': (verified, mandatory),
    'Approval Pending': ('Supervised (Awaiting guardian approval)', mandatory),
    'Approval Denied': ('Supervised (Guardian denied approval)', mandatory),
    'Self-declared adult': (verified, mandatory),
    'ID-verified minor': (supervised, mandatory),
    'Unknown': (unknown, mandatory),
    'Access Not Shared': (unknown, notMandatory),
    'Not mandatory region': (verified, notMandatory),
  };

  scenarios.forEach((name, expected) {
    final (status, sharing) = expected;
    testWidgets('scenario "$name"', (tester) async {
      await openApp(tester);
      await tapText(tester, find.widgetWithText(ActionChip, name));
      await tapText(tester, find.text('Check Age Signals'));
      await tapText(tester, find.text('Is Eligible For Age Features'));

      expect(find.text(status), findsOneWidget);
      expect(find.textContaining('($sharing)'), findsOneWidget);
    }, skip: !Platform.isAndroid);
  });

  group('old eligibility outcomes are cleared', () {
    Future<void> showOutcomes(WidgetTester tester) async {
      await openApp(tester);
      await tapText(tester, find.text('Is Eligible For Age Features'));
      await tapText(tester, find.text('Get Required Regulatory Features'));
      expect(find.textContaining(mandatory), findsOneWidget);
      expect(find.textContaining('declaredAgeRangeRequired'), findsOneWidget);
    }

    void expectCleared() {
      expect(find.textContaining(mandatory), findsNothing);
      expect(find.textContaining('declaredAgeRangeRequired'), findsNothing);
    }

    testWidgets('when the scenario changes', (tester) async {
      await showOutcomes(tester);
      await tapText(
        tester,
        find.widgetWithText(ActionChip, 'Not mandatory region'),
      );
      expectCleared();
    }, skip: !Platform.isAndroid);

    testWidgets('when mock mode is toggled', (tester) async {
      await showOutcomes(tester);
      await tapText(tester, find.byType(Switch));
      expectCleared();
    }, skip: !Platform.isAndroid);
  });
}
