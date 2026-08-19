import 'package:flutter/material.dart';

import '../../models/transcript_models.dart';
import '../../services/transcript_storage.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => TranscriptScreenState();
}

class TranscriptScreenState extends State<TranscriptScreen> {
  TranscriptSnapshot? _snapshot;
  bool _isLoading = true;
  final Set<int> _expandedIndices = {};

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }

  Future<void> reload() => _loadTranscript();

  Future<void> _loadTranscript() async {
    final snapshot = await TranscriptStorage.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = snapshot;
      _isLoading = false;
      _expandedIndices.clear();
      if (snapshot != null && snapshot.semesters.isNotEmpty) {
        _expandedIndices.add(snapshot.semesters.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadTranscript,
                color: _accent,
                child: _snapshot == null || _snapshot!.semesters.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        children: const [
                          SizedBox(height: 80),
                          _EmptyTranscriptState(),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAcademicTranscriptHeader(context),
                            const SizedBox(height: 48),
                            _buildTitleSection(context),
                            const SizedBox(height: 36),
                            _buildStatsSection(context),
                            const SizedBox(height: 48),
                            _buildSemestersList(context),
                          ],
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildAcademicTranscriptHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE), width: 1),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: _accent,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Academic Transcript',
          style: TextStyle(
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final semestersCount = _snapshot?.semesters.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcript Record',
          style: TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$semestersCount SEMESTER BLOCKS',
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
    final semestersCount = _snapshot?.semesters.length ?? 0;
    final latestCgpa = _snapshot != null && _snapshot!.semesters.isNotEmpty
        ? _snapshot!.semesters.last.cgpa ?? '-'
        : '-';
    final totalCourses = _snapshot?.semesters.fold<int>(0, (sum, sem) => sum + sem.courses.length) ?? 0;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CUMULATIVE CGPA',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              latestCgpa,
              style: const TextStyle(
                color: _accent,
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
            Text(
              'SEMESTERS',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$semestersCount',
              style: TextStyle(
                color: _ink,
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
            Text(
              'TOTAL COURSES',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$totalCourses',
              style: TextStyle(
                color: _muted,
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

  Widget _buildSemestersList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _snapshot!.semesters.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _buildSemesterCardItem(index),
        ],
      ],
    );
  }

  Widget _buildSemesterCardItem(int index) {
    final reversedIndex = _snapshot!.semesters.length - 1 - index;
    final semester = _snapshot!.semesters[reversedIndex];
    return _SemesterTranscriptCard(
      semester: semester,
      isExpanded: _expandedIndices.contains(reversedIndex),
      onTap: () {
        setState(() {
          if (_expandedIndices.contains(reversedIndex)) {
            _expandedIndices.remove(reversedIndex);
          } else {
            _expandedIndices.add(reversedIndex);
          }
        });
      },
    );
  }
}

class _SemesterTranscriptCard extends StatelessWidget {
  const _SemesterTranscriptCard({
    required this.semester,
    required this.isExpanded,
    required this.onTap,
  });

  final TranscriptSemester semester;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final containerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: containerBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          semester.name.isNotEmpty ? semester.name : 'Semester',
                          style: TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        if (semester.stats.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (semester.sgpa != null) ...[
                                _buildMiniStat(ink, muted, 'SGPA', semester.sgpa!),
                                const SizedBox(width: 24),
                              ],
                              if (semester.cgpa != null) ...[
                                _buildMiniStat(ink, muted, 'CGPA', semester.cgpa!),
                                const SizedBox(width: 24),
                              ],
                              if (semester.creditsEarned != null) ...[
                                _buildMiniStat(ink, muted, 'CREDITS', semester.creditsEarned!),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(color: containerBorder, height: 1),
            Container(
              width: double.infinity,
              color: containerBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: semester.courses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No course rows were captured for this semester.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    )
                  : Column(
                      children: [
                        _TranscriptTableHeader(),
                        const SizedBox(height: 6),
                        Divider(color: dividerColor, height: 1),
                        const SizedBox(height: 10),
                        for (var index = 0; index < semester.courses.length; index++) ...[
                          if (index > 0) ...[
                            const SizedBox(height: 14),
                            Divider(color: dividerColor, height: 1),
                            const SizedBox(height: 14),
                          ],
                          _TranscriptCourseRow(
                            course: semester.courses[index],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(Color ink, Color muted, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '-',
          style: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TranscriptTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            'CODE',
            style: TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'COURSE NAME',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            'GRADE',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            'POINTS',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptCourseRow extends StatelessWidget {
  const _TranscriptCourseRow({required this.course});

  final TranscriptCourse course;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                course.code.isNotEmpty ? course.code : '-',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  course.courseName.isNotEmpty ? course.courseName : '-',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                course.grade.isNotEmpty ? course.grade : '-',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                course.points.isNotEmpty ? course.points : '-',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        if (course.section.isNotEmpty ||
            course.creditHours.isNotEmpty ||
            course.type.isNotEmpty ||
            course.remarks.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 70),
            child: Text(
              [
                if (course.section.isNotEmpty) 'Section ${course.section}',
                if (course.creditHours.isNotEmpty) '${course.creditHours} credit hrs',
                if (course.type.isNotEmpty) course.type,
                if (course.remarks.isNotEmpty) course.remarks,
              ].join('   •   '),
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyTranscriptState extends StatelessWidget {
  const _EmptyTranscriptState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 52,
          color: muted,
        ),
        const SizedBox(height: 16),
        Text(
          'No transcript data captured yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Open the university login sync again to capture the transcript page.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.4),
        ),
      ],
    );
  }
}
