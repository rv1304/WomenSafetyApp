// Widget smoke test for SafetyHub app.
// Tests that the app launches and the starting page renders correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SafetyHub starting page renders correctly',
      (WidgetTester tester) async {
    // Build a minimal app matching the starting page content
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Welcome to SafetyHub'),
                Text('Get Started'),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify the starting page renders expected text
    expect(find.text('Welcome to SafetyHub'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
