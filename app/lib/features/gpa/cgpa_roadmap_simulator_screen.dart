import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/transcript_models.dart';
import '../../services/transcript_storage.dart';

class CgpaRoadmapSimulatorScreen extends StatefulWidget {
  final TranscriptSnapshot? snapshot;

  const CgpaRoadmapSimulatorScreen({super.key, this.snapshot});

  @override
  State<CgpaRoadmapSimulatorScreen> createState() => _CgpaRoadmapSimulatorScreenState();
}

class _CgpaRoadmapSimulatorScreenState extends State<CgpaRoadmapSimulatorScreen> {
  static const Color _accent = Color(0xFF2563EB); // Royal Blue

  // Configuration
  int _totalDegreeSemesters = 8;
  double _totalDegreeCredits = 133.0;
  double _targetCgpa = 3.50;

  // Derived state from transcript
  double _completedCredits = 0.0;
  double _completedQualityPoints = 0.0;
  int _completedSemestersCount = 0;
  bool _isLoading = true;

  // Dynamic future semester SGPA values (key: semester number e.g. 5 -> sgpa)
  final Map<int, double> _futureSemesterSgpas = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    TranscriptSnapshot? snapshot = widget.snapshot;
    snapshot ??= await TranscriptStorage.load();

    double compCredits = 0.0;
    double compQp = 0.0;
    int completedSems = 0;

    if (snapshot != null && snapshot.semesters.isNotEmpty) {
      int finishedSemsCount = 0;
      for (final sem in snapshot.semesters) {
        bool hasGradedCourse = false;
        for (final course in sem.courses) {
          final ch = double.tryParse(course.creditHours.trim()) ?? 0.0;
          final cleanGrade = course.grade.replaceAll(' ', '').replaceAll('.', '').toUpperCase();
          final gp = _gradePointFor(course.grade);

          if (ch > 0 && gp != null && cleanGrade != 'I' && cleanGrade != 'W') {
            compCredits += ch;
            compQp += (ch * gp);
            hasGradedCourse = true;
          }
        }
        if (hasGradedCourse) {
          finishedSemsCount++;
        }
      }
      completedSems = finishedSemsCount;
    }

    // Default fallback if no transcript synced yet
    if (compCredits == 0) {
      compCredits = 64.0;
      compQp = 64.0 * 3.20; // 3.20 CGPA default for demo
      completedSems = 4;
    }

    final remainingSemsCount = max(0, _totalDegreeSemesters - completedSems);

    // Initial default required average for future semesters
    final remainingCredits = max(1.0, _totalDegreeCredits - compCredits);
    final reqTotalQp = _targetCgpa * _totalDegreeCredits;
    final reqRemQp = max(0.0, reqTotalQp - compQp);
    final initialAvgFutureSgpa = (reqRemQp / remainingCredits).clamp(0.0, 4.0);

    final futureSgpas = <int, double>{};
    for (int i = completedSems + 1; i <= _totalDegreeSemesters; i++) {
      futureSgpas[i] = double.parse(initialAvgFutureSgpa.toStringAsFixed(2));
    }

