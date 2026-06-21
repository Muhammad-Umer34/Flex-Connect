import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/marks_models.dart';

void main() {
  group('Marks ' 'Best N out of M' ' Rule Tests', () {
    test('Correctly drops the lowest item when totalItemWeight > categoryWeight', () {
      // Set up a course with 5 quizzes, each worth 3.75% weightage.
      // Category total weight is 15.0%.
      // Quizzes:
      // Q1: 5 / 10 (50.0%) - lowest
      // Q2: 5.5 / 6 (91.67%)
      // Q3: 7 / 10 (70.0%)
      // Q4: 9.5 / 10 (95.0%)
      // Q5: 9 / 9 (100.0%)
      
      final section = MarksSection(
        sectionName: 'Quizzes',
        itemLabel: 'Quiz',
        rows: const [
          MarksRow(
            itemNo: '1',
            weightage: '3.75',
            obtained: '5',
            total: '10',
            average: '6.03',
            stdDev: '-',
            minimum: '0',
            maximum: '10',
          ),
          MarksRow(
            itemNo: '2',
            weightage: '3.75',
            obtained: '5.5',
            total: '6',
            average: '4.06',
            stdDev: '-',
            minimum: '1',
            maximum: '6',
          ),
          MarksRow(
            itemNo: '3',
            weightage: '3.75',
            obtained: '7',
            total: '10',
            average: '7.18',
            stdDev: '-',
            minimum: '2',
            maximum: '10',
          ),
          MarksRow(
            itemNo: '4',
            weightage: '3.75',
            obtained: '9.5',
            total: '10',
            average: '8.62',
            stdDev: '-',
            minimum: '5',
            maximum: '10',
          ),
          MarksRow(
            itemNo: '5',
            weightage: '3.75',
            obtained: '9',
            total: '9',
            average: '6.3',
            stdDev: '-',
            minimum: '1',
            maximum: '9',
          ),
          MarksRow(
            itemNo: 'Quiz # Total',
            weightage: '', // no individual weightage
            obtained: '13.375',
            total: '15', // Category total weightage is 15%
            average: '11.5',
            stdDev: '-',
            minimum: '8',
            maximum: '15',
          ),
        ],
      );

      // Verify that activeItemRows contains exactly 4 items (Q2, Q3, Q4, Q5) and drops Q1
      final active = section.activeItemRows;
      expect(active.length, 4);
      expect(active.any((r) => r.itemNo == '1'), isFalse);
      expect(active.any((r) => r.itemNo == '2'), isTrue);
      expect(active.any((r) => r.itemNo == '3'), isTrue);
      expect(active.any((r) => r.itemNo == '4'), isTrue);
      expect(active.any((r) => r.itemNo == '5'), isTrue);

      // Verify row dropping flags
      expect(section.isRowDropped(const MarksRow(itemNo: '1', weightage: '3.75', obtained: '5', total: '10', average: '6.03', stdDev: '-', minimum: '0', maximum: '10')), isTrue);
      expect(section.isRowDropped(const MarksRow(itemNo: '2', weightage: '3.75', obtained: '5.5', total: '6', average: '4.06', stdDev: '-', minimum: '1', maximum: '6')), isFalse);
      expect(section.isRowDropped(const MarksRow(itemNo: 'Quiz # Total', weightage: '', obtained: '13.375', total: '15', average: '11.5', stdDev: '-', minimum: '8', maximum: '15')), isFalse);

      final course = MarksCourse(
        paneId: 'EE3009',
        courseCode: 'EE3009',
        courseTitle: 'Computer Architecture',
        heading: 'EE3009 - Computer Architecture',
        sections: [section],
      );

      final scores = course.weightedScore;
      expect(scores['totalWeight'], closeTo(15.0, 0.001));
      expect(scores['obtained'], closeTo(13.375, 0.001));
    });

    test('Correctly drops the lowest item when categoryWeight is in weightage column instead of total column', () {
      final section = MarksSection(
        sectionName: 'Quizzes',
        itemLabel: 'Quiz',
        rows: const [
          MarksRow(
            itemNo: '1',
            weightage: '3.75',
            obtained: '5',
            total: '10',
            average: '6.03',
            stdDev: '-',
            minimum: '0',
            maximum: '10',
          ),
          MarksRow(
            itemNo: '2',
            weightage: '3.75',
            obtained: '5.5',
            total: '6',
            average: '4.06',
            stdDev: '-',
            minimum: '1',
            maximum: '6',
          ),
          MarksRow(
            itemNo: '3',
            weightage: '3.75',
            obtained: '7',
            total: '10',
            average: '7.18',
            stdDev: '-',
            minimum: '2',
            maximum: '10',
          ),
          MarksRow(
            itemNo: '4',
            weightage: '3.75',
            obtained: '9.5',
            total: '10',
            average: '8.62',
            stdDev: '-',
            minimum: '5',
            maximum: '10',
          ),
          MarksRow(
            itemNo: '5',
            weightage: '3.75',
            obtained: '9',
            total: '9',
            average: '6.3',
            stdDev: '-',
            minimum: '1',
            maximum: '9',
          ),
          MarksRow(
            itemNo: 'Quiz # Total',
            weightage: '15%', // Category weightage is here
            obtained: '13.375',
            total: '', // total is empty
            average: '11.5',
            stdDev: '-',
            minimum: '8',
            maximum: '15',
          ),
        ],
      );

      final active = section.activeItemRows;
      expect(active.length, 4);
      expect(active.any((r) => r.itemNo == '1'), isFalse);

      final course = MarksCourse(
        paneId: 'EE3009',
        courseCode: 'EE3009',
        courseTitle: 'Computer Architecture',
        heading: 'EE3009 - Computer Architecture',
        sections: [section],
      );

      final scores = course.weightedScore;
      expect(scores['totalWeight'], closeTo(15.0, 0.001));
      expect(scores['obtained'], closeTo(13.375, 0.001));
    });
  });
}
