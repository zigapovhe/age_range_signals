import 'package:flutter_test/flutter_test.dart';

import 'package:age_range_signals_example/main.dart';

void main() {
  testWidgets('Age Range Signals Demo loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify app bar is displayed
    expect(find.text('Age Range Signals'), findsOneWidget);

    // Verify check button is present
    expect(find.text('Check Age Signals'), findsOneWidget);
  });
}
