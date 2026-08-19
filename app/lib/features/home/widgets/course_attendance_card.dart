import 'package:flutter/material.dart';
import '../../../models/attendance_models.dart';
import '../../../models/marks_models.dart';
import '../../../models/course_bunk_status.dart';

class CourseAttendanceCard extends StatelessWidget {
  const CourseAttendanceCard({
    super.key,
    required this.course,
    this.marksCourse,
  });

  final AttendanceCourse course;
  final MarksCourse? marksCourse;

  static const Color _present = Color(0xFF10B981);
  static const Color _late = Color(0xFFF59E0B);
  static const Color _absent = Color(0xFFEF4444);
  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final Color containerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final status = CourseBunkStatus.calculate(course);
    final percentage = status.percentage;

    final Color statusColor;
    final IconData statusIcon;
    final String statusMessage;

    if (course.totalLectures == 0) {
      statusColor = _accent;
      statusIcon = Icons.info_outline;
      statusMessage = 'No lectures captured yet';
    } else if (status.isBelow80) {
      statusColor = _absent;
      statusIcon = Icons.warning_amber_rounded;
      statusMessage = 'Attend next ${status.minConsecutiveToAttend} classes to recover';
    } else if (status.maxMissable == 0) {
      statusColor = _late;
      statusIcon = Icons.error_outline_rounded;
      statusMessage = 'Do not miss next class';
    } else {
      statusColor = _present;
      statusIcon = Icons.check_circle_outline_rounded;
      statusMessage = 'You can miss ${status.maxMissable} class${status.maxMissable == 1 ? '' : 'es'}';
    }

    final marksInfo = marksCourse?.weightedScore;
    final obtainedMarks = marksInfo?['obtained'] ?? 0.0;
    final totalWeightage = marksInfo?['totalWeight'] ?? 0.0;
    final hasMarks = totalWeightage > 0.0;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.displayTitle,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.subtitle!,
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Text(
                  course.totalLectures == 0 ? '—' : '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                     color: statusColor,
                     fontWeight: FontWeight.bold,
                     fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: course.totalLectures > 0 ? (course.attendedCount / course.totalLectures) : 0.0,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASSES ATTENDED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course.attendedCount} / ${course.totalLectures}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'P: ${course.presentCount} | L: ${course.lateCount} | A: ${course.absentCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OBTAINED MARKS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasMarks
                          ? '${obtainedMarks.toStringAsFixed(1)} / ${totalWeightage.toStringAsFixed(1)}'
                          : '—',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasMarks
                          ? 'Weightage: ${(obtainedMarks / totalWeightage * 100).toStringAsFixed(1)}%'
                          : 'No marks uploaded yet',
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
          ),
          const SizedBox(height: 12),
          Divider(color: containerBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMessage,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
