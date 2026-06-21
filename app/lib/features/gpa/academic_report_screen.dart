import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/transcript_models.dart';

class AcademicReportScreen extends StatefulWidget {
  final TranscriptSnapshot snapshot;
  final int selectedSemesterIndex;
  final List<String?> selectedGrades;

  const AcademicReportScreen({
    super.key,
    required this.snapshot,
    required this.selectedSemesterIndex,
    required this.selectedGrades,
  });

  @override
  State<AcademicReportScreen> createState() => _AcademicReportScreenState();
}

class _AcademicReportScreenState extends State<AcademicReportScreen> {
  // Grading standard definitions
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

  // State variables for calculated stats
  double _cumulativeGpa = 0.0;
  double _totalCreditsEarned = 0.0;
  double _degreeCompletionPercent = 0.0;
  double _gpaChange = 0.0;
  bool _hasPrevSemester = false;

  final Map<String, int> _gradeDistribution = {
    'A': 0,
    'B': 0,
    'C': 0,
    'D': 0,
    'F': 0,
  };

  // Processed data lists for trend & breakdown
  final List<_SemesterReportData> _semestersData = [];

  @override
  void initState() {
    super.initState();
    _calculateStatistics();
  }

  void _calculateStatistics() {
    final snapshot = widget.snapshot;
    if (snapshot.semesters.isEmpty) return;

    var overallTotalQP = 0.0;
    var overallTotalCreditsAttempted = 0.0;
    var overallTotalCreditsEarned = 0.0;

    // Reset grade distributions
    _gradeDistribution.updateAll((key, value) => 0);

    // Helpers to parse course values
    double parseCredits(String creditHours) =>
        double.tryParse(creditHours.trim()) ?? 0.0;

    double? getGradePoint(String? grade) {
      if (grade == null) return null;
      final normalized = grade
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .toUpperCase()
          .trim();
      return _gradePoints[normalized];
    }

    bool isPassing(String? grade) {
      if (grade == null) return false;
      final normalized = grade
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .toUpperCase()
          .trim();
      if (normalized == 'F' || !_gradePoints.containsKey(normalized))
        return false;
      return true;
    }

    // 1. Process each semester (chronologically)
    for (int semIdx = 0; semIdx < snapshot.semesters.length; semIdx++) {
      final semester = snapshot.semesters[semIdx];
      final isCurrent = semIdx == widget.selectedSemesterIndex;

      var semQualityPoints = 0.0;
      var semCreditsAttempted = 0.0;
      var semCreditsEarned = 0.0;
      var semCoursesCount = 0;

      for (
        int courseIdx = 0;
        courseIdx < semester.courses.length;
        courseIdx++
      ) {
        final course = semester.courses[courseIdx];
        final credits = parseCredits(course.creditHours);
        if (credits <= 0.0) continue;

        // Use selected grades for the active semester, otherwise original grades
        final grade = isCurrent && courseIdx < widget.selectedGrades.length
            ? widget.selectedGrades[courseIdx]
            : course.grade;

        final gradePoint = getGradePoint(grade);
        if (gradePoint == null) continue; // Skip if ungraded

        semQualityPoints += credits * gradePoint;
        semCreditsAttempted += credits;
        semCoursesCount++;

        if (isPassing(grade)) {
          semCreditsEarned += credits;
        }

        // Count grade distribution
        final normalized = grade!
            .replaceAll(' ', '')
            .replaceAll('.', '')
            .toUpperCase()
            .trim();
        if (normalized.startsWith('A')) {
          _gradeDistribution['A'] = (_gradeDistribution['A'] ?? 0) + 1;
        } else if (normalized.startsWith('B')) {
          _gradeDistribution['B'] = (_gradeDistribution['B'] ?? 0) + 1;
        } else if (normalized.startsWith('C')) {
          _gradeDistribution['C'] = (_gradeDistribution['C'] ?? 0) + 1;
        } else if (normalized.startsWith('D')) {
          _gradeDistribution['D'] = (_gradeDistribution['D'] ?? 0) + 1;
        } else if (normalized == 'F') {
          _gradeDistribution['F'] = (_gradeDistribution['F'] ?? 0) + 1;
        }
      }

      final semGpa = semCreditsAttempted > 0.0
          ? semQualityPoints / semCreditsAttempted
          : 0.0;

      overallTotalQP += semQualityPoints;
      overallTotalCreditsAttempted += semCreditsAttempted;
      overallTotalCreditsEarned += semCreditsEarned;

      _semestersData.add(
        _SemesterReportData(
          name: semester.name,
          gpa: semGpa,
          creditsEarned: semCreditsEarned,
          coursesCount: semCoursesCount,
        ),
      );
    }

    // 2. Compute final cumulative stats
    _cumulativeGpa = overallTotalCreditsAttempted > 0.0
        ? overallTotalQP / overallTotalCreditsAttempted
        : 0.0;

    _totalCreditsEarned = overallTotalCreditsEarned;
    // Standard degree completion requirement of 130 credits
    _degreeCompletionPercent = (_totalCreditsEarned / 130.0).clamp(0.0, 1.0);

    // 3. Compute GPA Change from previous semester (if any)
    if (widget.selectedSemesterIndex > 0) {
      _hasPrevSemester = true;
      var prevQP = 0.0;
      var prevCredits = 0.0;

      for (int semIdx = 0; semIdx < widget.selectedSemesterIndex; semIdx++) {
        final semester = snapshot.semesters[semIdx];
        for (final course in semester.courses) {
          final credits = parseCredits(course.creditHours);
          final gp = getGradePoint(course.grade);
          if (credits > 0 && gp != null) {
            prevQP += credits * gp;
            prevCredits += credits;
          }
        }
      }
      final prevCgpa = prevCredits > 0.0 ? prevQP / prevCredits : 0.0;
      _gpaChange = _cumulativeGpa - prevCgpa;
    } else {
      _hasPrevSemester = false;
      _gpaChange = 0.0;
    }
  }

