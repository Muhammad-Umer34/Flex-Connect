import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/transcript_models.dart';

bool matchesMergedLetter(String lineLetter, String studentLetter) {
  if (lineLetter.toUpperCase() == studentLetter.toUpperCase()) return true;
  if (lineLetter.toLowerCase().startsWith(studentLetter.toLowerCase())) {
    final remaining = lineLetter.substring(studentLetter.length);
    if (remaining.isNotEmpty) {
      final firstChar = remaining[0];
      if (firstChar == firstChar.toUpperCase() && RegExp(r'[A-Z]').hasMatch(firstChar)) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  test('Trace EE3009 matching step by step with fixes', () {
    final line = "228EE3009Computer ArchitectureBCS-6BZeeshan Ali KhanThursday, 04 June, 2026Thursday, 11 June, 202612:25-12:40 PMF-208";
    
    final course = const TranscriptCourse(
      code: 'EE3009',
      courseName: 'Computer Architecture',
      section: 'BCS-6B',
      creditHours: '3',
      grade: 'A',
      points: '4.0',
      type: 'Core',
      remarks: '',
    );

    print('Line: "$line"');
    
    final codeNormalized = course.code.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
    final lineNormalized = line.replaceAll('-', '').replaceAll(' ', '').toLowerCase();

    final matchesCode = codeNormalized.isNotEmpty && lineNormalized.contains(codeNormalized);
    final matchesName = course.courseName.isNotEmpty && line.toLowerCase().contains(course.courseName.toLowerCase());

    if (matchesCode || matchesName) {
      final section = course.section.trim();
      bool matchesSection = false;

      if (section.isNotEmpty) {
        const deptMapping = {
          'BCS': 'CS',
          'BSE': 'SE',
          'BAI': 'AI',
          'BDS': 'DS',
          'BSD': 'DS',
          'BCY': 'CY',
          'BBA': 'BA',
          'BFT': 'FT',
          'BS': 'CS',
          'MCS': 'CS',
          'MS': 'MS',
          'PHD': 'PhD',
        };

        final studentSectionRegex = RegExp(r'^([A-Za-z]+)-?([0-9]+)([A-Za-z]*)$');
        final studentMatch = studentSectionRegex.firstMatch(section);

        if (studentMatch != null) {
          final studentDept = studentMatch.group(1)!.toUpperCase();
          final studentSem = studentMatch.group(2)!;
          final studentLetter = studentMatch.group(3)!.toUpperCase();
          final studentCanonicalDept = deptMapping[studentDept] ?? studentDept;

          // Note: Removed the \b at the beginning of the regex to allow merged matches
          final sectionInLineRegex = RegExp(
            r'(BCS|BSE|BAI|BDS|BSD|BCY|BBA|BFT|MCS|MS|PHD|BS|CS|SE|AI|DS|CY|BA|FT|Lab)?\s*[-–—_]?\s*([0-9]+)\s*[-–—_]?\s*([A-Za-z]+)\b',
            caseSensitive: false,
          );
          final matchesInLine = sectionInLineRegex.allMatches(line);
          print('matchesInLine count: ${matchesInLine.length}');

          for (final m in matchesInLine) {
            final lineDeptRaw = m.group(1);
            final lineSem = m.group(2);
            final lineLetter = m.group(3)!.toUpperCase();
            print('Line match: "${m.group(0)}" -> lineDeptRaw: $lineDeptRaw, lineSem: $lineSem, lineLetter: $lineLetter');

            if (lineSem == studentSem && matchesMergedLetter(lineLetter, studentLetter)) {
              print('Sem and Letter matched!');
              if (lineDeptRaw == null || lineDeptRaw.isEmpty || lineDeptRaw.toLowerCase() == 'lab') {
                print('lineDeptRaw is empty or lab -> matched');
                matchesSection = true;
                break;
              } else {
                final lineDept = lineDeptRaw.toUpperCase();
                final lineCanonicalDept = deptMapping[lineDept] ?? lineDept;
                print('lineDept: $lineDept, lineCanonicalDept: $lineCanonicalDept');
                if (lineCanonicalDept == studentCanonicalDept) {
                  print('Canonical department matches! -> matched');
                  matchesSection = true;
                  break;
                }
              }
            }
          }
        }
      }
      print('matchesSection final result: $matchesSection');
    }
  });
}
