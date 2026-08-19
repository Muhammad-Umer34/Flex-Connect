import 'package:flutter/material.dart';
import '../../timetable/timetable_screen.dart';
import '../../more/free_room_finder_screen.dart';
import '../../more/datesheet_screen.dart';
import '../../more/absolute_grading_calculator_screen.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final actions = [
      _QuickActionItem(
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
        title: 'Timetable',
        subtitle: 'Class schedule',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimetableScreen()),
          );
        },
      ),
      _QuickActionItem(
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF10B981),
        title: 'Free Rooms',
        subtitle: 'Study spaces',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FreeRoomFinderScreen()),
          );
        },
      ),
      _QuickActionItem(
        icon: Icons.event_note_rounded,
        color: const Color(0xFF8B5CF6),
        title: 'Datesheet',
        subtitle: 'Exam schedule',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DatesheetScreen()),
          );
        },
      ),
      _QuickActionItem(
        icon: Icons.calculate_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Grading Tool',
        subtitle: 'GPA calculator',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AbsoluteGradingCalculatorScreen()),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: inkColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: TextStyle(
                color: inkColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final item = actions[index];
            return Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.icon, color: item.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: inkColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