  Future<void> _downloadPdfReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
                SizedBox(height: 20),
                Text(
                  'Generating PDF Report...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Compiling academic index records',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final pdf = _buildPdfDocument();
      final pdfBytes = await pdf.save();

      if (mounted) Navigator.of(context).pop();

      final outputFilePath = await FilePicker.saveFile(
        dialogTitle: 'Save Academic Report PDF',
        fileName: 'Academic_Report.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (outputFilePath != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Academic_Report.pdf saved successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Document _buildPdfDocument() {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
    );
    final subtitleStyle = pw.TextStyle(
      fontSize: 14,
      color: PdfColors.grey700,
    );
    final sectionHeaderStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue800,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
    );
    final labelStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey600);
    final cellHeaderStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final cellStyle = pw.TextStyle(fontSize: 10);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text('Academic Performance Report', style: titleStyle),
            pw.SizedBox(height: 8),
            pw.Text(
              'Confidential institutional record of transcript evaluations.',
              style: subtitleStyle,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
              style: labelStyle,
            ),
            pw.Divider(color: PdfColors.grey300, thickness: 1, height: 24),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CUMULATIVE GPA', style: labelStyle),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _cumulativeGpa.toStringAsFixed(2),
                      style: valueStyle,
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TOTAL CREDITS EARNED', style: labelStyle),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _totalCreditsEarned.toStringAsFixed(1),
                      style: valueStyle,
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey300, thickness: 1, height: 24),

            pw.Text('GRADE DISTRIBUTION', style: sectionHeaderStyle),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: _gradeDistribution.entries.map((entry) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(entry.key, style: cellHeaderStyle),
                      pw.SizedBox(height: 4),
                      pw.Text(entry.value.toString(), style: cellStyle),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.Divider(color: PdfColors.grey300, thickness: 1, height: 24),

            pw.Text('SEMESTER BREAKDOWN', style: sectionHeaderStyle),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Semester Name', style: cellHeaderStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Credits Earned',
                        style: cellHeaderStyle,
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Courses Count',
                        style: cellHeaderStyle,
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'SGPA',
                        style: cellHeaderStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ..._semestersData.map((data) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(data.name, style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          data.creditsEarned.toStringAsFixed(1),
                          style: cellStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          data.coursesCount.toString(),
                          style: cellStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          data.gpa.toStringAsFixed(2),
                          style: cellStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> _sharePdfReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
                SizedBox(height: 20),
                Text(
                  'Generating PDF Report...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Compiling academic index records',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final pdf = _buildPdfDocument();
      final pdfBytes = await pdf.save();

      if (mounted) Navigator.of(context).pop();

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Academic_Report.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'Academic Performance Report',
          text: 'Here is my Academic Performance Report.',
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final snapshot = widget.snapshot;
    String periodText = 'Confidential institutional record.';
    if (snapshot.semesters.isNotEmpty) {
      final first = snapshot.semesters.first.name.trim();
      final last = snapshot.semesters.last.name.trim();
      if (first == last) {
        periodText = 'Confidential institutional record for the period of $first.';
      } else {
        periodText = 'Confidential institutional record for the period of $first to $last.';
      }
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFCFCFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Academic Report',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Performance\nReport',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              periodText,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Card 1: Cumulative GPA
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CUMULATIVE GPA',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _cumulativeGpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGpaComparisonWidget(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Total Credits Earned
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL CREDITS EARNED',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _totalCreditsEarned.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _degreeCompletionPercent,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_degreeCompletionPercent * 100).toStringAsFixed(0)}% of Degree Completion',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Grade Distribution
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GRADE DISTRIBUTION',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildGradeDistBar(
                    'A',
                    _gradeDistribution['A'] ?? 0,
                    const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),
                  _buildGradeDistBar(
                    'B',
                    _gradeDistribution['B'] ?? 0,
                    const Color(0xFF334155),
                  ),
                  const SizedBox(height: 12),
                  _buildGradeDistBar(
                    'C',
                    _gradeDistribution['C'] ?? 0,
                    const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 12),
                  _buildGradeDistBar(
                    'D',
                    _gradeDistribution['D'] ?? 0,
                    const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 12),
                  _buildGradeDistBar(
                    'F',
                    _gradeDistribution['F'] ?? 0,
                    const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: GPA Trend
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'GPA TREND',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SGPA',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildGpaTrendChart(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: Semester Breakdown
            _buildReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SEMESTER BREAKDOWN',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _semestersData.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(
                        color: const Color(0xFFE2E8F0).withOpacity(0.5),
                        height: 1,
                      ),
                    ),
                    itemBuilder: (context, idx) {
                      // Show latest semesters first to match layout
                      final data =
                          _semestersData[_semestersData.length - 1 - idx];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.name,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.creditsEarned.toStringAsFixed(1)} Credits • ${data.coursesCount} Courses',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${data.gpa.toStringAsFixed(2)} SGPA',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Action Button 1: Download PDF
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _downloadPdfReport,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text(
                  'Download PDF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Action Button 2: Share Report
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _sharePdfReport,
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text(
                  'Share Report',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: child,
    );
  }

  Widget _buildGpaComparisonWidget() {
    if (!_hasPrevSemester) {
      return Row(
        children: const [
          Icon(Icons.trending_up, color: Color(0xFF6B7280), size: 14),
          SizedBox(width: 6),
          Text(
            'First semester baseline',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final isPositive = _gpaChange > 0.0;
    final isNegative = _gpaChange < 0.0;
    final absDiffStr = _gpaChange.abs().toStringAsFixed(2);

    return Row(
      children: [
        Icon(
          isPositive
              ? Icons.trending_up_rounded
              : (isNegative
                    ? Icons.trending_down_rounded
                    : Icons.trending_flat_rounded),
          color: isPositive
              ? const Color(0xFF10B981)
              : (isNegative
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF6B7280)),
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          isPositive
              ? '+$absDiffStr from prev. semester'
              : (isNegative
                    ? '-$absDiffStr from prev. semester'
                    : 'No change from prev. semester'),
          style: TextStyle(
            color: isPositive
                ? const Color(0xFF10B981)
                : (isNegative
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF6B7280)),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGradeDistBar(String label, int count, Color color) {
    // Find the max count across all grades for relative width scaling
    final maxCount = _gradeDistribution.values.fold<int>(
      1,
      (max, val) => val > max ? val : max,
    );
    final widthRatio = count / maxCount;

    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            alignment: Alignment.centerLeft,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: widthRatio.clamp(0.01, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 20,
          child: Text(
            count.toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpaTrendChart() {
    // Premium custom bar-chart styled widget
    if (_semestersData.isEmpty) return const SizedBox.shrink();

    // Find the max GPA for height scaling (usually capped at 4.0)
    const maxGpa = 4.0;

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _semestersData.map((data) {
          final heightRatio = data.gpa / maxGpa;

          // Truncate name like "Spring 2026" to "Spring 26" or "Fall 2024" to "Fall 24"
          String shortName = data.name;
          if (data.name.contains(' ')) {
            final parts = data.name.split(' ');
            if (parts.length == 2 && parts[1].length == 4) {
              shortName = '${parts[0]} ${parts[1].substring(2)}';
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                data.gpa.toStringAsFixed(2),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: heightRatio.clamp(0.01, 1.0),
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                shortName,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SemesterReportData {
  final String name;
  final double gpa;
  final double creditsEarned;
  final int coursesCount;

  _SemesterReportData({
    required this.name,
    required this.gpa,
    required this.creditsEarned,
    required this.coursesCount,
  });
}
