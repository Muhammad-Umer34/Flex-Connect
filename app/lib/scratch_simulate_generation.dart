import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:app/models/timetable_models.dart';
import 'package:app/services/timetable_parser.dart';

bool isCoreCourse(TimetableSnapshot snapshot, String course, String dept, int semester) {
  final regex = RegExp('^${RegExp.escape(dept)}-$semester([A-Z]+)\$', caseSensitive: false);
  
  final allSectionsInDeptSem = snapshot.schedule
      .map((e) => e.section.replaceAll(RegExp(r'[0-9]+$'), ''))
      .where((s) => regex.hasMatch(s))
      .toSet()
      .toList();

  if (allSectionsInDeptSem.isEmpty) {
    print('  - _isCoreCourse: no sections found in dept $dept, sem $semester');
    return false;
  }

  final sectionsWithThisCourse = snapshot.schedule
      .where((e) => e.course.toLowerCase().trim() == course.toLowerCase().trim())
      .map((e) => e.section.replaceAll(RegExp(r'[0-9]+$'), ''))
      .where((s) => allSectionsInDeptSem.contains(s))
      .toSet();

  final ratio = sectionsWithThisCourse.length / allSectionsInDeptSem.length;
  print('  - Course: $course, Sections with it: $sectionsWithThisCourse, Ratio: $ratio');
  return ratio >= 0.7;
}

void main() async {
  final file = File('../uploaded_timetable.xlsx');
  final bytes = file.readAsBytesSync();
  
  // We simulate dynamic fetching from preferences:
  final campus = 'Lahore';
  final degreeLevel = 'bachelors';
  final finalSection = 'CS-6B';
  final dept = 'CS';
  final semester = 6;
  
  print('--- Simulating Parser & Generator ---');
  final snapshot = await TimetableParser.parse(
    fileBytes: bytes,
    campus: campus,
    degreeLevel: degreeLevel,
  );
  
  print('Total events in schedule: ${snapshot.schedule.length}');
  
  // Try exact matching
  final exactEvents = snapshot.schedule.where((e) => e.section == finalSection).toList();
  print('Exact section match events: ${exactEvents.length}');
  
  // Try pattern matching
  final matchedEvents = snapshot.schedule.where((e) => e.section == finalSection || (e.section.startsWith(finalSection) && RegExp(r'^[0-9]+$').hasMatch(e.section.substring(finalSection.length)))).toList();
  print('Pattern section match events: ${matchedEvents.length}');
  
  print('Core events:');
  final coreEvents = matchedEvents.where((e) => isCoreCourse(snapshot, e.course, dept, semester)).toList();
  print('Total core events: ${coreEvents.length}');
  for (final e in coreEvents) {
    print('  - ${e.course} (${e.section}) at ${e.day} ${e.time}');
  }
}
