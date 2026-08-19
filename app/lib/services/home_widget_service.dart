import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'timetable_storage.dart';
import 'datesheet_storage.dart';
import 'datesheet_parser.dart';
import '../models/timetable_models.dart';

class HomeWidgetService {
  HomeWidgetService._();

  /// Calculates the current and next class for today and updates the native widget.
  static Future<void> updateNextClassWidget() async {
    try {
      final datesheetEvents = await DatesheetStorage.load();
      if (datesheetEvents != null && datesheetEvents.isNotEmpty) {
        final now = DateTime.now();
        final todayDate = DateTime(now.year, now.month, now.day);
        
        final parsedExamDates = datesheetEvents
            .map((e) => _parseDatesheetDate(e.date))
            .whereType<DateTime>()
            .toList();
            
        if (parsedExamDates.isNotEmpty) {
          parsedExamDates.sort();
          final firstExamDate = parsedExamDates.first;
          final lastExamDate = parsedExamDates.last;

          final isExamPeriod = !todayDate.isBefore(firstExamDate) && !todayDate.isAfter(lastExamDate);

          if (isExamPeriod) {
            DatesheetEvent? todayExam;
            for (final exam in datesheetEvents) {
              final examDate = _parseDatesheetDate(exam.date);
              if (examDate != null &&
                  examDate.year == todayDate.year &&
                  examDate.month == todayDate.month &&
                  examDate.day == todayDate.day) {
                todayExam = exam;
                break;
              }
            }

            if (todayExam != null) {
              await HomeWidget.saveWidgetData<bool>('is_off_day', false);
              await HomeWidget.saveWidgetData<String>('ongoing_course', '${todayExam.courseName} (${todayExam.type})');
              await HomeWidget.saveWidgetData<String>('ongoing_time', todayExam.time);
              await HomeWidget.saveWidgetData<String>('ongoing_room', 'Exam Session');
              await HomeWidget.saveWidgetData<String>('next_course', '');
              await HomeWidget.saveWidgetData<String>('next_time', '');
              await HomeWidget.saveWidgetData<String>('next_room', '');
              await HomeWidget.saveWidgetData<String>('todays_schedule_json', '[]');
              await HomeWidget.updateWidget(
                name: 'NextClassWidgetProvider',
                androidName: 'NextClassWidgetProvider',
              );
            } else {
              await _clearWidgetData();
            }
            return;
          }
        }
      }
      final snapshot = await TimetableStorage.load();
      final section = await TimetableStorage.loadSelectedSection();
      final customEvents = await TimetableStorage.loadCustomEvents();

      if (snapshot == null || section == null) {
        await _clearWidgetData();
        return;
      }

      final allEvents = <TimetableDayEvent>[];

      if (customEvents.isNotEmpty) {
        allEvents.addAll(customEvents);
      } else {
        for (final event in snapshot.schedule) {
          if (event.section.trim().toUpperCase() == section.trim().toUpperCase()) {
            allEvents.add(event);
          }
        }
      }

      if (allEvents.isEmpty) {
        await _clearWidgetData();
        return;
      }

      final now = DateTime.now();
      final currentWeekdayName = _getWeekdayName(now.weekday);

      // Filter events to find classes specifically for TODAY
      final todayEvents = allEvents.where(
        (e) => e.day.trim().toLowerCase() == currentWeekdayName.toLowerCase(),
      ).toList();

      if (todayEvents.isEmpty) {
        // Today is an off-day
        await _clearWidgetData();
        return;
      }

      // Parse and construct start/end DateTimes for today's classes
      final parsedTodayEvents = todayEvents.map((e) {
        final parsedTime = _parseEventTime(e.time, now);
        return _ParsedEvent(
          event: e,
          start: parsedTime['start'],
          end: parsedTime['end'],
        );
      }).where((pe) => pe.start != null && pe.end != null).toList();

      // Sort by start time chronological order
      parsedTodayEvents.sort((a, b) => a.start!.compareTo(b.start!));

      _ParsedEvent? ongoingClass;
      _ParsedEvent? nextClass;

      for (final pe in parsedTodayEvents) {
        final start = pe.start!;
        final end = pe.end!;
        
        if (now.isAfter(start) && now.isBefore(end)) {
          ongoingClass = pe;
        } else if (now.isBefore(start)) {
          if (nextClass == null) {
            nextClass = pe;
          }
        }
      }

      // Serialize today's full timetable to JSON
      final todaysScheduleList = parsedTodayEvents.map((pe) => {
        'time': pe.event.time,
        'course': pe.event.course,
        'room': pe.event.room,
      }).toList();

      // If all classes for today have ended:
      final allCompleted = ongoingClass == null && nextClass == null;
      if (allCompleted) {
        await HomeWidget.saveWidgetData<bool>('is_off_day', false);
        await HomeWidget.saveWidgetData<String>('ongoing_course', 'Classes Finished 🎉');
        await HomeWidget.saveWidgetData<String>('ongoing_time', 'All done for today');
        await HomeWidget.saveWidgetData<String>('ongoing_room', 'See you tomorrow!');
        await HomeWidget.saveWidgetData<String>('next_course', '');
        await HomeWidget.saveWidgetData<String>('next_time', '');
        await HomeWidget.saveWidgetData<String>('next_room', '');
        await HomeWidget.saveWidgetData<String>('todays_schedule_json', jsonEncode(todaysScheduleList));
        await HomeWidget.updateWidget(
          name: 'NextClassWidgetProvider',
          androidName: 'NextClassWidgetProvider',
        );
        return;
      }

      // Update widget state
      await HomeWidget.saveWidgetData<bool>('is_off_day', false);
      
      // Save ongoing class data
      if (ongoingClass != null) {
        await HomeWidget.saveWidgetData<String>('ongoing_course', ongoingClass.event.course);
        await HomeWidget.saveWidgetData<String>('ongoing_time', ongoingClass.event.time);
        await HomeWidget.saveWidgetData<String>('ongoing_room', ongoingClass.event.room);
      } else {
        await HomeWidget.saveWidgetData<String>('ongoing_course', '');
        await HomeWidget.saveWidgetData<String>('ongoing_time', '');
        await HomeWidget.saveWidgetData<String>('ongoing_room', '');
      }

      // Save next class data
      if (nextClass != null) {
        await HomeWidget.saveWidgetData<String>('next_course', nextClass.event.course);
        await HomeWidget.saveWidgetData<String>('next_time', nextClass.event.time);
        await HomeWidget.saveWidgetData<String>('next_room', nextClass.event.room);
      } else {
        await HomeWidget.saveWidgetData<String>('next_course', '');
        await HomeWidget.saveWidgetData<String>('next_time', '');
        await HomeWidget.saveWidgetData<String>('next_room', '');
      }

      // Save full today list json
      await HomeWidget.saveWidgetData<String>('todays_schedule_json', jsonEncode(todaysScheduleList));

      // Trigger update native provider
      await HomeWidget.updateWidget(
        name: 'NextClassWidgetProvider',
        androidName: 'NextClassWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error updating home screen widget: $e');
    }
  }

