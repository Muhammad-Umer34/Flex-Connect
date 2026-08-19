import 'package:flutter/material.dart';
import '../../../models/timetable_models.dart';
import '../utils/timetable_utils.dart';

class TimetableGridView extends StatelessWidget {
  const TimetableGridView({
    super.key,
    required this.customEvents,
    required this.gridBoundaryKey,
    required this.selectedSection,
    required this.snapshot,
    required this.onExportGridToGallery,
    required this.onEventPressed,
  });

  final List<TimetableDayEvent> customEvents;
  final GlobalKey gridBoundaryKey;
  final String? selectedSection;
  final TimetableSnapshot? snapshot;
  final VoidCallback onExportGridToGallery;
  final ValueChanged<TimetableDayEvent> onEventPressed;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFF2563EB);

  List<int> _getEventBlockIndices(TimetableDayEvent event) {
    final blockTimes = [
      "08:30-10:00",
      "10:00-11:30",
      "11:30-13:00",
      "13:00-14:30",
      "14:30-16:00",
      "16:00-17:30",
      "17:30-19:00",
      "19:00-20:30"
    ];

    try {
      final parts = event.time.split('-');
      if (parts.length != 2) return [0];
      final start = parts[0].trim();
      final end = parts[1].trim();

      int startIndex = -1;
      int endIndex = -1;

      for (int i = 0; i < blockTimes.length; i++) {
        final bParts = blockTimes[i].split('-');
        if (bParts[0].trim() == start) {
          startIndex = i;
        }
        if (bParts[1].trim() == end) {
          endIndex = i;
        }
      }

      if (startIndex == -1) {
        startIndex = 0;
        int minDiff = 9999;
        for (int i = 0; i < blockTimes.length; i++) {
          final bStart = blockTimes[i].split('-')[0].trim();
          final diff = _diffInMinutes(start, bStart);
          if (diff < minDiff) {
            minDiff = diff;
            startIndex = i;
          }
        }
      }

      if (endIndex == -1) {
        endIndex = startIndex;
        int minDiff = 9999;
        for (int i = 0; i < blockTimes.length; i++) {
          final bEnd = blockTimes[i].split('-')[1].trim();
          final diff = _diffInMinutes(end, bEnd);
          if (diff < minDiff) {
            minDiff = diff;
            endIndex = i;
          }
        }
      }

      final List<int> indices = [];
      for (int i = startIndex; i <= endIndex; i++) {
        indices.add(i);
      }
      return indices;
    } catch (_) {
      return [0];
    }
  }

  int _diffInMinutes(String t1, String t2) {
    try {
      final p1 = t1.split(':');
      final p2 = t2.split(':');
      int h1 = int.parse(p1[0]);
      int m1 = int.parse(p1[1].replaceAll(RegExp(r'[^0-9]'), ''));
      int h2 = int.parse(p2[0]);
      int m2 = int.parse(p2[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (h1 < 8) h1 += 12;
      if (h2 < 8) h2 += 12;
      return ((h1 * 60 + m1) - (h2 * 60 + m2)).abs();
    } catch (_) {
      return 9999;
    }
  }

  Widget _buildGridCell(List<TimetableDayEvent> cellEvents) {
    if (cellEvents.isEmpty) {
      return const SizedBox(
        height: 75,
      );
    }

    final hasClash = cellEvents.length > 1;

    return Container(
      height: 75,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: hasClash ? Colors.red.withValues(alpha: 0.08) : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasClash) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 9, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'CLASH',
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
          ],
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cellEvents.length,
              itemBuilder: (context, index) {
                final event = cellEvents[index];
                final deptColor = getDeptColor(event.section.split('-')[0]);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: GestureDetector(
                    onTap: () => onEventPressed(event),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: deptColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasClash ? Colors.red.withValues(alpha: 0.6) : deptColor.withValues(alpha: 0.3),
                          width: hasClash ? 1.2 : 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.course,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: deptColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Icon(Icons.room, size: 8, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  event.room,
                                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.school, size: 8, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  event.section,
                                  style: const TextStyle(fontSize: 7, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockTimes = [
      "08:30-10:00",
      "10:00-11:30",
      "11:30-13:00",
      "13:00-14:30",
      "14:30-16:00",
      "16:00-17:30",
      "17:30-19:00",
      "19:00-20:30"
    ];

    // Determine what columns to show dynamically based on selections
    int maxActiveBlock = 4; // default to show up to 16:00
    for (final event in customEvents) {
      final blocks = _getEventBlockIndices(event);
      for (final b in blocks) {
        if (b > maxActiveBlock && b < blockTimes.length) {
          maxActiveBlock = b;
        }
      }
    }

    final columnsToShow = List.generate(maxActiveBlock + 1, (i) => i);
    final daysToShow = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final hasSunday = customEvents.any((e) => e.day.toLowerCase() == 'sunday');
    if (hasSunday) {
      daysToShow.add('Sunday');
    }

    if (customEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text(
                'Timetable is Empty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _muted),
              ),
              const SizedBox(height: 4),
              const Text(
                'Go to "Customize & Search" tab to add classes.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Schedule Grid',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
                  ),
                  Text(
                    'Scroll horizontally to see all periods. Tap any class to view details.',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: _accent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onExportGridToGallery,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Save to Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: RepaintBoundary(
              key: gridBoundaryKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FLEX CONNECT',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'WEEKLY ACADEMIC TIMETABLE',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 48),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'SECTION: ${selectedSection ?? "N/A"}',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Campus: ${snapshot?.campus ?? "N/A"}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Table(
                          defaultColumnWidth: const FixedColumnWidth(140),
                          border: TableBorder.all(
                            color: const Color(0xFFF1F5F9),
                            width: 0.8,
                          ),
                          children: [
                            // Header Row
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                              ),
                              children: [
                                const TableCell(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    child: Center(
                                      child: Text(
                                        'Day',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _ink),
                                      ),
                                    ),
                                  ),
                                ),
                                ...columnsToShow.map((idx) {
                                  return TableCell(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              'Period ${idx + 1}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _ink),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              blockTimes[idx],
                                              style: const TextStyle(fontSize: 9, color: _muted, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                            // Day Rows
                            ...daysToShow.map((day) {
                              return TableRow(
                                children: [
                                  TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                                      color: const Color(0xFFF8FAFC),
                                      child: Center(
                                        child: Text(
                                          day.substring(0, 3).toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _ink),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...columnsToShow.map((blockIdx) {
                                    final cellEvents = customEvents.where((e) {
                                      final isMatchingDay = e.day.toLowerCase() == day.toLowerCase();
                                      if (!isMatchingDay) return false;
                                      final blocks = _getEventBlockIndices(e);
                                      return blocks.contains(blockIdx);
                                    }).toList();

                                    return TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: _buildGridCell(cellEvents),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
