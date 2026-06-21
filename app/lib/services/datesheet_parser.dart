import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../models/transcript_models.dart';

class DatesheetEvent {
  final String date;
  final String day;
  final String time;
  final String courseCode;
  final String courseName;
  final String section;
  final String type; // 'THEORY' or 'LAB'

  const DatesheetEvent({
    required this.date,
    required this.day,
    required this.time,
    required this.courseCode,
    required this.courseName,
    required this.section,
    required this.type,
  });

  factory DatesheetEvent.fromJson(Map<String, dynamic> json) {
    return DatesheetEvent(
      date: (json['date'] as String?) ?? '',
      day: (json['day'] as String?) ?? '',
      time: (json['time'] as String?) ?? '',
      courseCode: (json['courseCode'] as String?) ?? '',
      courseName: (json['courseName'] as String?) ?? '',
      section: (json['section'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'THEORY',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'day': day,
      'time': time,
      'courseCode': courseCode,
      'courseName': courseName,
      'section': section,
      'type': type,
    };
  }
}

class DatesheetParser {
  DatesheetParser._();

  static List<DatesheetEvent> parse({
    required Uint8List fileBytes,
    required List<TranscriptCourse> registeredCourses,
  }) {
    final excel = Excel.decodeBytes(fileBytes);
    final List<DatesheetEvent> matchedEvents = [];

    if (excel.tables.isEmpty) return [];

    // Prioritize sheet named 'Complete' if it exists, otherwise use first available
    final sheetName = excel.tables.containsKey('Complete')
        ? 'Complete'
        : excel.tables.keys.first;

    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) return [];

    String currentDay = '';
    String currentDate = '';
    
    // Map column index of code to session time string
    final Map<int, String> sessionColumns = {};

    for (int r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;

      // Extract raw column values
      final dayVal = row[0]?.value?.toString().trim() ?? '';
      final dateVal = row[1]?.value?.toString().trim() ?? '';

      // Update current day/date (handling merged cells)
      if (dayVal.isNotEmpty) currentDay = dayVal;
      if (dateVal.isNotEmpty) currentDate = dateVal;

      // Detect header row (contains "day" or "date" labels)
      final dayLower = dayVal.toLowerCase();
      final dateLower = dateVal.toLowerCase();
      if (dayLower == 'day' || dateLower == 'date') {
        sessionColumns.clear();
        // Step through columns, pairing Code columns with their session time header column
        for (int c = 2; c < row.length - 1; c += 2) {
          final timeHeader = row[c + 1]?.value?.toString().trim() ?? '';
          if (timeHeader.isNotEmpty && timeHeader.contains(':')) {
            sessionColumns[c] = timeHeader;
          }
        }
        continue;
      }

      // Skip rows if we haven't identified the day/date yet
      if (currentDay.isEmpty || currentDate.isEmpty) continue;

      // Skip title rows or other general header metadata rows
      if (currentDay.toLowerCase() == 'day' || currentDate.toLowerCase() == 'date') {
        continue;
      }

      // Loop through all parsed session columns dynamically
      for (final entry in sessionColumns.entries) {
        final codeIndex = entry.key;
        final timeString = entry.value;

        if (row.length > codeIndex + 1) {
          final courseCode = row[codeIndex]?.value?.toString().trim() ?? '';
          final courseName = row[codeIndex + 1]?.value?.toString().trim() ?? '';

          if (courseCode.isNotEmpty) {
            final match = _findMatchingCourse(courseCode, courseName, registeredCourses);
            if (match != null && _isEventRelevantToSection(courseName, match.section)) {
              matchedEvents.add(DatesheetEvent(
                date: currentDate,
                day: currentDay,
                time: timeString,
                courseCode: courseCode,
                courseName: courseName,
                section: match.section,
                type: _isLabCourse(courseCode, courseName) ? 'LAB' : 'THEORY',
              ));
            }
          }
        }
      }
    }

    // Sort chronologically using a custom date parser helper
    matchedEvents.sort((a, b) {
      final dateA = _parseDateString(a.date);
      final dateB = _parseDateString(b.date);
      final dateCompare = dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;

      // Fallback: sort by morning/afternoon session time
      return a.time.compareTo(b.time);
    });

    return matchedEvents;
  }

  static TranscriptCourse? _findMatchingCourse(
    String sheetCode,
    String sheetName,
    List<TranscriptCourse> courses,
  ) {
    final cleanSheetCode = _cleanCode(sheetCode);
    final cleanSheetName = sheetName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final course in courses) {
      final cleanCourseCode = _cleanCode(course.code);
      final cleanCourseName = course.courseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      // 1. Match by cleaned course code
      if (cleanSheetCode.isNotEmpty && cleanCourseCode.isNotEmpty) {
        if (cleanSheetCode == cleanCourseCode ||
            cleanSheetCode.startsWith(cleanCourseCode) ||
            cleanCourseCode.startsWith(cleanSheetCode)) {
          return course;
        }
      }

      // 2. Match by exact cleaned course name (fallback)
      if (cleanSheetName.isNotEmpty && cleanCourseName.isNotEmpty) {
        if (cleanSheetName == cleanCourseName) {
          return course;
        }
      }
    }
    return null;
  }