  static Future<void> _clearWidgetData() async {
    await HomeWidget.saveWidgetData<bool>('is_off_day', true);
    await HomeWidget.saveWidgetData<String>('ongoing_course', '');
    await HomeWidget.saveWidgetData<String>('ongoing_time', '');
    await HomeWidget.saveWidgetData<String>('ongoing_room', '');
    await HomeWidget.saveWidgetData<String>('next_course', '');
    await HomeWidget.saveWidgetData<String>('next_time', '');
    await HomeWidget.saveWidgetData<String>('next_room', '');
    await HomeWidget.saveWidgetData<String>('todays_schedule_json', '[]');
    await HomeWidget.updateWidget(
      name: 'NextClassWidgetProvider',
      androidName: 'NextClassWidgetProvider',
    );
  }

  static String _getWeekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    if (weekday >= 1 && weekday <= 7) {
      return names[weekday - 1];
    }
    return 'Monday';
  }

  static Map<String, DateTime?> _parseEventTime(String timeStr, DateTime baseDate) {
    try {
      final parts = timeStr.split('-');
      if (parts.length != 2) return {'start': null, 'end': null};

      final startParts = parts[0].trim().split(':');
      final endParts = parts[1].trim().split(':');

      if (startParts.length != 2 || endParts.length != 2) return {'start': null, 'end': null};

      var startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      var endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      // Normalize 12-hour afternoon slots (01:00 to 07:00) to 24-hour clock (13 to 19)
      if (startHour >= 1 && startHour <= 7) {
        startHour += 12;
      }
      if (endHour >= 1 && endHour <= 7) {
        endHour += 12;
      }

      final start = DateTime(baseDate.year, baseDate.month, baseDate.day, startHour, startMin);
      final end = DateTime(baseDate.year, baseDate.month, baseDate.day, endHour, endMin);

      return {'start': start, 'end': end};
    } catch (_) {
      return {'start': null, 'end': null};
    }
  }

  static DateTime? _parseDatesheetDate(String dateStr) {
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
    return null;
  }
}

class _ParsedEvent {
  final TimetableDayEvent event;
  final DateTime? start;
  final DateTime? end;

  _ParsedEvent({required this.event, this.start, this.end});
}
