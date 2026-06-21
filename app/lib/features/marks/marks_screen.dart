import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/marks_models.dart';
import '../../services/marks_storage.dart';

class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});

  @override
  MarksScreenState createState() => MarksScreenState();
}

class MarksScreenState extends State<MarksScreen> {
  MarksSnapshot? _snapshot;
  bool _isLoading = true;
  int? _expandedCourseIndex;
  int? _expandedSectionIndex;
  List<String> _highlightedCourses = [];

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  Future<void> reload() => _loadMarks();

  Future<void> _loadMarks() async {
    final snapshot = await MarksStorage.load();
    final prefs = await SharedPreferences.getInstance();
    final highlights = prefs.getStringList('flex_highlighted_courses') ?? [];
    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = snapshot;
      _highlightedCourses = highlights;
      _isLoading = false;
      if (_expandedCourseIndex != null &&
          (_snapshot?.courses.length ?? 0) <= _expandedCourseIndex!) {
        _expandedCourseIndex = null;
        _expandedSectionIndex = null;
      }
    });
    MarksStorage.highlightedCoursesNotifier.value = highlights;
  }

  void _toggleCourse(int index) async {
    final course = _snapshot?.courses[index];
    if (course != null && _highlightedCourses.contains(course.displayTitle)) {
      setState(() {
        _highlightedCourses.remove(course.displayTitle);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('flex_highlighted_courses', _highlightedCourses);
      MarksStorage.highlightedCoursesNotifier.value = List.from(_highlightedCourses);
    }

    setState(() {
      if (_expandedCourseIndex == index) {
        _expandedCourseIndex = null;
        _expandedSectionIndex = null;
      } else {
        _expandedCourseIndex = index;
        _expandedSectionIndex = null;
      }
    });
  }

  void _toggleSection(int index) {
    setState(() {
      _expandedSectionIndex = _expandedSectionIndex == index ? null : index;
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
                onRefresh: _loadMarks,
                color: _accent,
                child: _snapshot == null || _snapshot!.courses.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        children: const [
                          SizedBox(height: 80),
                          _EmptyMarksState(),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAcademicMarksHeader(context),
                            const SizedBox(height: 48),
                            _buildTitleSection(context),
                            const SizedBox(height: 36),
                            _buildStatsSection(context),
                            const SizedBox(height: 48),
                            _buildCoursesList(context),
                          ],
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildAcademicMarksHeader(BuildContext context) {
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
            Icons.bookmark_outline_rounded,
            color: _accent,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Academic Marks',
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
          'Marks Evaluation',
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
    
    double studentSum = 0.0;
    double classSum = 0.0;
    int evaluatedCoursesCount = 0;
    
    if (_snapshot != null) {
      for (final course in _snapshot!.courses) {
        final scores = course.weightedScore;
        final totalWeight = scores['totalWeight'] ?? 0.0;
        if (totalWeight > 0) {
          final obtained = scores['obtained'] ?? 0.0;
          final average = scores['average'] ?? 0.0;
          studentSum += (obtained / totalWeight) * 100;
          classSum += (average / totalWeight) * 100;
          evaluatedCoursesCount++;
        }
      }
    }

    final double averageEvaluation = evaluatedCoursesCount > 0
        ? studentSum / evaluatedCoursesCount
        : 0.0;
    final double classAvgPct = evaluatedCoursesCount > 0
        ? classSum / evaluatedCoursesCount
        : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                color: _accent,
                fontSize: 44,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 64),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AVERAGE SCORE',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              evaluatedCoursesCount > 0
                  ? '${averageEvaluation.toStringAsFixed(1)}%'
                  : '-',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 44,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
            if (evaluatedCoursesCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Class Average: ${classAvgPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
                width: 50,
                child: Text(
                  'WEIGHT',
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
                  'AVG',
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
                  'OBTAINED',
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
            isHighlighted: _highlightedCourses.contains(_snapshot!.courses[index].displayTitle),
            expandedSectionIndex:
                _expandedCourseIndex == index ? _expandedSectionIndex : null,
            onTap: () => _toggleCourse(index),
            onSectionTap: _toggleSection,
          ),
        ],
      ],
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.isExpanded,
    required this.isHighlighted,
    required this.expandedSectionIndex,
    required this.onTap,
    required this.onSectionTap,
  });

  final MarksCourse course;
  final bool isExpanded;
  final bool isHighlighted;
  final int? expandedSectionIndex;
  final VoidCallback onTap;
  final ValueChanged<int> onSectionTap;

  static const Color _accent = Color(0xFF2563EB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _containerBg = Color(0xFFF8FAFC);
  static const Color _containerBorder = Color(0xFFF1F5F9);

  String _formatScore(double value) {
    final formatted = value.toStringAsFixed(2);
    return formatted.endsWith('.00')
        ? formatted.substring(0, formatted.length - 3)
        : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final scores = course.weightedScore;
    final hasScores = scores['totalWeight']! > 0;

    final displayWeight = hasScores ? _formatScore(scores['totalWeight']!) : '-';
    final displayAvg = hasScores ? _formatScore(scores['average']!) : '-';
    final displayObtained = hasScores ? _formatScore(scores['obtained']!) : '-';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? Border.all(color: const Color(0xFFFCD34D), width: 1.2)
            : Border.all(color: _containerBorder, width: 1),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                            if (isHighlighted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Color(0xFFD97706),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                    width: 50,
                    child: Text(
                      displayWeight,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      displayAvg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
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
                          displayObtained,
                          style: const TextStyle(
                            color: _accent,
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
            _SectionsList(
              sections: course.sections,
              expandedSectionIndex: expandedSectionIndex,
              onSectionTap: onSectionTap,
              course: course,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionsList extends StatelessWidget {
  const _SectionsList({
    required this.sections,
    required this.expandedSectionIndex,
    required this.onSectionTap,
    required this.course,
  });

  final List<MarksSection> sections;
  final int? expandedSectionIndex;
  final ValueChanged<int> onSectionTap;
  final MarksCourse course;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No marks components found for this course.',
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
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _SectionCard(
              section: sections[i],
              isExpanded: expandedSectionIndex == i,
              onTap: () => onSectionTap(i),
              course: course,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.isExpanded,
    required this.onTap,
    required this.course,
  });

  final MarksSection section;
  final bool isExpanded;
  final VoidCallback onTap;
  final MarksCourse course;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _containerBorder = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final nameLower = section.sectionName.toLowerCase();
    final isGrandTotal = nameLower.contains('grand total') || nameLower.contains('grand_total');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _containerBorder, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.sectionName.isNotEmpty
                          ? section.sectionName.toUpperCase()
                          : 'SECTION',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    isGrandTotal ? '1 item' : '${section.rows.length} items',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
          ),
          if (isExpanded) ...[
            const Divider(color: _containerBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'ITEM NAME',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          'WEIGHT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          'AVG',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'OBTAINED',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: _containerBorder, height: 1),
                  const SizedBox(height: 8),
                  if (isGrandTotal) ...[
                    _MarkRowTile(
                      row: MarksRow(
                        itemNo: '',
                        weightage: course.weightedScore['totalWeight']!.toStringAsFixed(1),
                        obtained: course.weightedScore['obtained']!.toStringAsFixed(2),
                        total: '100',
                        average: course.weightedScore['average']!.toStringAsFixed(2),
                        stdDev: '',
                        minimum: '',
                        maximum: '',
                      ),
                      itemLabel: 'Calculated Total',
                      isGrandTotal: true,
                    ),
                  ] else if (section.rows.isNotEmpty) ...[
                    for (var i = 0; i < section.rows.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(height: 10),
                        const Divider(color: _containerBorder, height: 1),
                        const SizedBox(height: 10),
                      ],
                      _MarkRowTile(
                        row: section.rows[i],
                        itemLabel: section.itemLabel,
                        isDropped: section.isRowDropped(section.rows[i]),
                      ),
                    ],
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No marks recorded yet.',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
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
}

class _MarkRowTile extends StatelessWidget {
  const _MarkRowTile({
    required this.row,
    required this.itemLabel,
    this.isDropped = false,
    this.isGrandTotal = false,
  });

  final MarksRow row;
  final String itemLabel;
  final bool isDropped;
  final bool isGrandTotal;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final hasMinMax =
        row.minimum.isNotEmpty || row.maximum.isNotEmpty || row.stdDev.isNotEmpty;
    final isTotal = row.itemNo.trim().isEmpty && !isGrandTotal;

    final textStyle = TextStyle(
      color: isDropped ? _muted : _ink,
      fontWeight: (isTotal || isGrandTotal) ? FontWeight.bold : FontWeight.w600,
      fontSize: 13,
      decoration: isDropped ? TextDecoration.lineThrough : null,
    );

    final valueStyle = TextStyle(
      color: isDropped ? _muted : _ink,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      decoration: isDropped ? TextDecoration.lineThrough : null,
    );

    final obtainedStyle = TextStyle(
      color: isDropped ? _muted : ((isTotal || isGrandTotal) ? _ink : _accent),
      fontWeight: FontWeight.bold,
      fontSize: 13,
      decoration: isDropped ? TextDecoration.lineThrough : null,
    );

    String displayLabel;
    if (isGrandTotal) {
      displayLabel = 'Calculated Total';
    } else if (isTotal) {
      displayLabel = 'Total';
    } else {
      displayLabel = '$itemLabel ${row.itemNo}';
    }

    String displayWeight;
    if (isGrandTotal) {
      displayWeight = row.weightage.isNotEmpty ? '${row.weightage}%' : '-';
    } else if (isTotal) {
      displayWeight = '-';
    } else {
      displayWeight = row.weightage.isNotEmpty ? '${row.weightage}%' : '-';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Text(
                    displayLabel,
                    style: textStyle,
                  ),
                  if (isDropped) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DROPPED',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                displayWeight,
                textAlign: TextAlign.center,
                style: valueStyle,
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                row.average.isNotEmpty ? row.average : '-',
                textAlign: TextAlign.center,
                style: valueStyle,
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                (isTotal || isGrandTotal)
                    ? (row.total.isNotEmpty ? '${row.obtained} / ${row.total}' : row.obtained)
                    : '${row.obtained} / ${row.total}',
                textAlign: TextAlign.right,
                style: obtainedStyle,
              ),
            ),
          ],
        ),
        if (hasMinMax && !isDropped) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Min: ${row.minimum.isNotEmpty ? row.minimum : "-"}   •   Max: ${row.maximum.isNotEmpty ? row.maximum : "-"}   •   Std Dev: ${row.stdDev.isNotEmpty ? row.stdDev : "-"}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EmptyMarksState extends StatelessWidget {
  const _EmptyMarksState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.grading_outlined,
          size: 52,
          color: Color(0xFF6B7280),
        ),
        const SizedBox(height: 16),
        Text(
          'No marks data captured yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Sync from the Home tab first so the marks screen can load your latest subjects.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
        ),
      ],
    );
  }
}
