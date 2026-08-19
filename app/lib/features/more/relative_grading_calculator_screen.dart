import 'package:flutter/material.dart';

class RelativeGradingCalculatorScreen extends StatefulWidget {
  const RelativeGradingCalculatorScreen({super.key});

  @override
  State<RelativeGradingCalculatorScreen> createState() =>
      _RelativeGradingCalculatorScreenState();
}

class _RelativeGradingCalculatorScreenState
    extends State<RelativeGradingCalculatorScreen> {
  final TextEditingController _mcaController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();

  double? _inputMca;
  double? _inputScore;
  int? _roundedMca;
  int? _roundedScore;
  String? _grade;
  Color _gradeColor = Colors.grey;

  static const Color _accent = Color(0xFF0F766E); // Teal Accent

  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _flatBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get _flatBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
  Color get _cardBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white;
  Color get _inputBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _headerSub => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2DD4BF) : const Color(0xFF115E59);
  Color get _iconBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F766E).withValues(alpha: 0.15) : const Color(0xFFCCFBF1);

  // The NUCES Official Relative Grading Scheme Table (effective Spring 2020)
  // Maps Rounded MCA (30 to 91) to thresholds for:
  // [F_max, D_min, D+_min, C-_min, C_min, C+_min, B-_min, B_min, B+_min, A-_min, A_min, A+_min]
  static const Map<int, List<int?>> _relativeGradingTable = {
    30: [29, null, null, null, null, 30, 33, 38, 43, 48, 65, 70],
    31: [29, null, null, null, null, 30, 34, 39, 44, 49, 65, 70],
    32: [29, null, null, null, null, 30, 35, 40, 45, 50, 65, 70],
    33: [29, null, null, null, 30, 31, 36, 41, 46, 51, 65, 70],
    34: [29, null, null, null, 30, 32, 37, 42, 47, 52, 65, 70],
    35: [29, null, null, null, 30, 33, 38, 43, 48, 53, 65, 70],
    36: [29, null, null, null, 30, 34, 39, 44, 49, 54, 65, 70],
    37: [29, null, null, null, 30, 35, 40, 45, 50, 55, 65, 70],
    38: [29, null, null, 30, 31, 36, 41, 46, 51, 56, 65, 70],
    39: [29, null, null, 30, 32, 37, 42, 47, 52, 57, 65, 70],
    40: [29, null, null, 30, 33, 38, 43, 48, 53, 58, 65, 70],
    41: [29, null, null, 30, 34, 39, 44, 49, 54, 59, 65, 70],
    42: [29, null, null, 30, 35, 40, 45, 50, 55, 60, 65, 70],
    43: [29, null, 30, 31, 36, 41, 46, 51, 56, 61, 66, 71],
    44: [29, null, 30, 32, 37, 42, 47, 52, 57, 62, 67, 72],
    45: [29, null, 30, 33, 38, 43, 48, 53, 58, 63, 68, 73],
    46: [29, null, 30, 34, 39, 44, 49, 54, 59, 64, 69, 74],
    47: [29, null, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
    48: [29, 30, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76],
    49: [29, 30, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77],
    50: [29, null, 30, 33, 38, 43, 48, 53, 58, 63, 68, 73],
    51: [29, null, 30, 34, 39, 44, 49, 54, 59, 64, 69, 74],
    52: [29, null, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
    53: [29, 30, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76],
    54: [29, 30, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77],
    55: [29, 30, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78],
    56: [29, 30, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79],
    57: [29, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80],
    58: [30, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81],
    59: [31, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82],
    60: [32, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83],
    61: [33, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84],
    62: [34, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85],
    63: [35, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86],
    64: [36, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87],
    65: [32, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83],
    66: [33, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84],
    67: [34, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85],
    68: [35, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86],
    69: [36, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87],
    70: [37, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83, 88],
    71: [38, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84, 89],
    72: [39, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90],
    73: [40, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86, 91],
    74: [41, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87, 92],
    75: [42, 43, 48, 53, 58, 63, 68, 73, 78, 83, 88, 93],
    76: [43, 44, 49, 54, 59, 64, 69, 74, 79, 84, 89, 94],
    77: [44, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95],
    78: [45, 46, 51, 56, 61, 66, 71, 76, 81, 86, 90, 95],
    79: [46, 47, 52, 57, 62, 67, 72, 77, 82, 87, 90, 95],
    80: [47, 48, 53, 58, 63, 68, 73, 78, 83, 88, 90, 95],
    81: [48, 49, 54, 59, 64, 69, 74, 79, 84, 89, 90, 95],
    82: [49, 50, 55, 60, 65, 70, 75, 80, 85, null, 90, 95],
    83: [49, 50, 56, 61, 66, 71, 76, 81, 86, null, 90, 95],
    84: [49, 50, 57, 62, 67, 72, 77, 82, 87, null, 90, 95],
    85: [49, 50, 58, 63, 68, 73, 78, 83, 88, null, 90, 95],
    86: [49, 50, 59, 64, 69, 74, 79, 84, 89, null, 90, 95],
    87: [49, 50, 60, 65, 70, 75, 80, 85, null, null, 90, 95],
    88: [49, 50, 61, 66, 71, 76, 81, 86, null, null, 90, 95],
    89: [49, 50, 62, 67, 72, 77, 82, 87, null, null, 90, 95],
    90: [49, 50, 63, 68, 73, 78, 83, 88, null, null, 90, 95],
    91: [49, 50, 64, 69, 74, 79, 84, 89, null, null, 90, 95],
  };

  @override
  void initState() {
    super.initState();
    _mcaController.addListener(_calculateGrade);
    _scoreController.addListener(_calculateGrade);
  }

  @override
  void dispose() {
    _mcaController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _calculateGrade() {
    final mcaText = _mcaController.text.trim();
    final scoreText = _scoreController.text.trim();

    if (mcaText.isEmpty || scoreText.isEmpty) {
      setState(() {
        _inputMca = double.tryParse(mcaText);
        _inputScore = double.tryParse(scoreText);
        _roundedMca = null;
        _roundedScore = null;
        _grade = null;
      });
      return;
    }

    final mca = double.tryParse(mcaText);
    final score = double.tryParse(scoreText);

    if (mca == null || mca < 0 || mca > 100 || score == null || score < 0 || score > 100) {
      setState(() {
        _inputMca = mca;
        _inputScore = score;
        _roundedMca = null;
        _roundedScore = null;
        _grade = 'Invalid';
        _gradeColor = const Color(0xFFEF4444); // Red
      });
      return;
    }

    final mcaRounded = mca.round();
    final scoreRounded = score.round();

    // Clamp MCA between 30 and 91
    final mcaClamped = mcaRounded.clamp(30, 91);
    final row = _relativeGradingTable[mcaClamped];

    if (row == null) {
      setState(() {
        _inputMca = mca;
        _inputScore = score;
        _roundedMca = mcaRounded;
        _roundedScore = scoreRounded;
        _grade = 'Invalid';
        _gradeColor = const Color(0xFFEF4444);
      });
      return;
    }

    String grade = 'F';
    Color color = const Color(0xFFEF4444); // Red for F

    // Thresholds:
    // 0: F_max, 1: D, 2: D+, 3: C-, 4: C, 5: C+, 6: B-, 7: B, 8: B+, 9: A-, 10: A, 11: A+
    final Map<int, Map<String, dynamic>> mapping = {
      11: {'grade': 'A+', 'color': const Color(0xFF10B981)},
      10: {'grade': 'A', 'color': const Color(0xFF10B981)},
      9: {'grade': 'A-', 'color': const Color(0xFF10B981)},
      8: {'grade': 'B+', 'color': const Color(0xFF0F766E)}, // Teal
      7: {'grade': 'B', 'color': const Color(0xFF0F766E)},
      6: {'grade': 'B-', 'color': const Color(0xFF0F766E)},
      5: {'grade': 'C+', 'color': const Color(0xFF6366F1)}, // Indigo
      4: {'grade': 'C', 'color': const Color(0xFF6366F1)},
      3: {'grade': 'C-', 'color': const Color(0xFF6366F1)},
      2: {'grade': 'D+', 'color': const Color(0xFFF59E0B)}, // Amber
      1: {'grade': 'D', 'color': const Color(0xFFF59E0B)},
    };

    // Check starting from A+ down to D
    bool matched = false;
    for (final index in [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]) {
      final val = row[index];
      if (val != null && scoreRounded >= val) {
        grade = mapping[index]!['grade'] as String;
        color = mapping[index]!['color'] as Color;
        matched = true;
        break;
      }
    }

    if (!matched) {
      grade = 'F';
      color = const Color(0xFFEF4444);
    }

    setState(() {
      _inputMca = mca;
      _inputScore = score;
      _roundedMca = mcaRounded;
      _roundedScore = scoreRounded;
      _grade = grade;
      _gradeColor = color;
    });
  }

  List<Map<String, String>> _getGradeRanges(int mcaRounded) {
    final mcaClamped = mcaRounded.clamp(30, 91);
    final row = _relativeGradingTable[mcaClamped];
    if (row == null) return [];

    final gradesList = ['F', 'D', 'D+', 'C-', 'C', 'C+', 'B-', 'B', 'B+', 'A-', 'A', 'A+'];
    final List<Map<String, String>> ranges = [];

    for (int i = 0; i < gradesList.length; i++) {
      final grade = gradesList[i];
      if (grade == 'F') {
        final fMax = row[0]!;
        ranges.add({'grade': 'F', 'range': '≤ $fMax%'});
        continue;
      }

      final threshold = row[i];
      if (threshold == null) {
        ranges.add({'grade': grade, 'range': '-'});
        continue;
      }

      int? nextThreshold;
      for (int j = i + 1; j < gradesList.length; j++) {
        if (row[j] != null) {
          nextThreshold = row[j];
          break;
        }
      }

      if (nextThreshold == null) {
        ranges.add({'grade': grade, 'range': '≥ $threshold%'});
      } else {
        final maxVal = nextThreshold - 1;
        if (maxVal == threshold) {
          ranges.add({'grade': grade, 'range': '$threshold%'});
        } else {
          ranges.add({'grade': grade, 'range': '$threshold - $maxVal%'});
        }
      }
    }

    return ranges.reversed.toList();
  }

  Widget _buildCalculatorHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _inputBorder, width: 1),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: _ink,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Academic Utilities',
              style: TextStyle(
                color: _headerSub,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relative Calculator',
          style: TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'NUCES RELATIVE POLICY (SPRING 2020)',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showResult = _grade != null;
    final mcaForTable = _roundedMca != null ? _roundedMca!.clamp(30, 91) : 50;
    final ranges = _getGradeRanges(mcaForTable);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCalculatorHeader(context),
              const SizedBox(height: 48),
              _buildTitleSection(context),
              const SizedBox(height: 36),

              // Inputs Container
              Container(
                decoration: BoxDecoration(
                  color: _flatBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _flatBorder, width: 1),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MCA Input
                    Text(
                      'MEAN CLASS AVERAGE (MCA) (%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mcaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Enter class average (e.g. 50.4)',
                        hintStyle: TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.people_outline, color: _accent, size: 18),
                        fillColor: _cardBg,
                        filled: true,
                        suffixIcon: _mcaController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _muted),
                                onPressed: () => _mcaController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Score Input
                    Text(
                      'YOUR COURSE SCORE (%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _scoreController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Enter your total marks (e.g. 62.6)',
                        hintStyle: TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.percent, color: _accent, size: 18),
                        fillColor: _cardBg,
                        filled: true,
                        suffixIcon: _scoreController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _muted),
                                onPressed: () => _scoreController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Results box
              if (_grade != null) ...[
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _grade == 'Invalid' ? const Color(0xFFFEF2F2) : _gradeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _grade == 'Invalid' ? const Color(0xFFFCA5A5) : _gradeColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _grade == 'Invalid'
                      ? Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Please enter valid values. MCA must be between 30 and 91, and Marks between 0 and 100.',
                                style: TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _gradeColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: _gradeColor.withValues(alpha: 0.3), width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _grade!,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: _gradeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CALCULATED GRADE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _muted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Grade ${_grade!} assigned',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'MCA: ${_inputMca!.toStringAsFixed(1)}% (rounded to $_roundedMca%)\nYour Marks: ${_inputScore!.toStringAsFixed(1)}% (rounded to $_roundedScore%)',
                                    style: TextStyle(fontSize: 12, color: _muted, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 32),
              ],

              // Dynamic threshold reference title
              Text(
                'RELATIVE SCALING AT MCA = $mcaForTable%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic table
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _flatBorder, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Table(
                    border: TableBorder.all(
                      color: _flatBorder,
                      width: 0.8,
                    ),
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(color: _flatBg),
                        children: [
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Text(
                                'Course Score Range (%)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Text(
                                'Letter Grade',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Dynamic Data Rows
                      ...ranges.map((row) {
                        final isUsersGrade = showResult && _grade == row['grade'] && _grade != 'Invalid';
                        return TableRow(
                          decoration: BoxDecoration(
                            color: isUsersGrade ? _gradeColor.withValues(alpha: 0.1) : null,
                          ),
                          children: [
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                child: Text(
                                  row['range']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _ink,
                                    fontWeight: isUsersGrade ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                child: Text(
                                  row['grade']!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isUsersGrade ? _gradeColor : _accent,
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
}
