import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/marks_models.dart';
import '../models/marks_changelog.dart';
import 'marks_changelog_storage.dart';

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

  static bool _isValidScore(String score) {
    final s = score.trim();
    return s.isNotEmpty && s != '-' && s != '—' && s != 'null';
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
      final List<MarksChangelogEntry> newEntries = [];
      final timestamp = DateTime.now();
      const uuid = Uuid();

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

        // Scenario 1: Completely new course
        if (oldCourse.paneId.isEmpty && oldCourse.courseCode.isEmpty) {
          updatedCourseCodes.add(newCourse.displayTitle);
          for (final section in newCourse.sections) {
            for (final row in section.rows) {
              final isTotal = row.itemNo.trim().isEmpty || row.itemNo.toLowerCase().contains('total');
              if (!isTotal && _isValidScore(row.obtained)) {
                newEntries.add(MarksChangelogEntry(
                  id: uuid.v4(),
                  timestamp: timestamp,
                  courseTitle: newCourse.displayTitle,
                  itemNo: row.itemNo,
                  changeType: 'added',
                  newObtained: row.obtained,
                  total: row.total,
                ));
              }
            }
          }
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
          
          // Scenario 2: Completely new section in an existing course
          if (oldSectionRows == null) {
            for (final newRow in newSection.rows) {
              final isTotal = newRow.itemNo.trim().isEmpty || newRow.itemNo.toLowerCase().contains('total');
              if (!isTotal && _isValidScore(newRow.obtained)) {
                hasNewMark = true;
                newEntries.add(MarksChangelogEntry(
                  id: uuid.v4(),
                  timestamp: timestamp,
                  courseTitle: newCourse.displayTitle,
                  itemNo: newRow.itemNo,
                  changeType: 'added',
                  newObtained: newRow.obtained,
                  total: newRow.total,
                ));
              }
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
              // Scenario 3: New evaluation row added
              if (_isValidScore(newRow.obtained)) {
                hasNewMark = true;
                newEntries.add(MarksChangelogEntry(
                  id: uuid.v4(),
                  timestamp: timestamp,
                  courseTitle: newCourse.displayTitle,
                  itemNo: newRow.itemNo,
                  changeType: 'added',
                  newObtained: newRow.obtained,
                  total: newRow.total,
                ));
              }
            } else {
              // Scenario 4: Evaluation row score modified
              if (newRow.obtained != oldRow.obtained) {
                // If it changed from empty/hyphen to a valid score, log as 'added' if old was invalid
                final oldValid = _isValidScore(oldRow.obtained);
                final newValid = _isValidScore(newRow.obtained);
                
                if (newValid) {
                  hasNewMark = true;
                  newEntries.add(MarksChangelogEntry(
                    id: uuid.v4(),
                    timestamp: timestamp,
                    courseTitle: newCourse.displayTitle,
                    itemNo: newRow.itemNo,
                    changeType: oldValid ? 'updated' : 'added',
                    oldObtained: oldValid ? oldRow.obtained : null,
                    newObtained: newRow.obtained,
                    total: newRow.total,
                  ));
                }
              }
            }
          }
        }

        if (hasNewMark) {
          updatedCourseCodes.add(newCourse.displayTitle);
        }
      }

      if (newEntries.isNotEmpty) {
        await MarksChangelogStorage.appendEntries(newEntries);
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
