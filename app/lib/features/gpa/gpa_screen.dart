import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/transcript_models.dart';
import '../../services/transcript_storage.dart';
import '../../models/marks_models.dart';
import '../../services/marks_storage.dart';
import '../../utils/grading_utils.dart';
import 'academic_report_screen.dart';
import 'cgpa_roadmap_simulator_screen.dart';

class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key});

  @override
  State<GpaScreen> createState() => GpaScreenState();
}

class GpaScreenState extends State<GpaScreen> {
  TranscriptSnapshot? _snapshot;
  bool _isLoading = true;
  int _selectedSemesterIndex = -1;
  List<String?> _selectedGrades = const [];
  MarksSnapshot? _marksSnapshot;
  Map<String, String> _gradingSchemes = {};
  Map<String, int> _courseMcas = {};

  static const Color _accent = Color(0xFF2563EB);

  static const List<String> _gradeOptions = [
    'A+',
    'A',
    'A-',
    'B+',
    'B',
    'B-',
    'C+',
    'C',
    'C-',
    'D+',
    'D',
    'F',
  ];

  static const Map<String, double> _gradePoints = {
    'A+': 4.0,
    'A': 4.0,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.0,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.0,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.0,
    'F': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> reload() => _loadSnapshot();

  Future<void> _loadSnapshot() async {
    final snapshot = await TranscriptStorage.load();
    final marksSnapshot = await MarksStorage.load();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    final semesterIndex = snapshot == null || snapshot.semesters.isEmpty
        ? -1
        : snapshot.semesters.length - 1;
    final selectedGrades = semesterIndex >= 0
        ? snapshot!.semesters[semesterIndex].courses
              .map((course) {
                final normalized = _normalizeGrade(course.grade);
                return _gradePoints.containsKey(normalized) ? normalized : null;
              })
              .toList(growable: false)
        : const <String?>[];

    final gradingSchemes = <String, String>{};
    final courseMcas = <String, int>{};

    if (snapshot != null && semesterIndex >= 0) {
      final semester = snapshot.semesters[semesterIndex];
      for (final course in semester.courses) {
        final code = course.code.trim().toUpperCase();
        gradingSchemes[code] = prefs.getString('flex_grading_scheme_$code') ?? 'absolute';

        MarksCourse? mc;
        if (marksSnapshot != null) {
          final tcNormalizedCode = course.code.trim().toLowerCase().replaceAll(' ', '');
          final tcNormalizedName = course.courseName.trim().toLowerCase().replaceAll(' ', '');
          for (final c in marksSnapshot.courses) {
            final mcNormalizedCode = c.courseCode.trim().toLowerCase().replaceAll(' ', '');
            final mcNormalizedName = c.courseTitle.trim().toLowerCase().replaceAll(' ', '');
            if (tcNormalizedCode == mcNormalizedCode || tcNormalizedName == mcNormalizedName) {
              mc = c;
              break;
            }
          }
        }

        int autoPredictedMca = 60;
        if (mc != null) {
          final scores = mc.weightedScore;
          final totalWeight = scores['totalWeight'] ?? 0.0;
          final average = scores['average'] ?? 0.0;
          if (totalWeight > 0) {
            autoPredictedMca = ((average / totalWeight) * 100).round().clamp(30, 91);
          }
        }
        courseMcas[code] = prefs.getInt('flex_grading_mca_$code') ?? autoPredictedMca;
      }
    }

    setState(() {
      _snapshot = snapshot;
      _marksSnapshot = marksSnapshot;
      _gradingSchemes = gradingSchemes;
      _courseMcas = courseMcas;
      _isLoading = false;
      _selectedSemesterIndex = semesterIndex;
      _selectedGrades = selectedGrades;
    });
  }

  void _updateGrade(int courseIndex, String? grade) {
    setState(() {
      final next = List<String?>.from(_selectedGrades);
      if (courseIndex >= 0 && courseIndex < next.length) {
        next[courseIndex] = grade;
      }
      _selectedGrades = next;
    });
  }

  String _normalizeGrade(String grade) {
    return grade.replaceAll(' ', '').replaceAll('.', '').toUpperCase().trim();
  }

  double? _creditHoursFor(String creditHours) {
    final parsed = double.tryParse(creditHours.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _gradePointFor(String? grade) {
    if (grade == null) {
      return null;
    }
    return _gradePoints[_normalizeGrade(grade)];
  }

  double? _semesterGpa(
    TranscriptSemester semester, {
    List<String?>? selectedGrades,
  }) {
    var totalQualityPoints = 0.0;
    var totalCreditHours = 0.0;

    for (var index = 0; index < semester.courses.length; index++) {
      final course = semester.courses[index];
      final creditHours = _creditHoursFor(course.creditHours);
      if (creditHours == null) {
        continue;
      }

      final gradeToUse = (selectedGrades != null && index < selectedGrades.length)
          ? selectedGrades[index]
          : course.grade;
      final gradePoint = _gradePointFor(gradeToUse);
      if (gradePoint == null) {
        continue;
      }

      totalQualityPoints += creditHours * gradePoint;
      totalCreditHours += creditHours;
    }

    if (totalCreditHours <= 0) {
      return null;
    }

    return totalQualityPoints / totalCreditHours;
  }

  double? _currentSemesterGpa() {
    final snapshot = _snapshot;
    if (snapshot == null || _selectedSemesterIndex < 0) {
      return null;
    }

    return _semesterGpa(
      snapshot.semesters[_selectedSemesterIndex],
      selectedGrades: _selectedGrades,
    );
  }

  double? _overallCgpa() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.semesters.isEmpty) {
      return null;
    }

    var totalQualityPoints = 0.0;
    var totalCreditHours = 0.0;

    for (
      var semesterIndex = 0;
      semesterIndex < snapshot.semesters.length;
      semesterIndex++
    ) {
      final semester = snapshot.semesters[semesterIndex];
      for (
        var courseIndex = 0;
        courseIndex < semester.courses.length;
        courseIndex++
      ) {
        final course = semester.courses[courseIndex];
        final creditHours = _creditHoursFor(course.creditHours);
        if (creditHours == null) {
          continue;
        }

        String? gradeToUse;
        if (semesterIndex == _selectedSemesterIndex &&
            courseIndex < _selectedGrades.length) {
          gradeToUse = _selectedGrades[courseIndex];
        } else {
          gradeToUse = course.grade;
        }

        final gradePoint = _gradePointFor(gradeToUse);
        if (gradePoint == null) {
          continue;
        }

        totalQualityPoints += creditHours * gradePoint;
        totalCreditHours += creditHours;
      }
    }

    if (totalCreditHours <= 0) {
      return null;
    }

    return totalQualityPoints / totalCreditHours;
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
                onRefresh: _loadSnapshot,
                color: _accent,
                child: _snapshot == null || _snapshot!.semesters.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        children: const [
                          SizedBox(height: 80),
                          _EmptyGpaState(),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAcademicIndexHeader(context),
                            const SizedBox(height: 48),
                            _buildTitleSection(context),
                            const SizedBox(height: 36),
                             _buildGpaSection(context),
                             const SizedBox(height: 24),
                             _buildCgpaRoadmapBanner(context),
                             const SizedBox(height: 36),
                            _LatestSemesterCalculator(
                              semester: _snapshot!
                                  .semesters[_selectedSemesterIndex],
                              selectedGrades: _selectedGrades,
                              gradeOptions: _gradeOptions,
                              gradePoints: _gradePoints,
                              onGradeChanged: _updateGrade,
                              marksSnapshot: _marksSnapshot,
                              gradingSchemes: _gradingSchemes,
                              courseMcas: _courseMcas,
                              onSchemeChanged: _updateGradingScheme,
                              onMcaChanged: _updateCourseMca,
                              onGenerateReport: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AcademicReportScreen(
                                      snapshot: _snapshot!,
                                      selectedSemesterIndex: _selectedSemesterIndex,
                                      selectedGrades: _selectedGrades,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
              ),
      ),
    );
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

  Widget _buildAcademicIndexHeader(BuildContext context) {
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
            Icons.insert_chart_outlined_rounded,
            color: Color(0xFF2563EB),
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Academic Index',
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
    final latestSemester = _snapshot!.semesters[_selectedSemesterIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GPA Calculator',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${latestSemester.name.toUpperCase()} SEMESTER',
          style: TextStyle(
            color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGpaSection(BuildContext context) {
    final semesterGpa = _currentSemesterGpa();
    final cgpa = _overallCgpa();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SGPA',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatFixedDecimal(semesterGpa),
              style: const TextStyle(
                color: Color(0xFF2563EB),
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
              'CGPA',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatFixedDecimal(cgpa),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
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

  Widget _buildCgpaRoadmapBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CgpaRoadmapSimulatorScreen(snapshot: _snapshot),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                color: _accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Graduation CGPA Simulator',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Simulate SGPA targets needed for remaining semesters',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: mutedColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestSemesterCalculator extends StatelessWidget {
  const _LatestSemesterCalculator({
    required this.semester,
    required this.selectedGrades,
    required this.gradeOptions,
    required this.gradePoints,
    required this.onGradeChanged,
    required this.marksSnapshot,
    required this.gradingSchemes,
    required this.courseMcas,
    required this.onSchemeChanged,
    required this.onMcaChanged,
    required this.onGenerateReport,
  });

  final TranscriptSemester semester;
  final List<String?> selectedGrades;
  final List<String> gradeOptions;
  final Map<String, double> gradePoints;
  final ValueChanged2<int, String?> onGradeChanged;
  final MarksSnapshot? marksSnapshot;
  final Map<String, String> gradingSchemes;
  final Map<String, int> courseMcas;
  final ValueChanged2<String, String> onSchemeChanged;
  final ValueChanged2<String, int> onMcaChanged;
  final VoidCallback onGenerateReport;

  @override
  Widget build(BuildContext context) {
    var totalCreditHours = 0.0;
    for (var index = 0; index < semester.courses.length; index++) {
      final course = semester.courses[index];
      final creditHours = double.tryParse(course.creditHours.trim()) ?? 0.0;
      final grade = index < selectedGrades.length ? selectedGrades[index] : null;
      final gradePoint = grade == null
          ? null
          : gradePoints[grade
                .replaceAll(' ', '')
                .replaceAll('.', '')
                .toUpperCase()];
      if (creditHours <= 0 || gradePoint == null) {
        continue;
      }
      totalCreditHours += creditHours;
    }

    final totalQualityPoints = _totalQualityPoints();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Expanded(
              flex: 4,
              child: Text(
                'SUBJECT NAME',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                'CREDITS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                'POINTS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                'GRADE',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        const SizedBox(height: 16),
        for (var index = 0; index < semester.courses.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _GradeRow(
            course: semester.courses[index],
            selectedGrade: index < selectedGrades.length
                ? selectedGrades[index]
                : null,
            gradeOptions: gradeOptions,
            gradePoints: gradePoints,
            onChanged: (grade) => onGradeChanged(index, grade),
            marksSnapshot: marksSnapshot,
            gradingSchemes: gradingSchemes,
            courseMcas: courseMcas,
            onSchemeChanged: onSchemeChanged,
            onMcaChanged: onMcaChanged,
          ),
        ],
        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL CREDITS',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    totalCreditHours.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GRADED POINTS',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    totalQualityPoints.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Center(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onGenerateReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'GENERATE REPORT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _totalQualityPoints() {
    var total = 0.0;
    for (var index = 0; index < semester.courses.length; index++) {
      final course = semester.courses[index];
      final creditHours = double.tryParse(course.creditHours.trim()) ?? 0;
      final grade = index < selectedGrades.length
          ? selectedGrades[index]
          : null;
      final gradePoint = grade == null
          ? null
          : gradePoints[grade
                .replaceAll(' ', '')
                .replaceAll('.', '')
                .toUpperCase()];
      if (creditHours <= 0 || gradePoint == null) {
        continue;
      }
      total += creditHours * gradePoint;
    }
    return total;
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.course,
    required this.selectedGrade,
    required this.gradeOptions,
    required this.gradePoints,
    required this.onChanged,
    required this.marksSnapshot,
    required this.gradingSchemes,
    required this.courseMcas,
    required this.onSchemeChanged,
    required this.onMcaChanged,
  });

  final TranscriptCourse course;
  final String? selectedGrade;
  final List<String> gradeOptions;
  final Map<String, double> gradePoints;
  final ValueChanged<String?> onChanged;
  final MarksSnapshot? marksSnapshot;
  final Map<String, String> gradingSchemes;
  final Map<String, int> courseMcas;
  final ValueChanged2<String, String> onSchemeChanged;
  final ValueChanged2<String, int> onMcaChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final Color containerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color dropdownBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final normalized = selectedGrade != null
        ? selectedGrade!
              .replaceAll(' ', '')
              .replaceAll('.', '')
              .toUpperCase()
        : '';
    final gradePoint = gradePoints[normalized];
    final displayPoints = gradePoint != null ? gradePoint.toStringAsFixed(2) : '-';

    final String normalizedCode = course.code.trim().toUpperCase();
    final scheme = gradingSchemes[normalizedCode] ?? 'absolute';
    final isAbsolute = scheme == 'absolute';
    final mca = courseMcas[normalizedCode] ?? 60;

    MarksCourse? mc;
    if (marksSnapshot != null) {
      final tcNormalizedCode = course.code.trim().toLowerCase().replaceAll(' ', '');
      final tcNormalizedName = course.courseName.trim().toLowerCase().replaceAll(' ', '');
      for (final c in marksSnapshot!.courses) {
        final mcNormalizedCode = c.courseCode.trim().toLowerCase().replaceAll(' ', '');
        final mcNormalizedName = c.courseTitle.trim().toLowerCase().replaceAll(' ', '');
        if (tcNormalizedCode == mcNormalizedCode || tcNormalizedName == mcNormalizedName) {
          mc = c;
          break;
        }
      }
    }

    double obtained = 0.0;
    double totalWeight = 0.0;
    if (mc != null) {
      final scores = mc.weightedScore;
      obtained = scores['obtained'] ?? 0.0;
      totalWeight = scores['totalWeight'] ?? 0.0;
    }

    final double remainingWeight = 100.0 - totalWeight;
    final double maxPossibleScore = obtained + remainingWeight;
    
    final String maxGrade = (mc != null)
        ? (isAbsolute
            ? GradingUtils.calculateAbsoluteGrade(maxPossibleScore)
            : GradingUtils.calculateRelativeGrade(maxPossibleScore, mca))
        : '—';

    final double predictedScore = totalWeight > 0 ? (obtained / totalWeight) * 100 : 0.0;
    final String predictedGrade = (mc != null && totalWeight > 0)
        ? (isAbsolute
            ? GradingUtils.calculateAbsoluteGrade(predictedScore)
            : GradingUtils.calculateRelativeGrade(predictedScore, mca))
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: containerBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseName,
                      style: TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.code,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  double.tryParse(course.creditHours)?.toStringAsFixed(1) ?? course.creditHours,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  displayPoints,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 45,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGrade,
                        isDense: true,
                        isExpanded: true,
                        alignment: Alignment.centerLeft,
                        dropdownColor: dropdownBg,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: muted,
                          size: 16,
                        ),
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        hint: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('-', style: TextStyle(color: muted)),
                          ),
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return gradeOptions.map<Widget>((String grade) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(grade, style: TextStyle(color: ink)),
                              ),
                            );
                          }).toList();
                        },
                        items: gradeOptions
                            .map(
                              (grade) => DropdownMenuItem<String>(
                                value: grade,
                                alignment: Alignment.centerLeft,
                                child: Text(grade),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: containerBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Scheme: ',
                      style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: scheme,
                      style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.bold),
                      dropdownColor: dropdownBg,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'absolute', child: Text('Absolute')),
                        DropdownMenuItem(value: 'relative', child: Text('Relative')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          onSchemeChanged(normalizedCode, val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (!isAbsolute) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'MCA: ',
                        style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      DropdownButton<int>(
                        value: mca,
                        style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.bold),
                        dropdownColor: dropdownBg,
                        underline: const SizedBox.shrink(),
                        items: List.generate(62, (idx) {
                          final val = 30 + idx;
                          return DropdownMenuItem(
                            value: val,
                            child: Text('$val%'),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            onMcaChanged(normalizedCode, val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (mc != null) ...[
            Row(
              children: [
                _buildGradeBadge(context, 'MAX GRADE', maxGrade),
                const SizedBox(width: 8),
                _buildGradeBadge(context, 'PREDICTED', predictedGrade),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'No marks history synced for this course',
                style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeBadge(BuildContext context, String label, String grade) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color badgeColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              grade,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGpaState extends StatelessWidget {
  const _EmptyGpaState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.calculate_outlined,
          size: 52,
          color: Color(0xFF6B7788),
        ),
        const SizedBox(height: 16),
        Text(
          'No transcript data captured yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF1A2332),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Open the transcript sync first so the GPA calculator can load the latest semester.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7788), height: 1.4),
        ),
      ],
    );
  }
}

typedef ValueChanged2<T, U> = void Function(T value, U value2);

String _formatFixedDecimal(double? value, {int fractionDigits = 2}) {
  if (value == null) {
    return '-';
  }

  return value.toStringAsFixed(fractionDigits);
}
