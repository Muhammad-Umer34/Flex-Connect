import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../../services/datesheet_parser.dart';
import '../../services/datesheet_storage.dart';
import '../../services/home_widget_service.dart';
import '../../services/transcript_storage.dart';
import '../../widgets/custom_toast.dart';
import '../../utils/calendar_utils.dart';

class DatesheetScreen extends StatefulWidget {
  const DatesheetScreen({super.key});

  @override
  State<DatesheetScreen> createState() => _DatesheetScreenState();
}

class _DatesheetScreenState extends State<DatesheetScreen> {
  Uint8List? _fileBytes;
  String? _fileName;

  List<DatesheetEvent>? _events;
  bool _isLoading = false;
  String? _error;
  String _activeFilter = 'All'; // 'All', 'Theory', 'Lab'

  final GlobalKey _tableBoundaryKey = GlobalKey();

  static const Color _accent = Color(0xFF059669); // Emerald Green
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  @override
  void initState() {
    super.initState();
    _loadSavedDatesheet();
  }

  Future<void> _loadSavedDatesheet() async {
    final events = await DatesheetStorage.load();
    if (events != null && mounted) {
      setState(() {
        _events = events;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;

        // On mobile, bytes might be null. Try reading path if available
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          setState(() {
            _fileBytes = bytes;
            _fileName = file.name;
            _error = null;
          });
        } else {
          setState(() {
            _error = 'Could not read file contents. Please try again.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking file: $e';
      });
    }
  }

  void _clearFile() {
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _error = null;
    });
  }

  Future<void> _generateDatesheet() async {
    if (_fileBytes == null) {
      setState(() {
        _error = 'Please upload a datesheet Excel file first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transcript = await TranscriptStorage.load();
      if (transcript == null || transcript.semesters.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No transcript data found. Please sync your portal/transcript first.';
        });
        return;
      }

      final latestSemester = transcript.semesters.last;
      final registeredCourses = latestSemester.courses;

      if (registeredCourses.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No registered courses found in your latest semester (${latestSemester.name}).';
        });
        return;
      }

      final parsedEvents = DatesheetParser.parse(
        fileBytes: _fileBytes!,
        registeredCourses: registeredCourses,
      );

      setState(() {
        _events = parsedEvents;
        _isLoading = false;
      });
      
