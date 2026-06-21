import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/more/absolute_grading_calculator_screen.dart';

void main() {
  Widget buildTestableWidget(Widget widget) {
    return MaterialApp(
      home: widget,
    );
  }

  group('AbsoluteGradingCalculatorScreen Widget Tests', () {
    testWidgets('calculates and displays grade correctly with rounding (85.4 -> 85 -> A-)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      // Find the text field
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Enter 85.4
      await tester.enterText(textFieldFinder, '85.4');
      await tester.pump();

      // Check results
      expect(find.text('Grade A- assigned'), findsOneWidget);
      expect(find.text('Obtained: 85.4% (rounded to 85%)'), findsOneWidget);
    });

    testWidgets('calculates and displays grade correctly with rounding (85.5 -> 86 -> A)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '85.5');
      await tester.pump();

      expect(find.text('Grade A assigned'), findsOneWidget);
      expect(find.text('Obtained: 85.5% (rounded to 86%)'), findsOneWidget);
    });

    testWidgets('calculates and displays grade correctly with rounding (89.5 -> 90 -> A+)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '89.5');
      await tester.pump();

      expect(find.text('Grade A+ assigned'), findsOneWidget);
      expect(find.text('Obtained: 89.5% (rounded to 90%)'), findsOneWidget);
    });

    testWidgets('handles boundary cases (49.4 -> 49 -> F)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '49.4');
      await tester.pump();

      expect(find.text('Grade F assigned'), findsOneWidget);
      expect(find.text('Obtained: 49.4% (rounded to 49%)'), findsOneWidget);
    });

    testWidgets('handles boundary cases (49.5 -> 50 -> D)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '49.5');
      await tester.pump();

      expect(find.text('Grade D assigned'), findsOneWidget);
      expect(find.text('Obtained: 49.5% (rounded to 50%)'), findsOneWidget);
    });

    testWidgets('shows validation error for values > 100', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '100.1');
      await tester.pump();

      expect(find.text('Please enter a valid percentage between 0 and 100.'), findsOneWidget);
      expect(find.text('CALCULATED GRADE'), findsNothing);
    });

    testWidgets('shows validation error for values < 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '-1');
      await tester.pump();

      expect(find.text('Please enter a valid percentage between 0 and 100.'), findsOneWidget);
    });

    testWidgets('shows nothing when score field is empty', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AbsoluteGradingCalculatorScreen()));

      expect(find.text('CALCULATED GRADE'), findsNothing);
      expect(find.text('Please enter a valid percentage between 0 and 100.'), findsNothing);
    });
  });
}