    if (mounted) {
      setState(() {
        _completedCredits = compCredits;
        _completedQualityPoints = compQp;
        _completedSemestersCount = completedSems;
        _futureSemesterSgpas.clear();
        _futureSemesterSgpas.addAll(futureSgpas);
        _isLoading = false;
      });
    }
  }

  double? _gradePointFor(String grade) {
    final clean = grade.replaceAll(' ', '').replaceAll('.', '').toUpperCase();
    switch (clean) {
      case 'A+':
      case 'A':
        return 4.0;
      case 'A-':
        return 3.67;
      case 'B+':
        return 3.33;
      case 'B':
        return 3.0;
      case 'B-':
        return 2.67;
      case 'C+':
        return 2.33;
      case 'C':
        return 2.0;
      case 'C-':
        return 1.67;
      case 'D+':
        return 1.33;
      case 'D':
        return 1.0;
      case 'F':
        return 0.0;
      default:
        return null;
    }
  }

  double get _currentCgpa => _completedCredits > 0 ? _completedQualityPoints / _completedCredits : 0.0;

  double get _remainingCredits => max(0.0, _totalDegreeCredits - _completedCredits);

  int get _remainingSemestersCount => max(0, _totalDegreeSemesters - _completedSemestersCount);

  double get _avgCreditsPerFutureSemester =>
      _remainingSemestersCount > 0 ? _remainingCredits / _remainingSemestersCount : 0.0;

  // Calculates required average future SGPA to hit target CGPA
  double get _requiredAvgFutureSgpa {
    if (_remainingCredits <= 0) return 0.0;
    final reqTotalQp = _targetCgpa * _totalDegreeCredits;
    final reqRemQp = reqTotalQp - _completedQualityPoints;
    return reqRemQp / _remainingCredits;
  }

  // Max achievable CGPA assuming 4.00 in all remaining credits
  double get _maxAchievableCgpa {
    if (_totalDegreeCredits <= 0) return 0.0;
    final maxTotalQp = _completedQualityPoints + (_remainingCredits * 4.0);
    return min(4.0, maxTotalQp / _totalDegreeCredits);
  }

  // Simulated projected final CGPA based on current custom sliders
  double get _projectedFinalCgpa {
    if (_totalDegreeCredits <= 0) return 0.0;
    double futureQp = 0.0;
    final chPerSem = _avgCreditsPerFutureSemester;
    _futureSemesterSgpas.forEach((semNum, sgpa) {
      futureQp += (chPerSem * sgpa);
    });
    final totalQp = _completedQualityPoints + futureQp;
    return min(4.0, totalQp / _totalDegreeCredits);
  }

  void _showConfigDialog() {
    int tempSemesters = _totalDegreeSemesters;
    double tempCredits = _totalDegreeCredits;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Degree Parameters',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Degree Credit Hours:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: tempCredits,
                        min: 120.0,
                        max: 150.0,
                        divisions: 30,
                        activeColor: _accent,
                        label: '${tempCredits.round()} CH',
                        onChanged: (val) {
                          setModalState(() {
                            tempCredits = val;
                          });
                        },
                      ),
                    ),
                    Text(
                      '${tempCredits.round()} CH',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Semesters in Degree:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: tempSemesters.toDouble(),
                        min: 6.0,
                        max: 10.0,
                        divisions: 4,
                        activeColor: _accent,
                        label: '$tempSemesters Semesters',
                        onChanged: (val) {
                          setModalState(() {
                            tempSemesters = val.round();
                          });
                        },
                      ),
                    ),
                    Text(
                      '$tempSemesters Sems',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _totalDegreeCredits = tempCredits;
                    _totalDegreeSemesters = tempSemesters;
                  });
                  Navigator.pop(context);
                  _initData();
                },
                style: FilledButton.styleFrom(backgroundColor: _accent),
                child: const Text('Apply Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final reqFutureSgpa = _requiredAvgFutureSgpa;
    final isPossible = reqFutureSgpa <= 4.0;
    final isChallenging = isPossible && reqFutureSgpa > 3.75;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: inkColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CGPA Roadmap Simulator',
          style: TextStyle(
            color: inkColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Degree Settings',
            icon: Icon(Icons.settings_outlined, color: inkColor),
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Transcript Snapshot Tile
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT TRANSCRIPT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: mutedColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _currentCgpa.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: _accent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CGPA',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: cardBorder,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMPLETED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: mutedColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_completedSemestersCount} / $_totalDegreeSemesters Sems',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: inkColor,
                              ),
                            ),
                            Text(
                              '${_completedCredits.round()} / ${_totalDegreeCredits.round()} CH',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Target CGPA Selector Slider Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target Graduation CGPA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: inkColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _targetCgpa.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _accent,
                            inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            thumbColor: _accent,
                            overlayColor: _accent.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _targetCgpa,
                            min: 2.0,
                            max: 4.0,
                            divisions: 40,
                            onChanged: (val) {
                              setState(() {
                                _targetCgpa = val;
                              });
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('2.00', style: TextStyle(fontSize: 11, color: mutedColor)),
                            Text('3.00', style: TextStyle(fontSize: 11, color: mutedColor)),
                            Text('4.00', style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Feasibility Analysis Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !isPossible
                          ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2))
                          : (isChallenging
                              ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7))
                              : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFD1FAE5))),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !isPossible
                            ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                            : (isChallenging
                                ? (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A))
                                : (isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0))),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          !isPossible
                              ? Icons.cancel_outlined
                              : (isChallenging ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
                          color: !isPossible
                              ? const Color(0xFFEF4444)
                              : (isChallenging ? const Color(0xFFD97706) : const Color(0xFF10B981)),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                !isPossible
                                    ? 'MATHEMATICALLY UNATTAINABLE'
                                    : (isChallenging ? 'HIGH EFFORT REQUIRED' : 'ON TRACK TO TARGET'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: !isPossible
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                      : (isChallenging
                                          ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))
                                          : (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                !isPossible
                                    ? 'Even with 4.00 SGPA in all remaining semesters, your maximum achievable CGPA is ${_maxAchievableCgpa.toStringAsFixed(2)}.'
                                    : 'You need an average SGPA of ${reqFutureSgpa.toStringAsFixed(2)} across the remaining $_remainingSemestersCount semester${_remainingSemestersCount == 1 ? "" : "s"}.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Interactive Per-Semester Roadmap Sliders Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Future Semesters Roadmap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                          Text(
                            'Simulate expected SGPA per semester',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Text(
                          'Projected: ${_projectedFinalCgpa.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // List of sliders for future semesters
                  if (_futureSemesterSgpas.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        '🎉 You have completed all semesters of your degree!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedColor, fontSize: 13),
                      ),
                    )
                  else
                    Column(
                      children: _futureSemesterSgpas.entries.map((entry) {
                        final semNum = entry.key;
                        final sgpa = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Semester $semNum Expected SGPA',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: inkColor,
                                    ),
                                  ),
                                  Text(
                                    sgpa.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _accent,
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: _accent,
                                  inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  thumbColor: _accent,
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: sgpa,
                                  min: 0.0,
                                  max: 4.0,
                                  divisions: 40,
                                  onChanged: (val) {
                                    setState(() {
                                      _futureSemesterSgpas[semNum] = double.parse(val.toStringAsFixed(2));
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
