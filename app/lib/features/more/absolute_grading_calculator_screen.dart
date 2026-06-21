import 'package:flutter/material.dart';

class AbsoluteGradingCalculatorScreen extends StatefulWidget {
  const AbsoluteGradingCalculatorScreen({super.key});

  @override
  State<AbsoluteGradingCalculatorScreen> createState() =>
      _AbsoluteGradingCalculatorScreenState();
}

class _AbsoluteGradingCalculatorScreenState
    extends State<AbsoluteGradingCalculatorScreen> {
  final TextEditingController _scoreController = TextEditingController();
  double? _inputScore;
  int? _roundedScore;
  String? _grade;
  Color _gradeColor = Colors.grey;

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray
  static const Color _flatBg = Color(0xFFF8FAFC); // Slate 50
  static const Color _flatBorder = Color(0xFFF1F5F9); // Slate 100

  @override
  void initState() {
    super.initState();
    _scoreController.addListener(_calculateGrade);
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  void _calculateGrade() {
    final text = _scoreController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _inputScore = null;
        _roundedScore = null;
        _grade = null;
      });
      return;
    }

    final score = double.tryParse(text);
    if (score == null || score < 0 || score > 100) {
      setState(() {
        _inputScore = score;
        _roundedScore = null;
        _grade = 'Invalid';
        _gradeColor = const Color(0xFFEF4444); // Red
      });
      return;
    }

    final rounded = score.round();
    String grade;
    Color color;

    if (rounded >= 90) {
      grade = 'A+';
      color = const Color(0xFF10B981); // Emerald
    } else if (rounded >= 86) {
      grade = 'A';
      color = const Color(0xFF10B981); // Emerald
    } else if (rounded >= 82) {
      grade = 'A-';
      color = const Color(0xFF10B981); // Emerald
    } else if (rounded >= 78) {
      grade = 'B+';
      color = _accent; // Royal Blue
    } else if (rounded >= 74) {
      grade = 'B';
      color = _accent; // Royal Blue
    } else if (rounded >= 70) {
      grade = 'B-';
      color = _accent; // Royal Blue
    } else if (rounded >= 66) {
      grade = 'C+';
      color = const Color(0xFF6366F1); // Indigo
    } else if (rounded >= 62) {
      grade = 'C';
      color = const Color(0xFF6366F1); // Indigo
    } else if (rounded >= 58) {
      grade = 'C-';
      color = const Color(0xFF6366F1); // Indigo
    } else if (rounded >= 54) {
      grade = 'D+';
      color = const Color(0xFFF59E0B); // Amber
    } else if (rounded >= 50) {
      grade = 'D';
      color = const Color(0xFFF59E0B); // Amber
    } else {
      grade = 'F';
      color = const Color(0xFFEF4444); // Red
    }

    setState(() {
      _inputScore = score;
      _roundedScore = rounded;
      _grade = grade;
      _gradeColor = color;
    });
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: const Icon(
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
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
              ),
              child: const Icon(
                Icons.calculate_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Academic Utilities',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grading Calculator',
          style: TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'NUCES ABSOLUTE POLICY (SPRING 2020)',
          style: TextStyle(
            color: Color(0xFFB45309),
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
    final scaleData = [
      {'range': '≥ 90%', 'grade': 'A+'},
      {'range': '86 - 89%', 'grade': 'A'},
      {'range': '82 - 85%', 'grade': 'A-'},
      {'range': '78 - 81%', 'grade': 'B+'},
      {'range': '74 - 77%', 'grade': 'B'},
      {'range': '70 - 73%', 'grade': 'B-'},
      {'range': '66 - 69%', 'grade': 'C+'},
      {'range': '62 - 65%', 'grade': 'C'},
      {'range': '58 - 61%', 'grade': 'C-'},
      {'range': '54 - 57%', 'grade': 'D+'},
      {'range': '50 - 53%', 'grade': 'D'},
      {'range': '≤ 49%', 'grade': 'F'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
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
              
              // Input field container
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
                    const Text(
                      'TOTAL COURSE SCORE (%)',
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
                      style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Enter your total marks (e.g. 73.6)',
                        hintStyle: const TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.percent, color: _accent, size: 18),
                        fillColor: Colors.white,
                        filled: true,
                        suffixIcon: _scoreController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: _muted),
                                onPressed: () => _scoreController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
                    color: _grade == 'Invalid' ? const Color(0xFFFEF2F2) : _gradeColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _grade == 'Invalid' ? const Color(0xFFFCA5A5) : _gradeColor.withValues(alpha: 0.15),
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
                                'Please enter a valid percentage between 0 and 100.',
                                style: TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
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
                                color: _gradeColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: _gradeColor.withValues(alpha: 0.2), width: 1),
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
                                  const Text(
                                    'CALCULATED GRADE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _muted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Grade ${_grade!} assigned',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Obtained: ${_inputScore!.toStringAsFixed(1)}% (rounded to $_roundedScore%)',
                                    style: const TextStyle(fontSize: 12, color: _muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 32),
              ],

              // Reference scale title
              const Text(
                'ABSOLUTE GRADING SCALE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Reference table
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
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Text(
                                'Total Marks (%)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Text(
                                'Letter Grade',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Data Rows
                      ...scaleData.map((row) {
                        return TableRow(
                          children: [
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                child: Text(
                                  row['range']!,
                                  style: const TextStyle(fontSize: 13, color: _ink),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                child: Text(
                                  row['grade']!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _accent),
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
