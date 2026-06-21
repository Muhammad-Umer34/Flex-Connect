import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../models/timetable_models.dart';

/// Parses a university timetable Excel file entirely on-device.
/// This is a direct Dart port of the server-side `parseTimetableExcel` function,
/// eliminating the need for a backend server.
class TimetableParser {
  TimetableParser._();

  static const Map<String, String> _deptMapping = {
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
    'MSP': 'MS',
    'MCY': 'CY',
    'MDS': 'DS',
    'PHD': 'PhD',
  };

  static const List<String> _blockTimes = [
    '08:30-10:00',
    '10:00-11:30',
    '11:30-13:00',
    '13:00-14:30',
    '14:30-16:00',
    '16:00-17:30',
    '17:30-19:00',
    '19:00-20:30',
  ];

  static final RegExp _sectionRegex = RegExp(
    r'\b(BCS|BSE|BAI|BDS|BSD|BCY|BBA|BFT|MCS|MS|MSP|MCY|MDS|PHD|BS)\s*[-–—]?\s*([0-9])\s*([A-Za-z][0-9]*)\b',
    caseSensitive: false,
  );

  /// Parse the given Excel bytes with the specified [degreeLevel] filter
  /// ('bachelors' or 'masters') and [campus].
  ///
  /// Returns a [TimetableSnapshot] ready for display.
  static Future<TimetableSnapshot> parse({
    required Uint8List fileBytes,
    required String campus,
    required String degreeLevel,
  }) async {
    // Run parsing on an isolate to avoid blocking the UI thread
    final result = await compute(_parseInIsolate, _ParseArgs(
      fileBytes: fileBytes,
      campus: campus,
      degreeLevel: degreeLevel.toLowerCase(),
    ));
    return result;
  }

