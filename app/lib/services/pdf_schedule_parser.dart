import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/timetable_models.dart';
import '../models/transcript_models.dart';

class PdfScheduleParser {
  PdfScheduleParser._();

  static bool _matchesMergedLetter(String lineLetter, String studentLetter) {
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

  static List<TimetableDayEvent> parse({
    required Uint8List pdfBytes,
    required List<TranscriptCourse> registeredCourses,
  }) {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    final String text = PdfTextExtractor(document).extractText();
    document.dispose();

    final List<TimetableDayEvent> events = [];
    final List<String> lines = text.split('\n');

    String currentDay = 'Monday';
    String currentTime = '08:30-10:00';
    String currentRoom = 'Room';

    final dayRegex = RegExp(
      r'\b(Mon|Monday|Tue|Tuesday|Wed|Wednesday|Thu|Thur|Thursday|Fri|Friday|Sat|Saturday|Sun|Sunday)\b',
      caseSensitive: false,
    );
    final timeRegex = RegExp(
      r'(\d{1,2}:\d{2})\s*[-–—]\s*(\d{1,2}:\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    );
    
    // Pattern for rooms (e.g. CS-1, R-102, Lab-3, EE Room 5, A-101, B-2)
    final roomRegex = RegExp(
      r'(CS|EE|CE|SE|AI|DS|CY|R|Lab|Room|Auditorium|Classroom|[A-H])\s*[-–\s]?\s*\d{1,3}\b',
      caseSensitive: false,
    );

    final dateRegex = RegExp(
      r'(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Thur|Fri|Sat|Sun),\s*\d{1,2}\s+[A-Za-z]+,?\s*\d{4}',
      caseSensitive: false,
    );

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // 1. Detect Day/Date
      final dateMatches = dateRegex.allMatches(line).toList();
      if (dateMatches.isNotEmpty) {
        final firstDate = line.substring(dateMatches.first.start, dateMatches.first.end).trim();
        if (dateMatches.length > 1) {
          final secondDate = line.substring(dateMatches[1].start, dateMatches[1].end).trim();
          // Swap: secondDate (Rechecking Date) is primary, firstDate (Exam Date) is secondary
          currentDay = '$secondDate|$firstDate';
        } else {
          currentDay = firstDate;
        }
      } else {
        final dayMatch = dayRegex.firstMatch(line);
        if (dayMatch != null) {
          final matchedStr = dayMatch.group(1)!.toLowerCase();
          if (matchedStr.startsWith('mon')) {
            currentDay = 'Monday';
          } else if (matchedStr.startsWith('tue')) {
            currentDay = 'Tuesday';
          } else if (matchedStr.startsWith('wed')) {
            currentDay = 'Wednesday';
          } else if (matchedStr.startsWith('thu')) {
            currentDay = 'Thursday';
          } else if (matchedStr.startsWith('fri')) {
            currentDay = 'Friday';
          } else if (matchedStr.startsWith('sat')) {
            currentDay = 'Saturday';
          } else if (matchedStr.startsWith('sun')) {
            currentDay = 'Sunday';
          }
        }
      }

      // 2. Detect Time
      final timeMatch = timeRegex.firstMatch(line);
      if (timeMatch != null) {
        final startHour = timeMatch.group(1)!;
        final endHour = timeMatch.group(2)!;
        final ampm = timeMatch.group(3) ?? '';
        
        // Normalize time slot format to HH:mm-HH:mm
        String normalizeTimeStr(String t) {
          final parts = t.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (h != null && m != null) {
              return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
            }
          }
          return t;
        }
        final startNormal = normalizeTimeStr(startHour);
        final endNormal = normalizeTimeStr(endHour);
        currentTime = ampm.isNotEmpty ? '$startNormal-$endNormal $ampm' : '$startNormal-$endNormal';
      }

      // 3. Detect Room
      final roomMatches = roomRegex.allMatches(line).toList();
      if (roomMatches.isNotEmpty) {
        final lastMatch = roomMatches.last;
        currentRoom = line.substring(lastMatch.start, lastMatch.end).trim();
      }

      // 4. Match registered courses
      for (final course in registeredCourses) {
        final codeNormalized = course.code.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        final lineNormalized = line.replaceAll('-', '').replaceAll(' ', '').toLowerCase();

        final matchesCode = codeNormalized.isNotEmpty && lineNormalized.contains(codeNormalized);
        final matchesName = course.courseName.isNotEmpty && line.toLowerCase().contains(course.courseName.toLowerCase());

        if (matchesCode || matchesName) {
          final section = course.section.trim();
          bool matchesSection = false;
          String extractedTeacher = 'Staff';

          if (section.isNotEmpty) {
            // Map BCS -> CS, BSE -> SE, etc.
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

            // Parse student section components, e.g. BSE-6B -> BSE, 6, B
            final studentSectionRegex = RegExp(r'^([A-Za-z]+)-?([0-9]+)([A-Za-z]*)$');
            final studentMatch = studentSectionRegex.firstMatch(section);

            if (studentMatch != null) {
              final studentDept = studentMatch.group(1)!.toUpperCase();
              final studentSem = studentMatch.group(2)!;
              final studentLetter = studentMatch.group(3)!.toUpperCase();
              final studentCanonicalDept = deptMapping[studentDept] ?? studentDept;

              // Find any section patterns in the line (e.g. CS-6B, Lab-6B, 6B)
              // Note: Removed the leading \b to allow merged matches
              final sectionInLineRegex = RegExp(
                r'(BCS|BSE|BAI|BDS|BSD|BCY|BBA|BFT|MCS|MS|PHD|BS|CS|SE|AI|DS|CY|BA|FT|Lab)?\s*[-–—_]?\s*([0-9]+)\s*[-–—_]?\s*([A-Za-z]+)\b',
                caseSensitive: false,
              );
              final matchesInLine = sectionInLineRegex.allMatches(line);

              if (matchesInLine.isEmpty) {
                // Fallback if no sections are explicitly mentioned in the line but it matched the course,
                // we check if the single letter matches
                if (studentLetter.isNotEmpty) {
                  final wordRegex = RegExp(r'\b' + studentLetter + r'\b|[\(\-\s]' + studentLetter + r'[\)\-\s]', caseSensitive: false);
                  matchesSection = wordRegex.hasMatch(line);
                } else {
                  matchesSection = true;
                }
              } else {
                for (final m in matchesInLine) {
                  final lineDeptRaw = m.group(1);
                  final lineSem = m.group(2);
                  final lineLetter = m.group(3)!.toUpperCase();

                  if (lineSem == studentSem && _matchesMergedLetter(lineLetter, studentLetter)) {
                    if (lineDeptRaw == null || lineDeptRaw.isEmpty || lineDeptRaw.toLowerCase() == 'lab') {
                      matchesSection = true;
                    } else {
                      final lineDept = lineDeptRaw.toUpperCase();
                      final lineCanonicalDept = deptMapping[lineDept] ?? lineDept;
                      if (lineCanonicalDept == studentCanonicalDept) {
                        matchesSection = true;
                      }
                    }

                    if (matchesSection) {
                      // Dynamically extract teacher name between the end of section match and start of first date
                      if (dateMatches.isNotEmpty) {
                        final dateStartIdx = dateMatches.first.start;
                        final matchEndIdx = m.end;
                        if (matchEndIdx <= dateStartIdx) {
                          final suffix = line.substring(matchEndIdx, dateStartIdx).trim();
                          final prefix = lineLetter.substring(studentLetter.length).trim();
                          extractedTeacher = '$prefix $suffix'.trim();
                          if (extractedTeacher.isEmpty) {
                            extractedTeacher = 'Staff';
                          }
                        }
                      }
                      break;
                    }
                  }
                }
              }
            } else {
              // Fallback for sections without standard formats, e.g. single letters or special sections
              final cleanLine = line.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
              final cleanSection = section.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
              if (cleanLine.contains(cleanSection)) {
                matchesSection = true;
              } else {
                final wordRegex = RegExp(r'\b' + RegExp.escape(section) + r'\b', caseSensitive: false);
                matchesSection = wordRegex.hasMatch(line);
              }
            }
          } else {
            matchesSection = true;
          }

          if (matchesSection) {
            final event = TimetableDayEvent(
              day: currentDay,
              time: currentTime,
              room: currentRoom,
              section: section.isNotEmpty ? section : 'All',
              originalSection: section,
              course: course.courseName,
              teacher: extractedTeacher,
              degree: 'bachelors',
            );

            final isDuplicate = events.any(
              (e) => e.day == event.day && e.time == event.time && e.course == event.course && e.room == event.room,
            );
            if (!isDuplicate) {
              events.add(event);
            }
          }
        }
      }
    }

    return events;
  }
}
