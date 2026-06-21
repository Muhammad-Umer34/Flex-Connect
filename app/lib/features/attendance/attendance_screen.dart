import 'package:flutter/material.dart';

import '../../models/attendance_models.dart';
import '../../services/attendance_storage.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  AttendanceScreenState createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> {
  AttendanceSnapshot? _snapshot;
  bool _isLoading = true;
  int? _expandedCourseIndex;

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> reload() => _loadAttendance();

  Future<void> _loadAttendance() async {
    final snapshot = await AttendanceStorage.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = snapshot;
      _isLoading = false;
      if (_expandedCourseIndex != null &&
          (_snapshot?.courses.length ?? 0) <= _expandedCourseIndex!) {
        _expandedCourseIndex = null;
      }
    });
  }

  void _toggleCourse(int index) {
    setState(() {
      _expandedCourseIndex = _expandedCourseIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAttendance,
                color: _accent,
                child: _snapshot == null || _snapshot!.courses.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        children: const [
                          SizedBox(height: 80),
                          _EmptyAttendanceState(),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAcademicAttendanceHeader(context),
                            const SizedBox(height: 48),
                            _buildTitleSection(context),
                            const SizedBox(height: 36),
                            _buildStatsSection(context),
                            const SizedBox(height: 32),
                            if (_snapshot!.coursesInDanger.isNotEmpty) ...[
                              _DangerCoursesBanner(
                                courses: _snapshot!.coursesInDanger,
                              ),
                              const SizedBox(height: 32),
                            ],
                            _buildCoursesList(context),
                          ],
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildAcademicAttendanceHeader(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
          ),
          child: const Icon(
            Icons.event_available_outlined,
            color: _accent,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Academic Attendance',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final semesterName = _snapshot?.semester?.name ?? 'Semester';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Record',
          style: TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${semesterName.toUpperCase()} SEMESTER',
          style: const TextStyle(
            color: Color(0xFFB45309),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final coursesCount = _snapshot?.courses.length ?? 0;
    final totalLecturesCount = _snapshot?.totalLectures ?? 0;

    final dangerCount = _snapshot?.coursesInDanger.length ?? 0;
    final Color dangerColor = dangerCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DANGER COURSES',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$dangerCount',
              style: TextStyle(
                color: dangerColor,
                fontSize: 44,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 48),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SUBJECTS',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$coursesCount',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 44,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 48),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LECTURES',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$totalLecturesCount',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 44,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoursesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'SUBJECT NAME',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'ATTENDED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  'ABSENT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'PERCENT',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        const SizedBox(height: 16),
        for (var index = 0; index < _snapshot!.courses.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _CourseRow(
            course: _snapshot!.courses[index],
            isExpanded: _expandedCourseIndex == index,
            onTap: () => _toggleCourse(index),
          ),
        ],
      ],
    );
  }
}

class _DangerCoursesBanner extends StatelessWidget {
  const _DangerCoursesBanner({required this.courses});

  final List<AttendanceCourse> courses;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _alertAccent = Color(0xFFD97706);
  static const Color _alertBorder = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _alertBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _alertAccent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ATTENDANCE ALERT',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The following subjects require attention to maintain the minimum 80% attendance requirement:',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < courses.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    courses[i].displayTitle,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${courses[i].attendancePercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.isExpanded,
    required this.onTap,
  });

  final AttendanceCourse course;
  final bool isExpanded;
  final VoidCallback onTap;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _present = Color(0xFF10B981);
  static const Color _late = Color(0xFFF59E0B);
  static const Color _absent = Color(0xFFEF4444);
  static const Color _containerBg = Color(0xFFF8FAFC);
  static const Color _containerBorder = Color(0xFFF1F5F9);

  Color _accentForPercentage(double percentage) {
    if (percentage >= AttendanceRow.dangerThresholdPercent) {
      return _present;
    }
    if (percentage >= 60) {
      return _late;
    }
    return _absent;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForPercentage(course.attendancePercentage);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _containerBorder, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.displayTitle,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        if (course.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            course.subtitle!,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${course.attendedCount}/${course.totalLectures}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${course.absentCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${course.attendancePercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _muted,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: _containerBorder, height: 1),
            _LectureList(rows: course.rows),
          ],
        ],
      ),
    );
  }
}

class _LectureList extends StatelessWidget {
  const _LectureList({required this.rows});

  final List<AttendanceRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No lecture records for this course yet.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'LECTURE',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'DURATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  'STATUS',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),
            ],
            _LectureTile(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _LectureTile extends StatelessWidget {
  const _LectureTile({required this.row});

  final AttendanceRow row;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _present = Color(0xFF10B981);
  static const Color _late = Color(0xFFF59E0B);
  static const Color _absent = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final isPresent = row.isPresent;
    final isLate = row.isLate;
    final isAbsent = row.isAbsent;
    final statusColor = isPresent
        ? _present
        : isLate
        ? _late
        : isAbsent
        ? _absent
        : _muted;
    final statusLabel = row.statusLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lecture ${row.lectureNo}',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.date,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '${row.durationHours} hrs',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 130,
          child: Text(
            statusLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyAttendanceState extends StatelessWidget {
  const _EmptyAttendanceState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.event_available_outlined,
          size: 52,
          color: Color(0xFF6B7280),
        ),
        const SizedBox(height: 16),
        Text(
          'No attendance data captured yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Sync from the Home tab first so the attendance screen can load your latest subjects.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
        ),
      ],
    );
  }
}