      await DatesheetStorage.save(parsedEvents);
      await HomeWidgetService.updateNextClassWidget();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error processing datesheet: $e';
      });
    }
  }

  void _resetScreen() async {
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _events = null;
      _error = null;
      _activeFilter = 'All';
    });
    
    await DatesheetStorage.clear();
    await HomeWidgetService.updateNextClassWidget();
  }

  String _getMonthAbbr(String dateStr) {
    try {
      final parts = dateStr.trim().split(RegExp(r'[-/\s,]+'));
      if (parts.length >= 2) {
        final month = parts[1];
        if (month.length > 3) {
          return month.substring(0, 3).toUpperCase();
        }
        return month.toUpperCase();
      }
    } catch (_) {}
    return 'EXAM';
  }

  String _getDayNum(String dateStr) {
    try {
      final parts = dateStr.trim().split(RegExp(r'[-/\s,]+'));
      if (parts.isNotEmpty) {
        return parts[0].padLeft(2, '0');
      }
    } catch (_) {}
    return '--';
  }

  String _getYear(String dateStr) {
    try {
      final parts = dateStr.trim().split(RegExp(r'[-/\s,]+'));
      if (parts.length >= 3) {
        return parts[2];
      }
    } catch (_) {}
    return '';
  }

  Future<void> _exportTableToGallery() async {
    try {
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!mounted) return;
      if (!hasAccess) {
        CustomToast.showError(context, 'Gallery save permission is required to download the datesheet.');
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _accent),
                  SizedBox(height: 12),
                  Text('Generating datesheet image...'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final boundary = _tableBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        throw Exception("Could not locate schedule table boundary renderer.");
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.pop(context);
        throw Exception("Failed to extract image byte data.");
      }
      final pngBytes = byteData.buffer.asUint8List();

      if (mounted) Navigator.pop(context);

      await Gal.putImageBytes(pngBytes);

      if (mounted) {
        CustomToast.showSuccess(context, 'Datesheet table saved to your gallery! 📸');
      }
    } catch (e) {
      debugPrint("Export table to gallery error: $e");
      if (mounted) {
        CustomToast.showError(context, 'Failed to save to gallery: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final list = _events ?? [];
    final filteredList = list.where((event) {
      final isLab = event.type == 'LAB';
      if (_activeFilter == 'Theory') return !isLab;
      if (_activeFilter == 'Lab') return isLab;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: _accent),
                        const SizedBox(height: 20),
                        Text(
                          'Matching datesheet with transcript...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : _ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This will only take a moment.',
                          style: TextStyle(color: isDark ? Colors.grey[400] : _muted),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, isDark),
                        const SizedBox(height: 40),
                        _buildTitle(isDark),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _events == null
                              ? _buildUploadView(isDark)
                              : _buildTimelineView(isDark, filteredList),
                        ),
                      ],
                    ),
                  ),
            if (_events != null && _events!.isNotEmpty)
              Positioned(
                left: -9999,
                top: -9999,
                child: RepaintBoundary(
                  key: _tableBoundaryKey,
                  child: _buildExportTableWidget(isDark, list),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : _ink,
              size: 16,
            ),
          ),
        ),
        if (_events != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.calendar_today_rounded, color: isDark ? Colors.grey[400] : _muted),
                tooltip: 'Export to Google Calendar',
                onPressed: _exportToCalendar,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: isDark ? Colors.grey[400] : _muted),
                tooltip: 'Upload New Datesheet',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      title: Text(
                        'Reset Datesheet',
                        style: TextStyle(color: isDark ? Colors.white : _ink),
                      ),
                      content: Text(
                        'Are you sure you want to reset and upload a different datesheet?',
                        style: TextStyle(color: isDark ? Colors.grey[300] : _muted),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.pop(context),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _resetScreen();
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _exportToCalendar() async {
    if (_events == null || _events!.isEmpty) return;

    final icsContent = CalendarUtils.generateDatesheetIcs(_events!);
    await CalendarUtils.exportAndShare(context, icsContent, 'exam_datesheet.ics');
  }

  Widget _buildTitle(bool isDark) {
    final isTimeline = _events != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTimeline ? 'Exam Schedule' : 'Datesheet Matcher',
          style: TextStyle(
            color: isDark ? Colors.white : _ink,
            fontSize: 34,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isTimeline
              ? 'YOUR CHRONOLOGICAL EXAM SCHEDULE'
              : 'EXTRACT INDIVIDUAL DATESHEET FROM EXCEL',
          style: const TextStyle(
            color: _accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadView(bool isDark) {
    final isEnabled = _fileBytes != null;

    return Column(
      key: const ValueKey('upload_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUploadCard(
          isDark: isDark,
          title: 'Datesheet Excel File',
          subtitle: 'Upload the datesheet sheet (.xlsx or .xls) to scan.',
          fileName: _fileName,
          onTap: _pickFile,
          onClear: _clearFile,
          icon: Icons.table_chart_rounded,
          accentColor: _accent,
          bgColor: const Color(0xFFECFDF5),
        ),
        const SizedBox(height: 24),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark ? Colors.grey[400] : _muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The tool scans the uploaded spreadsheet columns, matches course codes/names from your active semester transcript, and builds a personalized exam schedule.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              disabledBackgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              disabledForegroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey[400],
            ),
            onPressed: isEnabled ? _generateDatesheet : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_rounded, size: 20),
                SizedBox(width: 10),
                Text(
                  'Generate Exam Datesheet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required String? fileName,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    final isPicked = fileName != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPicked
              ? accentColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isPicked ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : bgColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Colors.white : accentColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : _ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPicked ? fileName : subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPicked
                              ? accentColor
                              : (isDark ? Colors.grey[400] : _muted),
                          fontSize: 12,
                          fontWeight: isPicked ? FontWeight.w600 : FontWeight.normal,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isPicked)
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                    onPressed: onClear,
                  )
                else
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineView(bool isDark, List<DatesheetEvent> filteredList) {
    return Column(
      key: const ValueKey('timeline_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildTabsFilter(isDark)),
            if (filteredList.isNotEmpty) ...[
              const SizedBox(width: 12),
              Ink(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: _exportTableToGallery,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: isDark ? Colors.white : _ink,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Download Table',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        if (filteredList.isEmpty) ...[
          _buildEmptyTimelineState(isDark),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              return _buildTimelineCard(context, filteredList[index], isDark);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTabsFilter(bool isDark) {
    final tabs = ['All', 'Theory', 'Lab'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeFilter == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.white : _ink)
                        : (isDark ? Colors.grey[400] : _muted),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyTimelineState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Matches Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No matches were found for the $_activeFilter courses filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, DatesheetEvent event, bool isDark) {
    final isLab = event.type == 'LAB';
    final accentColor = isLab ? const Color(0xFF0D9488) : const Color(0xFF4F46E5);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final monthAbbr = _getMonthAbbr(event.date);
    final dayNum = _getDayNum(event.date);
    final year = _getYear(event.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthAbbr,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayNum,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _ink,
                      ),
                    ),
                    if (year.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        year,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.grey[500] : _muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLab ? 'LAB' : 'THEORY',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                        Text(
                          event.day,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : _muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      event.courseName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[500] : _muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Code: ${event.courseCode}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.groups_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[500] : _muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sec: ${event.section}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          event.time,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : _ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportTableWidget(bool isDark, List<DatesheetEvent> events) {
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : _ink;
    final subtitleColor = isDark ? Colors.grey[400] : _muted;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      width: 1000,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLEX CONNECT',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OFFICIAL EXAM DATESHEET',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Generated on',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateTime.now().toString().substring(0, 16),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.6), // Date
                  1: FlexColumnWidth(1.4), // Day
                  2: FlexColumnWidth(1.6), // Time
                  3: FlexColumnWidth(1.4), // Code
                  4: FlexColumnWidth(3.0), // Subject Name
                  5: FlexColumnWidth(1.0), // Sec
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: headerBg,
                    ),
                    children: [
                      _buildTableHeaderCell('DATE', isDark),
                      _buildTableHeaderCell('DAY', isDark),
                      _buildTableHeaderCell('TIME', isDark),
                      _buildTableHeaderCell('CODE', isDark),
                      _buildTableHeaderCell('COURSE / TYPE', isDark),
                      _buildTableHeaderCell('SEC', isDark),
                    ],
                  ),
                  ...events.asMap().entries.map((entry) {
                    final index = entry.key;
                    final event = entry.value;
                    final isEven = index % 2 == 0;
                    final rowBg = isEven 
                        ? Colors.transparent 
                        : (isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC));

                    return TableRow(
                      decoration: BoxDecoration(
                        color: rowBg,
                        border: Border(
                          bottom: BorderSide(
                            color: borderColor,
                            width: index == events.length - 1 ? 0 : 1.0,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.date,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.day,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.time,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.courseCode,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  event.courseName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildTypeBadge(event.type),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.section,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Flex Connect Utility System - Keep track of your exam schedules efficiently.',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.grey[350] : const Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final isLab = type == 'LAB';
    final color = isLab ? const Color(0xFF0D9488) : const Color(0xFF4F46E5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
