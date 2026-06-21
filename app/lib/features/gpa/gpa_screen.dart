import 'package:flutter/material.dart';

import '../../models/transcript_models.dart';
import '../../services/transcript_storage.dart';
import 'academic_report_screen.dart';

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

    setState(() {
      _snapshot = snapshot;
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
      backgroundColor: Colors.white,
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
                            const SizedBox(height: 48),
                            _LatestSemesterCalculator(
                              semester: _snapshot!
                                  .semesters[_selectedSemesterIndex],
                              selectedGrades: _selectedGrades,
                              gradeOptions: _gradeOptions,
                              gradePoints: _gradePoints,
                              onGradeChanged: _updateGrade,
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

  Widget _buildAcademicIndexHeader(BuildContext context) {
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
            Icons.insert_chart_outlined_rounded,
            color: Color(0xFF2563EB),
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Academic Index',
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
    final latestSemester = _snapshot!.semesters[_selectedSemesterIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GPA Calculator',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${latestSemester.name.toUpperCase()} SEMESTER',
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

  Widget _buildGpaSection(BuildContext context) {
    final semesterGpa = _currentSemesterGpa();
    final cgpa = _overallCgpa();

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SGPA',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
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
            const Text(
              'CGPA',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatFixedDecimal(cgpa),
              style: const TextStyle(
                color: Color(0xFF1E293B),
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
}

class _LatestSemesterCalculator extends StatelessWidget {
  const _LatestSemesterCalculator({
    required this.semester,
    required this.selectedGrades,
    required this.gradeOptions,
    required this.gradePoints,
    required this.onGradeChanged,
    required this.onGenerateReport,
  });

  final TranscriptSemester semester;
  final List<String?> selectedGrades;
  final List<String> gradeOptions;
  final Map<String, double> gradePoints;
  final ValueChanged2<int, String?> onGradeChanged;
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
          if (index > 0) const SizedBox(height: 20),
          _GradeRow(
            course: semester.courses[index],
            selectedGrade: index < selectedGrades.length
                ? selectedGrades[index]
                : null,
            gradeOptions: gradeOptions,
            gradePoints: gradePoints,
            onChanged: (grade) => onGradeChanged(index, grade),
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
  });

  final TranscriptCourse course;
  final String? selectedGrade;
  final List<String> gradeOptions;
  final Map<String, double> gradePoints;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = selectedGrade != null
        ? selectedGrade!
              .replaceAll(' ', '')
              .replaceAll('.', '')
              .toUpperCase()
        : '';
    final gradePoint = gradePoints[normalized];
    final displayPoints = gradePoint != null ? gradePoint.toStringAsFixed(2) : '-';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.courseName,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                course.code,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
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
            style: const TextStyle(
              color: Color(0xFF4B5563),
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
            style: const TextStyle(
              color: Color(0xFF4B5563),
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
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6B7280),
                    size: 16,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  hint: const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('-', style: TextStyle(color: Color(0xFF6B7280))),
                    ),
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return gradeOptions.map<Widget>((String grade) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(grade),
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