  static TimetableSnapshot _parseInIsolate(_ParseArgs args) {
    final excel = Excel.decodeBytes(args.fileBytes);
    final schedule = <TimetableDayEvent>[];
    final departmentsSet = <String>{};
    final sectionsMap = <String, Set<String>>{};
    final seenEvents = <String>{};

    // Prioritize "Combined TT" sheet if it exists
    List<String> sheetsToParse = excel.tables.keys.toList();
    if (sheetsToParse.contains('Combined TT')) {
      sheetsToParse = ['Combined TT'];
    }

    for (final sheetName in sheetsToParse) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      String currentDay = 'Monday';

      for (int r = 0; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        // 1. Detect Day in Column 0
        final dayCell = row.isNotEmpty ? row[0] : null;
        if (dayCell != null && dayCell.value != null) {
          final val = dayCell.value.toString().trim().toLowerCase();
          if (val.startsWith('mon')) {
            currentDay = 'Monday';
          } else if (val.startsWith('tue')) {
            currentDay = 'Tuesday';
          } else if (val.startsWith('wed')) {
            currentDay = 'Wednesday';
          } else if (val.startsWith('thu')) {
            currentDay = 'Thursday';
          } else if (val.startsWith('fri')) {
            currentDay = 'Friday';
          } else if (val.startsWith('sat')) {
            currentDay = 'Saturday';
          } else if (val.startsWith('sun')) {
            currentDay = 'Sunday';
          }
        }

        // 2. Room Name in Column 1
        final roomCell = row.length > 1 ? row[1] : null;
        final room = roomCell?.value?.toString().trim() ?? '';
        if (room.isEmpty ||
            room == 'Room' ||
            room == 'Periods' ||
            room == 'Days') {
          continue;
        }

        // 3. Scan columns for class cells starting from Column 2
        for (int c = 2; c < row.length; c++) {
          final cell = row[c];
          if (cell == null || cell.value == null) continue;

          final val = cell.value.toString().trim();
          if (val.length < 3) continue; // skip noise

          // Find merge range for this cell
          int cStart = c;
          int cEnd = c;
          for (final rangeStr in sheet.spannedItems) {
            final parts = rangeStr.split(':');
            if (parts.length == 2) {
              final startCell = CellIndex.indexByString(parts[0]);
              final endCell = CellIndex.indexByString(parts[1]);

              final startRow = startCell.rowIndex;
              final endRow = endCell.rowIndex;
              final startCol = startCell.columnIndex;
              final endCol = endCell.columnIndex;

              if (r >= startRow &&
                  r <= endRow &&
                  c >= startCol &&
                  c <= endCol) {
                // Only process at the top-left of the merge
                if (c != startCol) {
                  cStart = -1; // Signal to skip
                  break;
                }
                cStart = startCol;
                cEnd = endCol;
                break;
              }
            }
          }
          if (cStart == -1) continue;

          // Match section patterns like BCS-4D
          final matches = _sectionRegex
              .allMatches(val)
              .map((m) => _SectionMatch(
                    full: m.group(0)!,
                    deptPrefix: m.group(1)!.toUpperCase(),
                    semester: m.group(2)!,
                    sectionLetter: m.group(3)!.toUpperCase(),
                  ))
              .toList();

          if (matches.isEmpty) continue;

          // 4. Resolve Time based on column boundaries
          final startIndex = ((cStart - 5) / 9).floor();
          final endIndex = ((cEnd - 5) / 9).floor();
          final startTime =
              (startIndex >= 0 && startIndex < _blockTimes.length)
                  ? _blockTimes[startIndex].split('-')[0].trim()
                  : '08:30';
          final endTime = (endIndex >= 0 && endIndex < _blockTimes.length)
              ? _blockTimes[endIndex].split('-')[1].trim()
              : '10:00';
          final time = '$startTime-$endTime';

          // 5. Clean up course name and teacher by removing parenthesized sections
          String cleanVal = val.replaceAll(RegExp(r'\([^)]*\)'), '');
          cleanVal = cleanVal
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          cleanVal = cleanVal
              .replaceAll(RegExp(r'^[:,\s]+|[:,\s]+$'), '')
              .trim();

          String course = cleanVal;
          String teacher = 'Staff';

          if (cleanVal.contains(':')) {
            final parts = cleanVal.split(':');
            course = parts[0].trim();
            teacher = parts.sublist(1).join(':').trim();
          }

          if (course.isEmpty) course = 'Scheduled Class';
          if (teacher.isEmpty) teacher = 'Staff';

          // 6. Process each section match
          for (final m in matches) {
            final mappedDept = _deptMapping[m.deptPrefix] ?? m.deptPrefix;
            String matchDegree = 'bachelors';
            if (['MCS', 'MS', 'MSP', 'MCY', 'MDS', 'PHD'].contains(m.deptPrefix)) {
              matchDegree = 'masters';
            }

            if (matchDegree != args.degreeLevel) continue;

            departmentsSet.add(mappedDept);

            final deptSection =
                '$mappedDept-${m.semester}${m.sectionLetter}';
            sectionsMap.putIfAbsent(mappedDept, () => <String>{});
            sectionsMap[mappedDept]!.add(deptSection);

            // De-duplicate
            final eventKey =
                '$currentDay|$time|$room|$deptSection|$course|$teacher|$matchDegree';
            if (seenEvents.contains(eventKey)) continue;
            seenEvents.add(eventKey);

            schedule.add(TimetableDayEvent(
              day: currentDay,
              time: time,
              room: room,
              section: deptSection,
              originalSection: m.full,
              course: course,
              teacher: teacher,
              degree: matchDegree,
            ));
          }
        }
      }
    }

    final departments = departmentsSet.toList()..sort();
    final sections = <String, List<String>>{};
    for (final entry in sectionsMap.entries) {
      sections[entry.key] = entry.value.toList()..sort();
    }

    return TimetableSnapshot(
      campus: args.campus,
      degree: args.degreeLevel,
      departments: departments,
      sections: sections,
      schedule: schedule,
      capturedAt: DateTime.now(),
    );
  }
}

class _ParseArgs {
  final Uint8List fileBytes;
  final String campus;
  final String degreeLevel;

  const _ParseArgs({
    required this.fileBytes,
    required this.campus,
    required this.degreeLevel,
  });
}

class _SectionMatch {
  final String full;
  final String deptPrefix;
  final String semester;
  final String sectionLetter;

  const _SectionMatch({
    required this.full,
    required this.deptPrefix,
    required this.semester,
    required this.sectionLetter,
  });
}