  static String _cleanCode(String code) {
    return code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool _isLabCourse(String code, String name) {
    final cLower = code.toLowerCase();
    final nLower = name.toLowerCase();
    return cLower.contains('lab') ||
        cLower.contains('laboratory') ||
        nLower.contains('lab') ||
        nLower.contains('laboratory');
  }

  static DateTime _parseDateString(String dateStr) {
    try {
      final clean = dateStr.trim();
      final parts = clean.split(RegExp(r'[-/\s,]+'));
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final monthName = parts[1].toLowerCase();
        final year = int.tryParse(parts[2]) ?? DateTime.now().year;

        const months = {
          'jan': 1, 'january': 1,
          'feb': 2, 'february': 2,
          'mar': 3, 'march': 3,
          'apr': 4, 'april': 4,
          'may': 5,
          'jun': 6, 'june': 6,
          'jul': 7, 'july': 7,
          'aug': 8, 'august': 8,
          'sep': 9, 'september': 9,
          'oct': 10, 'october': 10,
          'nov': 11, 'november': 11,
          'dec': 12, 'december': 12,
        };

        final month = months[monthName] ?? 1;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime(2099, 12, 31);
  }

  static bool _isEventRelevantToSection(String sheetName, String studentSection) {
    // Extract anything inside parentheses in the course name
    // e.g. "Artificial Intelligence - Lab (BCS-6A, 6B, BDS-6A, 6B)"
    final match = RegExp(r'\(([^)]+)\)').firstMatch(sheetName);
    if (match == null) {
      // No parentheses with sections found, assume it is general/relevant
      return true;
    }

    final sectionsContent = match.group(1) ?? '';
    final parts = sectionsContent.split(',');
    
    final List<String> parsedSections = [];
    String currentDept = '';
    String currentSem = '';

    final fullSectionRegex = RegExp(r'\b([A-Za-z]+)\s*-\s*([0-9])([A-Za-z])\b');
    final shortSectionRegex = RegExp(r'\b([0-9])([A-Za-z])\b');
    final letterOnlyRegex = RegExp(r'\b([A-Za-z])\b');

    for (final part in parts) {
      final cleanPart = part.trim();
      
      final fullMatch = fullSectionRegex.firstMatch(cleanPart);
      if (fullMatch != null) {
        currentDept = fullMatch.group(1)!.toUpperCase();
        currentSem = fullMatch.group(2)!;
        final letter = fullMatch.group(3)!.toUpperCase();
        parsedSections.add('$currentDept-$currentSem$letter');
        continue;
      }

      final shortMatch = shortSectionRegex.firstMatch(cleanPart);
      if (shortMatch != null) {
        currentSem = shortMatch.group(1)!;
        final letter = shortMatch.group(2)!.toUpperCase();
        if (currentDept.isNotEmpty) {
          parsedSections.add('$currentDept-$currentSem$letter');
        }
        continue;
      }

      final letterMatch = letterOnlyRegex.firstMatch(cleanPart);
      if (letterMatch != null) {
        final letter = letterMatch.group(1)!.toUpperCase();
        if (currentDept.isNotEmpty && currentSem.isNotEmpty) {
          parsedSections.add('$currentDept-$currentSem$letter');
        }
        continue;
      }
    }

    if (parsedSections.isEmpty) {
      // If we couldn't parse any structured sections inside the parentheses,
      // fall back to true (general course) to avoid missing exams.
      return true;
    }

    final cleanStudentSec = studentSection.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return parsedSections.contains(cleanStudentSec);
  }
}
