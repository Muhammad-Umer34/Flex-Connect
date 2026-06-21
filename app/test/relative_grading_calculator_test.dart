import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/more/relative_grading_calculator_screen.dart';

void main() {
  Widget buildTestableWidget(Widget widget) {
    return MaterialApp(
      home: widget,
    );
  }

  group('RelativeGradingCalculatorScreen Widget Tests', () {
    testWidgets('calculates grade correctly (MCA = 50, Score = 62.6 -> rounds to 63 -> A-)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), '50');
      await tester.enterText(textFields.at(1), '62.6');
      await tester.pump();

      expect(find.text('Grade A- assigned'), findsOneWidget);
      expect(find.textContaining('MCA: 50.0% (rounded to 50%)'), findsOneWidget);
      expect(find.textContaining('Your Marks: 62.6% (rounded to 63%)'), findsOneWidget);
    });

    testWidgets('calculates grade correctly for low MCA (MCA = 30, Score = 30 -> C+)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '30');
      await tester.enterText(textFields.at(1), '30');
      await tester.pump();

      expect(find.text('Grade C+ assigned'), findsOneWidget);
    });

    testWidgets('handles skipped/null thresholds correctly (MCA = 82, Score = 88 -> B+)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '82');
      await tester.enterText(textFields.at(1), '88');
      await tester.pump();

      expect(find.text('Grade B+ assigned'), findsOneWidget);
    });

    testWidgets('handles multiple skipped thresholds correctly (MCA = 87, Score = 88 -> B)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '87');
      await tester.enterText(textFields.at(1), '88');
      await tester.pump();

      expect(find.text('Grade B assigned'), findsOneWidget);
    });

    testWidgets('clamps low MCA values below 30 and shows clamping notice (MCA = 20, Score = 30 -> C+)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '20');
      await tester.enterText(textFields.at(1), '30');
      await tester.pump();

      expect(find.text('Grade C+ assigned'), findsOneWidget);
      expect(find.textContaining('Class Average rounded to 20 is below 30'), findsOneWidget);
    });

    testWidgets('clamps high MCA values above 91 and shows clamping notice (MCA = 95, Score = 88 -> B-)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '95');
      await tester.enterText(textFields.at(1), '88');
      await tester.pump();

      expect(find.text('Grade B- assigned'), findsOneWidget);
      expect(find.textContaining('Class Average rounded to 95 is above 91'), findsOneWidget);
    });

    testWidgets('shows validation error for values > 100', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '50');
      await tester.enterText(textFields.at(1), '100.5');
      await tester.pump();

      expect(find.text('Please enter valid percentages between 0 and 100.'), findsOneWidget);
    });

    testWidgets('shows validation error for values < 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const RelativeGradingCalculatorScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '-5');
      await tester.enterText(textFields.at(1), '80');
      await tester.pump();

      expect(find.text('Please enter valid percentages between 0 and 100.'), findsOneWidget);
    });
  });
}
