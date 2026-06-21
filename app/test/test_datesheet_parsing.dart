import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/datesheet_parser.dart';
import 'package:app/models/transcript_models.dart';

void main() {
  group('DatesheetParser Tests', () {
    test('Test Spring 2026 Final Datesheet Parsing (2 sessions)', () {
      final file = File(r'E:\Flex Connect\final date sheet-Spring2026-Stu V1.3.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      
      final registeredCourses = [
        const TranscriptCourse(
          code: 'MT2007',
          courseName: 'Numerical Analysis',
          section: 'BCS-4A',
          creditHours: '3',
          grade: 'A',
          points: '12',
          type: 'Theory',
          remarks: '',
        ),
        const TranscriptCourse(
          code: 'CS2005',
          courseName: 'Database Systems',
          section: 'BCS-4B',
          creditHours: '3',
          grade: 'B',
          points: '9',
          type: 'Theory',
          remarks: '',
        ),
        const TranscriptCourse(
          code: 'CL2005',
          courseName: 'Database Systems - Lab',
          section: 'BCS-4B',
          creditHours: '1',
          grade: 'A',
          points: '4',
          type: 'Lab',
          remarks: '',
        ),
        const TranscriptCourse(
          code: 'CS2001',
          courseName: 'Data Structures',
          section: 'BCS-3A',
          creditHours: '3',
          grade: 'A',
          points: '12',
          type: 'Theory',
          remarks: '',
        ),
        const TranscriptCourse(
          code: 'AL2002',
          courseName: 'Artificial Intelligence - Lab',
          section: 'BCS-6B',
          creditHours: '1',
          grade: 'A',
          points: '4',
          type: 'Lab',
          remarks: '',
        ),
      ];

      final matches = DatesheetParser.parse(
        fileBytes: bytes,
        registeredCourses: registeredCourses,
      );

      print('Final Exam matches found: ${matches.length}');
      expect(matches.length, equals(5));

      final numericalAnalysis = matches.firstWhere((m) => m.courseCode == 'MT2007');
      expect(numericalAnalysis.day, equals('Monday'));
      expect(numericalAnalysis.date, equals('18-May-2026'));
      expect(numericalAnalysis.time, equals('09:00 - 12:00'));

      final dbLab = matches.firstWhere((m) => m.courseCode == 'CL2005');
      expect(dbLab.day, equals('Wednesday'));
      expect(dbLab.date, equals('20-May-2026'));
      expect(dbLab.time, equals('1:00 - 4:00'));

      final aiLab = matches.firstWhere((m) => m.courseCode == 'AL2002');
      expect(aiLab.day, equals('Monday'));
      expect(aiLab.date, equals('25-May-2026'));
      expect(aiLab.time, equals('1:00 - 4:00'));
    });

    test('Test Mid 1 Datesheet Parsing (6 sessions)', () {
      final file = File(r'E:\Flex Connect\mid1 date sheet-Spring2026-StuV1.2.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      
      final registeredCourses = [
        const TranscriptCourse(
          code: 'MT2007',
          courseName: 'Numerical Analysis',
          section: 'BCS-4A',
          creditHours: '3',
          grade: 'A',
          points: '12',
          type: 'Theory',
          remarks: '',
        ),
        const TranscriptCourse(
          code: 'AI2002',
          courseName: 'Artificial Intelligence',
          section: 'BCS-6B',
          creditHours: '3',
          grade: 'A',
          points: '12',
          type: 'Theory',
          remarks: '',
        ),
        const TranscriptCourse(
          code: 'CS2001',
          courseName: 'Data Structures',
          section: 'BCS-3A',
          creditHours: '3',
          grade: 'A',
          points: '12',
          type: 'Theory',
          remarks: '',
        ),
      ];

      final matches = DatesheetParser.parse(
        fileBytes: bytes,
        registeredCourses: registeredCourses,
      );

      print('Mid Exam matches found: ${matches.length}');
      for (final m in matches) {
        print('Date: ${m.date} | Day: ${m.day} | Time: ${m.time} | Code: ${m.courseCode} | Course: ${m.courseName}');
      }

      expect(matches.length, equals(3));

      // MT2007 - Numerical Analysis (Monday 06-Apr-2026 at column index 8 -> 14:00 - 15:00)
      final numericalAnalysis = matches.firstWhere((m) => m.courseCode == 'MT2007');
      expect(numericalAnalysis.day, equals('Monday'));
      expect(numericalAnalysis.date, equals('06-Apr-2026'));
      expect(numericalAnalysis.time, equals('14:00 - 15:00'));

      // AI2002 - Artificial Intelligence (Tuesday 07-Apr-2026 at column index 6 -> 12:00 - 13:00)
      final ai = matches.firstWhere((m) => m.courseCode == 'AI2002');
      expect(ai.day, equals('Tuesday'));
      expect(ai.date, equals('07-Apr-2026'));
      expect(ai.time, equals('12:00 - 13:00'));

      // CS2001 - Data Structures (Wednesday 08-Apr-2026 at column index 8 -> 14:00 - 15:00)
      final ds = matches.firstWhere((m) => m.courseCode == 'CS2001');
      expect(ds.day, equals('Wednesday'));
      expect(ds.date, equals('08-Apr-2026'));
      expect(ds.time, equals('14:00 - 15:00'));
    });
  });
}
