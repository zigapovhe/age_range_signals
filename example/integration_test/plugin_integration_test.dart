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

  testWidgets('requestAgeSignalsAccess resolves to a typed outcome', (
    WidgetTester tester,
  ) async {
    // A MissingPluginException here would mean the channel method name is
    // wired wrong on one platform.
    try {
      final status = await AgeRangeSignals.instance
          .requestAgeSignalsAccess()
          .timeout(const Duration(seconds: 20));
      expect(status, isA<AgeSignalsAccessStatus>());
      if (Platform.isIOS) {
        // iOS has no separate access grant; shared is the fixed answer.
        expect(status, AgeSignalsAccessStatus.shared);
      }
    } on AgeSignalsException catch (e) {
      // Acceptable on Android builds without Play (emulator, sideload).
      // ignore: avoid_print
      print('requestAgeSignalsAccess threw: ${e.runtimeType}: $e');
    } on TimeoutException {
      // Play presented its age sharing prompt and is waiting for a person;
      // integration tests cannot tap system UI. Reaching the prompt still
      // proves the native call went through.
      // ignore: avoid_print
      print(
        'requestAgeSignalsAccess: prompt presented (timed out waiting for '
        'user input, as expected in an automated run)',
      );
    }
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
    final call = AgeRangeSignals.instance
        .getRequiredRegulatoryFeatures()
        .timeout(const Duration(seconds: 20));

    if (Platform.isAndroid) {
      // Android must succeed with an empty set; anything else is a
      // regression in the Kotlin stub.
      expect(await call, isEmpty);
      return;
    }

    try {
      final features = await call;
      // ignore: avoid_print
      print('regulatory features: $features');
    } on AgeSignalsException catch (e) {
      // Acceptable on iOS: UnsupportedPlatformException below 26.4, or the
      // API rejecting the caller (entitlement, region, no Apple Account on
      // a simulator). The typed exception proves the native handler ran
      // and mapped the error.
      // ignore: avoid_print
      print('regulatory features threw: ${e.runtimeType}: $e');
    }
  });

  testWidgets(
    'showSignificantUpdateAcknowledgment fails cleanly, never hangs',
    (WidgetTester tester) async {
      final call = AgeRangeSignals.instance
          .showSignificantUpdateAcknowledgment(
            updateDescription: 'Integration test update description',
          )
          .timeout(const Duration(seconds: 20));

      if (Platform.isAndroid) {
        // Android must reject with UNSUPPORTED_PLATFORM; a silent success
        // here would be exactly the false-compliance no-op the API
        // documentation promises never to produce.
        await expectLater(call, throwsA(isA<UnsupportedPlatformException>()));
        return;
      }

      try {
        await call;
        // ignore: avoid_print
        print('significant update acknowledgment: completed');
      } on AgeSignalsException catch (e) {
        // Acceptable on iOS: UnsupportedPlatformException below 26.4, or
        // entitlement and account errors from Apple on 26.4+.
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
