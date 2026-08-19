import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/marks_models.dart';
import '../../models/marks_changelog.dart';
import '../../services/marks_storage.dart';
import '../../services/marks_changelog_storage.dart';
import '../../utils/grading_utils.dart';

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
  bool _showPlanner = false;
  Map<String, String> _targetGrades = {};
  Map<String, String> _gradingSchemes = {};
  Map<String, int> _courseMcas = {};

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

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

    final targetGrades = <String, String>{};
    final gradingSchemes = <String, String>{};
    final courseMcas = <String, int>{};

    if (snapshot != null) {
      for (final course in snapshot.courses) {
        final code = course.courseCode.isNotEmpty ? course.courseCode : course.paneId;
        targetGrades[code] = prefs.getString('flex_target_grade_$code') ?? 'A';
        gradingSchemes[code] = prefs.getString('flex_grading_scheme_$code') ?? 'absolute';

        final scores = course.weightedScore;
        final totalWeight = scores['totalWeight'] ?? 0.0;
        final average = scores['average'] ?? 0.0;
        int autoPredictedMca = 60;
        if (totalWeight > 0) {
          autoPredictedMca = ((average / totalWeight) * 100).round().clamp(30, 91);
        }
        courseMcas[code] = prefs.getInt('flex_grading_mca_$code') ?? autoPredictedMca;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = snapshot;
      _highlightedCourses = highlights;
      _targetGrades = targetGrades;
      _gradingSchemes = gradingSchemes;
      _courseMcas = courseMcas;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            _buildTabControls(context),
                            const SizedBox(height: 24),
                            _showPlanner
                                ? _buildGradePlanner(context)
                                : _buildCoursesList(context),
                          ],
                        ),
                      ),
              ),
      ),
    );
  }

  Future<void> _updateTargetGrade(String code, String grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flex_target_grade_$code', grade);
    setState(() {
      _targetGrades[code] = grade;
    });
  }

  Future<void> _updateGradingScheme(String code, String scheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flex_grading_scheme_$code', scheme);
    setState(() {
      _gradingSchemes[code] = scheme;
    });
  }

  Future<void> _updateCourseMca(String code, int mca) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flex_grading_mca_$code', mca);
    setState(() {
      _courseMcas[code] = mca;
    });
  }

  Widget _buildTabControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showPlanner = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_showPlanner
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: !_showPlanner
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Evaluations',
                  style: TextStyle(
                    color: !_showPlanner
                        ? (isDark ? Colors.white : _ink)
                        : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showPlanner = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _showPlanner
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _showPlanner
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Grade Planner',
                  style: TextStyle(
                    color: _showPlanner
                        ? (isDark ? Colors.white : _ink)
                        : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradePlanner(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _snapshot!.courses.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _buildPlannerCard(_snapshot!.courses[index]),
        ],
      ],
    );
  }

  Widget _buildPlannerCard(MarksCourse course) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color dropdownBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color dropdownBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final code = course.courseCode.isNotEmpty ? course.courseCode : course.paneId;
    final targetGrade = _targetGrades[code] ?? 'A';
    final scheme = _gradingSchemes[code] ?? 'absolute';
    final isAbsolute = scheme == 'absolute';
    final mca = _courseMcas[code] ?? 60;

    final scores = course.weightedScore;
    final double obtained = scores['obtained'] ?? 0.0;
    final double totalWeight = scores['totalWeight'] ?? 0.0;
    final double remainingWeight = 100.0 - totalWeight;

    final double targetScore = GradingUtils.getMinThreshold(targetGrade, isAbsolute, mca);
    final double requiredPercentage = remainingWeight > 0 ? ((targetScore - obtained) / remainingWeight) * 100 : 0.0;
    final double maxPossibleScore = obtained + remainingWeight;

    final String maxGrade = isAbsolute
        ? GradingUtils.calculateAbsoluteGrade(maxPossibleScore)
        : GradingUtils.calculateRelativeGrade(maxPossibleScore, mca);

    final double predictedScore = totalWeight > 0 ? (obtained / totalWeight) * 100 : 0.0;
    final String predictedGrade = totalWeight > 0
        ? (isAbsolute
            ? GradingUtils.calculateAbsoluteGrade(predictedScore)
            : GradingUtils.calculateRelativeGrade(predictedScore, mca))
        : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.displayTitle,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (course.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${obtained.toStringAsFixed(1)} / ${totalWeight.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OBTAINED SO FAR',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRADING CRITERIA',
                      style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: dropdownBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dropdownBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: scheme,
                          isExpanded: true,
                          style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
                          dropdownColor: dropdownBg,
                          items: const [
                            DropdownMenuItem(value: 'absolute', child: Text('Absolute')),
                            DropdownMenuItem(value: 'relative', child: Text('Relative')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              _updateGradingScheme(code, val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAbsolute) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEAN CLASS AVG (MCA)',
                        style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: dropdownBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: dropdownBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: mca,
                            isExpanded: true,
                            style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
                            dropdownColor: dropdownBg,
                            items: List.generate(62, (idx) {
                              final val = 30 + idx;
                              return DropdownMenuItem(
                                value: val,
                                child: Text('$val%'),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                _updateCourseMca(code, val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TARGET GRADE',
                      style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: dropdownBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dropdownBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: targetGrade,
                          isExpanded: true,
                          style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
                          dropdownColor: dropdownBg,
                          items: const [
                            'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D'
                          ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _updateTargetGrade(code, val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUIRED IN FINALS',
                      style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: remainingWeight <= 0
                            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                            : (requiredPercentage <= 0
                                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                : (requiredPercentage > 100
                                    ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                                    : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF)))),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        remainingWeight <= 0
                            ? 'Closed'
                            : (requiredPercentage <= 0
                                ? 'Guaranteed'
                                : (requiredPercentage > 100
                                    ? 'Impossible'
                                    : '${requiredPercentage.toStringAsFixed(1)}%')),
                        style: TextStyle(
                          color: remainingWeight <= 0
                              ? (isDark ? const Color(0xFF94A3B8) : Colors.grey[600])
                              : (requiredPercentage <= 0
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                  : (requiredPercentage > 100
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                      : (isDark ? const Color(0xFF60A5FA) : _accent))),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildGradeBadge('MAX GRADE', maxGrade),
              const SizedBox(width: 8),
              _buildGradeBadge('PREDICTED', predictedGrade),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(String label, String grade) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color badgeColor = isDark ? const Color(0xFF334155) : Colors.grey[100]!;
    Color textColor = isDark ? const Color(0xFF94A3B8) : Colors.grey[700]!;

    if (grade != '—' && grade != 'Invalid') {
      if (grade.startsWith('A')) {
        badgeColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
        textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);
      } else if (grade.startsWith('B')) {
        badgeColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
        textColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF);
      } else if (grade.startsWith('C')) {
        badgeColor = isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF);
        textColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF3730A3);
      } else if (grade.startsWith('D')) {
        badgeColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
        textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
      } else {
        badgeColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      }
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              grade,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicMarksHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
                Icons.bookmark_outline_rounded,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Academic Marks',
              style: TextStyle(
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Marks Changelog',
          icon: Icon(
            Icons.history_rounded,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          onPressed: () => _showChangelogBottomSheet(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final semesterName = _snapshot?.semester?.name ?? 'Semester';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
            Text(
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
            Text(
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
              style: TextStyle(
                color: _ink,
                fontSize: 44,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
            if (evaluatedCoursesCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Class Average: ${classAvgPct.toStringAsFixed(1)}%',
                style: TextStyle(
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
            children: [
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
        Divider(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE5E7EB),
          height: 1,
        ),
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

  Future<void> _showChangelogBottomSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initialLogs = await MarksChangelogStorage.load();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<List<MarksChangelogEntry>>(
              future: MarksChangelogStorage.load(),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? initialLogs;
                final bool isEmpty = logs.isEmpty;

                return DraggableScrollableSheet(
                  initialChildSize: 0.6,
                  minChildSize: 0.4,
                  maxChildSize: 0.85,
                  expand: false,
                  builder: (context, scrollController) {
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active_outlined,
                                      color: _accent,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Marks Changelog',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isEmpty)
                                IconButton(
                                  tooltip: 'Clear History',
                                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 20),
                                  onPressed: () => _confirmClearChangelog(sheetContext, setSheetState),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        ),
                        Expanded(
                          child: isEmpty
                              ? _buildEmptyChangelogState(isDark)
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) {
                                    final entry = logs[index];
                                    return _buildChangelogItem(entry, isDark);
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyChangelogState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No marks changes yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Flex Connect automatically logs modifications or additions to your scores whenever you sync.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogItem(MarksChangelogEntry entry, bool isDark) {
    final bool isUpdate = entry.changeType == 'updated';
    final Color badgeBgColor = isUpdate
        ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7))
        : (isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFD1FAE5));
    final Color badgeTextColor = isUpdate
        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
        : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));

    final String badgeText = isUpdate ? 'Updated' : 'New Mark';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.itemNo,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.courseTitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isUpdate ? Icons.trending_up_rounded : Icons.add_circle_outline_rounded,
                size: 14,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                    children: [
                      if (isUpdate) ...[
                        TextSpan(
                          text: '${entry.oldObtained} ',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const TextSpan(text: '➔ '),
                      ],
                      TextSpan(
                        text: '${entry.newObtained} / ${entry.total}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF60A5FA) : _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _formatLogTimestamp(entry.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLogTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1 && time.day == now.day) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute';
    } else if (diff.inDays < 2 && time.day == now.subtract(const Duration(days: 1)).day) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return 'Yesterday, $hour:$minute';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[time.month - 1];
      final day = time.day;
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$month $day, $hour:$minute';
    }
  }

  Future<void> _confirmClearChangelog(BuildContext sheetContext, StateSetter setSheetState) async {
    final theme = Theme.of(sheetContext);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: sheetContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Clear Changelog', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to clear all stored marks history? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await MarksChangelogStorage.clear();
                setSheetState(() {});
              },
              child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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

  String _formatScore(double value) {
    final formatted = value.toStringAsFixed(2);
    return formatted.endsWith('.00')
        ? formatted.substring(0, formatted.length - 3)
        : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final subText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563);

    final scores = course.weightedScore;
    final hasScores = scores['totalWeight']! > 0;

    final displayWeight = hasScores ? _formatScore(scores['totalWeight']!) : '-';
    final displayAvg = hasScores ? _formatScore(scores['average']!) : '-';
    final displayObtained = hasScores ? _formatScore(scores['obtained']!) : '-';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? Border.all(color: const Color(0xFFFCD34D), width: 1.2)
            : Border.all(color: containerBorder, width: 1),
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
                              style: TextStyle(
                                color: ink,
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
                            style: TextStyle(
                              color: muted,
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
                      style: TextStyle(
                        color: subText,
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
                      style: TextStyle(
                        color: subText,
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
                          style: TextStyle(
                            color: isDark ? const Color(0xFF60A5FA) : _accent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: muted,
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
            Divider(color: containerBorder, height: 1),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No marks components found for this course.',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: containerBg,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final nameLower = section.sectionName.toLowerCase();
    final isGrandTotal = nameLower.contains('grand total') || nameLower.contains('grand_total');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder, width: 1),
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
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    isGrandTotal ? '1 item' : '${section.rows.length} items',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: muted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(color: cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'ITEM NAME',
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
                          'WEIGHT',
                          textAlign: TextAlign.center,
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
                          'AVG',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
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
                            color: muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(color: cardBorder, height: 1),
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
                        Divider(color: cardBorder, height: 1),
                        const SizedBox(height: 10),
                      ],
                      _MarkRowTile(
                        row: section.rows[i],
                        itemLabel: section.itemLabel,
                        isDropped: section.isRowDropped(section.rows[i]),
                      ),
                    ],
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No marks recorded yet.',
                        style: TextStyle(color: muted, fontSize: 11),
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

  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final hasMinMax =
        row.minimum.isNotEmpty || row.maximum.isNotEmpty || row.stdDev.isNotEmpty;
    final isTotal = row.itemNo.trim().isEmpty && !isGrandTotal;

    final textStyle = TextStyle(
      color: isDropped ? muted : ink,
      fontWeight: (isTotal || isGrandTotal) ? FontWeight.bold : FontWeight.w600,
      fontSize: 13,
      decoration: isDropped ? TextDecoration.lineThrough : null,
    );

    final valueStyle = TextStyle(
      color: isDropped ? muted : (isDark ? const Color(0xFFCBD5E1) : ink),
      fontSize: 13,
      fontWeight: FontWeight.w500,
      decoration: isDropped ? TextDecoration.lineThrough : null,
    );

    final obtainedStyle = TextStyle(
      color: isDropped
          ? muted
          : ((isTotal || isGrandTotal)
              ? ink
              : (isDark ? const Color(0xFF60A5FA) : _accent)),
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
                      child: Text(
                        'DROPPED',
                        style: TextStyle(
                          color: muted,
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
                style: TextStyle(
                  color: muted,
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
