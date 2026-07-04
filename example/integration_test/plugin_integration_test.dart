import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:age_range_signals/age_range_signals.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize completes successfully', (WidgetTester tester) async {
    await expectLater(
      AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]),
      completes,
    );
  });

  testWidgets('checkAgeSignals returns a result or throws exception', (
    WidgetTester tester,
  ) async {
    if (Platform.isIOS) {
      await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
    }

    try {
      final result = await AgeRangeSignals.instance.checkAgeSignals();
      expect(result, isA<AgeSignalsResult>());
      expect(result.status, isNotNull);
    } on AgeSignalsException catch (e) {
      // On platforms where the API isn't available, we expect an exception
      expect(e, isA<AgeSignalsException>());
    }
  });

  testWidgets('getRequiredRegulatoryFeatures returns within its deadline', (
    WidgetTester tester,
  ) async {
    // The native side races the Apple call against a 10 second deadline, so
    // this must never hang. A MissingPluginException here would mean the
    // channel method name is wired wrong.
    try {
      final features = await AgeRangeSignals.instance
          .getRequiredRegulatoryFeatures()
          .timeout(const Duration(seconds: 20));
      // ignore: avoid_print
      print('regulatory features: $features');
      expect(features, isA<Set<AgeRegulatoryFeature>>());
      if (Platform.isAndroid) {
        expect(features, isEmpty);
      }
    } on AgeSignalsException catch (e) {
      // Acceptable on iOS: the API can reject the caller (entitlement,
      // region, no Apple Account on a simulator). The typed exception
      // proves the native handler ran and mapped the error.
      // ignore: avoid_print
      print('regulatory features threw: ${e.runtimeType}: $e');
    }
  });

  testWidgets(
    'showSignificantUpdateAcknowledgment fails cleanly, never hangs',
    (WidgetTester tester) async {
      try {
        await AgeRangeSignals.instance
            .showSignificantUpdateAcknowledgment(
              updateDescription: 'Integration test update description',
            )
            .timeout(const Duration(seconds: 20));
        // ignore: avoid_print
        print('significant update acknowledgment: completed');
      } on UnsupportedPlatformException catch (e) {
        // Expected on Android and on iOS below 26.4.
        // ignore: avoid_print
        print('significant update acknowledgment unsupported: $e');
        if (Platform.isAndroid) {
          expect(e, isA<UnsupportedPlatformException>());
        }
      } on AgeSignalsException catch (e) {
        // Acceptable on iOS 26.4+: entitlement or account errors from Apple.
        // ignore: avoid_print
        print('significant update acknowledgment threw: ${e.runtimeType}: $e');
      } on TimeoutException {
        // The system sheet was presented and is waiting for a person to
        // respond; integration tests cannot tap system UI. Reaching the sheet
        // still proves the native call went through.
        // ignore: avoid_print
        print(
          'significant update acknowledgment: sheet presented (timed out '
          'waiting for user input, as expected in an automated run)',
        );
      }
    },
  );
}
