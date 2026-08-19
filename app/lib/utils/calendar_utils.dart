import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/datesheet_parser.dart';
import '../models/timetable_models.dart';
import '../widgets/custom_toast.dart';

class CalendarUtils {
  static DateTime _parseDateString(String dateStr) {
    try {
      final clean = dateStr.trim();
      final parts = clean.split(RegExp(r'[-/\s,]+'));
      
      final List<String> cleanParts = [];
      for (final p in parts) {
        final pLower = p.toLowerCase();
        if (pLower == 'monday' || pLower == 'tuesday' || pLower == 'wednesday' ||
            pLower == 'thursday' || pLower == 'friday' || pLower == 'saturday' ||
            pLower == 'sunday' || pLower == 'mon' || pLower == 'tue' ||
            pLower == 'wed' || pLower == 'thu' || pLower == 'fri' ||
            pLower == 'sat' || pLower == 'sun') {
          continue;
        }
        cleanParts.add(p);
      }

      if (cleanParts.length >= 3) {
        final day = int.tryParse(cleanParts[0]) ?? 1;
        final monthName = cleanParts[1].toLowerCase();
        final year = int.tryParse(cleanParts[2]) ?? DateTime.now().year;

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

  static DateTime? _parseEventDateTime(String dateStr, String timeStr, {bool isStart = true}) {
    try {
      final date = _parseDateString(dateStr);
      if (date.year == 2099) return null;

      final timeParts = timeStr.split(RegExp(r'[-–—]'));
      if (timeParts.isEmpty) return date;

      final timePart = isStart ? timeParts.first.trim() : timeParts.last.trim();
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(timePart);
      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(1)!);
        final int minute = int.parse(timeMatch.group(2)!);
        final String? meridiem = timeMatch.group(3);

        if (meridiem != null) {
          if (meridiem.toLowerCase() == 'pm' && hour != 12) hour += 12;
          if (meridiem.toLowerCase() == 'am' && hour == 12) hour = 0;
        } else {
          if (hour < 8) hour += 12;
        }
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
      return DateTime(date.year, date.month, date.day, isStart ? 9 : 12, 0);
    } catch (_) {
      return null;
    }
  }

  static String _formatToIcsDateTime(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute$second';
  }

  static String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  static String generateDatesheetIcs(List<DatesheetEvent> events) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Flex Connect//Exam Datesheet//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    final nowStr = _formatToIcsDateTime(DateTime.now());

    for (final event in events) {
      final start = _parseEventDateTime(event.date, event.time, isStart: true);
      final end = _parseEventDateTime(event.date, event.time, isStart: false);

      if (start == null || end == null) continue;

      final summary = '${event.type == "LAB" ? "Lab Exam" : "Theory Exam"}: ${event.courseName}';
      final description = 'Course Code: ${event.courseCode}\\nType: ${event.type}\\nSection: ${event.section}';
      final uid = 'datesheet_${event.courseCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_${_formatToIcsDateTime(start)}@flexconnect';

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:$uid');
      buffer.writeln('DTSTAMP:${nowStr}Z');
      buffer.writeln('DTSTART:${_formatToIcsDateTime(start)}');
      buffer.writeln('DTEND:${_formatToIcsDateTime(end)}');
      buffer.writeln('SUMMARY:${_escapeText(summary)}');
      buffer.writeln('DESCRIPTION:$description');
      buffer.writeln('LOCATION:Main Campus');
      buffer.writeln('BEGIN:VALARM');
      buffer.writeln('TRIGGER:-PT15M');
      buffer.writeln('ACTION:DISPLAY');
      buffer.writeln('DESCRIPTION:Exam Reminder (15m before)');
      buffer.writeln('END:VALARM');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String generateRecheckingIcs(List<TimetableDayEvent> events) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Flex Connect//Paper Rechecking Schedule//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    final nowStr = _formatToIcsDateTime(DateTime.now());

    for (final event in events) {
      final start = _parseEventDateTime(event.day, event.time, isStart: true);
      final end = _parseEventDateTime(event.day, event.time, isStart: false);

      if (start == null || end == null) continue;

      final summary = 'Paper Rechecking: ${event.course}';
      final description = 'Teacher: ${event.teacher}\\nRoom: ${event.room}\\nSection: ${event.section}\\nOriginal Section: ${event.originalSection}\\nDegree: ${event.degree}';
      final uid = 'rechecking_${event.course.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_${_formatToIcsDateTime(start)}@flexconnect';

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:$uid');
      buffer.writeln('DTSTAMP:${nowStr}Z');
      buffer.writeln('DTSTART:${_formatToIcsDateTime(start)}');
      buffer.writeln('DTEND:${_formatToIcsDateTime(end)}');
      buffer.writeln('SUMMARY:${_escapeText(summary)}');
      buffer.writeln('DESCRIPTION:$description');
      buffer.writeln('LOCATION:${_escapeText(event.room)}');
      buffer.writeln('BEGIN:VALARM');
      buffer.writeln('TRIGGER:-PT15M');
      buffer.writeln('ACTION:DISPLAY');
      buffer.writeln('DESCRIPTION:Paper Showing Reminder (15m before)');
      buffer.writeln('END:VALARM');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static Future<void> exportAndShare(
    BuildContext context,
    String icsContent,
    String filename,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(icsContent);

      final xFile = XFile(file.path);
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'Import this schedule into your Google Calendar.');
    } catch (e) {
      if (context.mounted) {
        CustomToast.showError(context, 'Failed to export calendar file: $e');
      }
    }
  }
}
