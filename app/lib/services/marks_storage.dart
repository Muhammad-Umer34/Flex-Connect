import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/marks_models.dart';

class MarksStorage {
  static const String marksDataKey = 'flex_marks_data';

  static final ValueNotifier<List<String>> highlightedCoursesNotifier = ValueNotifier<List<String>>([]);

  static Future<void> updateHighlightsNotifier() async {
    final prefs = await SharedPreferences.getInstance();
    final highlights = prefs.getStringList('flex_highlighted_courses') ?? [];
    highlightedCoursesNotifier.value = highlights;
  }

  static Future<MarksSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedMarks = preferences.getString(marksDataKey);

    if (storedMarks == null || storedMarks.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(storedMarks);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return MarksSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> compareAndHighlightNewMarks(
    Map<String, dynamic> newJson,
    String? oldJsonString,
  ) async {
    if (oldJsonString == null || oldJsonString.isEmpty) {
      return;
    }

    try {
      final oldJson = jsonDecode(oldJsonString);
      if (oldJson is! Map<String, dynamic>) {
        return;
      }

      final oldSnapshot = MarksSnapshot.fromJson(oldJson);
      final newSnapshot = MarksSnapshot.fromJson(newJson);

      final List<String> updatedCourseCodes = [];

      for (final newCourse in newSnapshot.courses) {
        final oldCourse = oldSnapshot.courses.firstWhere(
          (c) => c.displayTitle == newCourse.displayTitle,
          orElse: () => MarksCourse(
            paneId: '',
            courseCode: '',
            courseTitle: '',
            heading: '',
            sections: const [],
          ),
        );

        if (oldCourse.paneId.isEmpty && oldCourse.courseCode.isEmpty) {
          updatedCourseCodes.add(newCourse.displayTitle);
          continue;
        }

        bool hasNewMark = false;

        final Map<String, Map<String, MarksRow>> oldRowsBySection = {};
        for (final section in oldCourse.sections) {
          final rowsMap = <String, MarksRow>{};
          for (final row in section.rows) {
            final isTotalRow = row.itemNo.trim().isEmpty || row.itemNo.toLowerCase().contains('total');
            if (!isTotalRow) {
              rowsMap[row.itemNo] = row;
            }
          }
          oldRowsBySection[section.sectionName] = rowsMap;
        }

        for (final newSection in newCourse.sections) {
          final oldSectionRows = oldRowsBySection[newSection.sectionName];
          if (oldSectionRows == null) {
            final hasNewNonTotal = newSection.rows.any((r) =>
                !(r.itemNo.trim().isEmpty || r.itemNo.toLowerCase().contains('total')));
            if (hasNewNonTotal) {
              hasNewMark = true;
              break;
            }
            continue;
          }

          for (final newRow in newSection.rows) {
            final isTotal = newRow.itemNo.trim().isEmpty || newRow.itemNo.toLowerCase().contains('total');
            if (isTotal) {
              continue;
            }

            final oldRow = oldSectionRows[newRow.itemNo];
            if (oldRow == null) {
              hasNewMark = true;
              break;
            } else {
              if (newRow.obtained != oldRow.obtained) {
                hasNewMark = true;
                break;
              }
            }
          }
          if (hasNewMark) {
            break;
          }
        }

        if (hasNewMark) {
          updatedCourseCodes.add(newCourse.displayTitle);
        }
      }

      if (updatedCourseCodes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final currentHighlights = prefs.getStringList('flex_highlighted_courses') ?? [];
        final merged = {...currentHighlights, ...updatedCourseCodes}.toList();
        await prefs.setStringList('flex_highlighted_courses', merged);
        highlightedCoursesNotifier.value = merged;
        try {
          await HapticFeedback.vibrate();
        } catch (_) {}
      }
    } catch (_) {
      // Ignore comparison errors to prevent sync failures
    }
  }
}
