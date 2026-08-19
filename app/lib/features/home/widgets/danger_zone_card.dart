import 'package:flutter/material.dart';
import '../../../models/attendance_models.dart';
import '../../../models/course_bunk_status.dart';

class DangerZoneCard extends StatelessWidget {
  const DangerZoneCard({
    super.key,
    required this.attendanceCourses,
    required this.hasTranscriptData,
    required this.hasMarksData,
  });

  final List<AttendanceCourse> attendanceCourses;
  final bool hasTranscriptData;
  final bool hasMarksData;

  Widget _buildDangerItem(String title, String subtitle, Color color, IconData icon, Color ink, Color muted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final Color containerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final List<Widget> riskItems = [];

    // Check attendance courses risks
    for (final course in attendanceCourses) {
      final status = CourseBunkStatus.calculate(course);
      final percentage = status.percentage;

      if (course.totalLectures > 0) {
        if (status.isBelow80) {
          riskItems.add(_buildDangerItem(
            '${course.displayTitle}: attendance is ${percentage.toStringAsFixed(1)}%',
            'Attend next ${status.minConsecutiveToAttend} classes to recover',
            const Color(0xFFEF4444),
            Icons.warning_amber_rounded,
            ink,
            muted,
          ));
        } else if (status.maxMissable == 0) {
          riskItems.add(_buildDangerItem(
            '${course.displayTitle}: attendance is ${percentage.toStringAsFixed(1)}%',
            'Do not miss next class',
            const Color(0xFFF59E0B),
            Icons.error_outline_rounded,
            ink,
            muted,
          ));
        } else if (percentage >= 80 && percentage < 85) {
          riskItems.add(_buildDangerItem(
            '${course.displayTitle}: attendance is ${percentage.toStringAsFixed(1)}%',
            'Near danger threshold (can miss ${status.maxMissable} class${status.maxMissable == 1 ? '' : 'es'})',
            const Color(0xFFD97706),
            Icons.info_outline,
            ink,
            muted,
          ));
        }
      }
    }

    // Check missing transcript data
    if (!hasTranscriptData) {
      riskItems.add(_buildDangerItem(
        'Missing Transcript Data',
        'Sync using credentials to view latest CGPA/SGPA',
        const Color(0xFFEF4444),
        Icons.receipt_long_outlined,
        ink,
        muted,
      ));
    }

    // Check missing marks data
    if (!hasMarksData) {
      riskItems.add(_buildDangerItem(
        'Missing Marks Data',
        'Sync using credentials to view course marks',
        const Color(0xFFEF4444),
        Icons.grading_outlined,
        ink,
        muted,
      ));
    }

    final isClear = riskItems.isEmpty;

    if (isClear) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: containerBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Academic Status: Safe & Verified',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: containerBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_outlined, color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              Text(
                'DANGER ZONE',
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${riskItems.length} alert${riskItems.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: riskItems.length,
            separatorBuilder: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 1),
            ),
            itemBuilder: (context, index) => riskItems[index],
          ),
        ],
      ),
    );
  }
}
