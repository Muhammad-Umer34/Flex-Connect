import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../../models/timetable_models.dart';
import '../../services/pdf_schedule_parser.dart';
import '../../services/transcript_storage.dart';
import '../../widgets/custom_toast.dart';

class RecheckingScheduleScreen extends StatefulWidget {
  const RecheckingScheduleScreen({super.key});

  @override
  State<RecheckingScheduleScreen> createState() => _RecheckingScheduleScreenState();
}

class _RecheckingScheduleScreenState extends State<RecheckingScheduleScreen> {
  final GlobalKey _tableBoundaryKey = GlobalKey();
  Uint8List? _coursePdfBytes;
  String? _coursePdfName;
  Uint8List? _labPdfBytes;
  String? _labPdfName;

  List<TimetableDayEvent>? _events;
  bool _isLoading = false;
  String? _error;
  String _activeFilter = 'All'; // 'All', 'Theory', 'Lab'

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  Future<void> _pickFile(bool isLab) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
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
            if (isLab) {
              _labPdfBytes = bytes;
              _labPdfName = file.name;
            } else {
              _coursePdfBytes = bytes;
              _coursePdfName = file.name;
            }
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

  void _clearFile(bool isLab) {
    setState(() {
      if (isLab) {
        _labPdfBytes = null;
        _labPdfName = null;
      } else {
        _coursePdfBytes = null;
        _coursePdfName = null;
      }
      _error = null;
    });
  }

  Future<void> _generateSchedule() async {
    if (_coursePdfBytes == null && _labPdfBytes == null) {
      setState(() {
        _error = 'Please upload at least one PDF schedule first.';
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

      final List<TimetableDayEvent> parsedEvents = [];

      if (_coursePdfBytes != null) {
        final courseEvents = PdfScheduleParser.parse(
          pdfBytes: _coursePdfBytes!,
          registeredCourses: registeredCourses,
        );
        parsedEvents.addAll(courseEvents);
      }

      if (_labPdfBytes != null) {
        final labEvents = PdfScheduleParser.parse(
          pdfBytes: _labPdfBytes!,
          registeredCourses: registeredCourses,
        );
        parsedEvents.addAll(labEvents);
      }

      // De-duplicate final list by day, time, course, and room
      final Map<String, TimetableDayEvent> uniqueMap = {};
      for (final e in parsedEvents) {
        final key = '${e.day}_${e.time}_${e.course}_${e.room}';
        uniqueMap[key] = e;
      }
      final uniqueEvents = uniqueMap.values.toList();

      // Sort chronologically using our helpers
      uniqueEvents.sort((a, b) {
        final dateA = _parseDateString(a.day);
        final dateB = _parseDateString(b.day);
        final dateCompare = dateA.compareTo(dateB);
        if (dateCompare != 0) return dateCompare;

        final timeA = _parseStartTimeMinutes(a.time);
        final timeB = _parseStartTimeMinutes(b.time);
        return timeA.compareTo(timeB);
      });

      setState(() {
        _events = uniqueEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error processing PDF: $e';
      });
    }
  }

  DateTime _parseDateString(String dayStr) {
    try {
      final datePart = dayStr.split('|').first.trim();
      final parts = datePart.split(RegExp(r'[\s,]+'));
      if (parts.length >= 4) {
        final day = int.tryParse(parts[1]) ?? 1;
        final monthName = parts[2].toLowerCase();
        final year = int.tryParse(parts[3]) ?? DateTime.now().year;

        const months = {
          'jan': 1, 'january': 1,
          'feb': 2, 'february': 2,
          'mar': 3, 'march': 3,
          'apr': 4, 'april': 4,
          'may': 5,
          'jun': 6, 'june': 6,
          'jul': 7, 'july': 7,
          'aug': 8, 'august': 8,
          'sep': 9, 'september': 9,
          'oct': 10, 'october': 10,
          'nov': 11, 'november': 11,
          'dec': 12, 'december': 12,
        };

        final month = months[monthName] ?? 1;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime(2099, 12, 31);
  }

  int _parseStartTimeMinutes(String timeStr) {
    try {
      final startPart = timeStr.split('-').first.trim();
      final isPM = timeStr.toLowerCase().contains('pm') && !startPart.toLowerCase().contains('am');
      final timeParts = startPart.split(':');
      if (timeParts.length == 2) {
        int hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        return hour * 60 + minute;
      }
    } catch (_) {}
    return 0;
  }

  String _getMonthAbbr(String dayStr) {
    try {
      final datePart = dayStr.split('|').first.trim();
      final parts = datePart.split(RegExp(r'[\s,]+'));
      if (parts.length >= 3) {
        final month = parts[2];
        if (month.length > 3) {
          return month.substring(0, 3).toUpperCase();
        }
        return month.toUpperCase();
      }
    } catch (_) {}
    return 'EXAM';
  }

  String _getDayNum(String dayStr) {
    try {
      final datePart = dayStr.split('|').first.trim();
      final parts = datePart.split(RegExp(r'[\s,]+'));
      if (parts.length >= 2) {
        return parts[1].padLeft(2, '0');
      }
    } catch (_) {}
    return '--';
  }

  String _getYear(String dayStr) {
    try {
      final datePart = dayStr.split('|').first.trim();
      final parts = datePart.split(RegExp(r'[\s,]+'));
      if (parts.length >= 4) {
        return parts[3];
      }
    } catch (_) {}
    return '';
  }

  String _getDayName(String dayStr) {
    try {
      final datePart = dayStr.split('|').first.trim();
      final parts = datePart.split(RegExp(r'[\s,]+'));
      if (parts.isNotEmpty) {
        return parts[0];
      }
    } catch (_) {}
    return dayStr.split('|').first;
  }

  void _resetScreen() {
    setState(() {
      _coursePdfBytes = null;
      _coursePdfName = null;
      _labPdfBytes = null;
      _labPdfName = null;
      _events = null;
      _error = null;
      _activeFilter = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final list = _events ?? [];

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
                          'Matching schedule with transcript...',
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
                              : _buildTimelineView(isDark),
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
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.grey[400] : _muted),
            tooltip: 'Upload New PDFs',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  title: Text(
                    'Reset Extractor',
                    style: TextStyle(color: isDark ? Colors.white : _ink),
                  ),
                  content: Text(
                    'Are you sure you want to reset and upload different schedules?',
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
    );
  }

  Widget _buildTitle(bool isDark) {
    final isTimeline = _events != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTimeline ? 'Rechecking Slots' : 'Rechecking Extractor',
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
              ? 'MATCHED CHRONOLOGICAL TIMELINE'
              : 'EXTRACT INDIVIDUAL SCHEDULES FROM PDF',
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

  Widget _buildUploadView(bool isDark) {
    final isEnabled = _coursePdfBytes != null || _labPdfBytes != null;

    return Column(
      key: const ValueKey('upload_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Course Card
        _buildUploadCard(
          isDark: isDark,
          title: 'Course Rechecking PDF',
          subtitle: 'Upload the theory rechecking schedule document.',
          fileName: _coursePdfName,
          onTap: () => _pickFile(false),
          onClear: () => _clearFile(false),
          icon: Icons.menu_book_rounded,
          accentColor: const Color(0xFF4F46E5),
          bgColor: const Color(0xFFEEF2FF),
        ),
        const SizedBox(height: 16),

        // Lab Card
        _buildUploadCard(
          isDark: isDark,
          title: 'Lab Rechecking PDF',
          subtitle: 'Upload the laboratory rechecking schedule document.',
          fileName: _labPdfName,
          onTap: () => _pickFile(true),
          onClear: () => _clearFile(true),
          icon: Icons.biotech_rounded,
          accentColor: const Color(0xFF0D9488),
          bgColor: const Color(0xFFF0FDFA),
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

        // Instructions note
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
                  'The extractor matches course codes/names from the latest semester of your synced transcript with entries inside the uploaded PDFs. Please make sure your transcript was imported correctly.',
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

        // Action button
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
            onPressed: isEnabled ? _generateSchedule : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_rounded, size: 20),
                SizedBox(width: 10),
                Text(
                  'Extract Rechecking Schedule',
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
                // Icon block
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

                // Text details
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

                // Button state action
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

  Widget _buildTimelineView(bool isDark) {
    final list = _events ?? [];

    // Filter items based on active tab
    final filteredList = list.where((event) {
      final isLab = event.course.toLowerCase().contains('lab') ||
          event.course.toLowerCase().contains('laboratory') ||
          event.room.toLowerCase().contains('lab');
      if (_activeFilter == 'Theory') return !isLab;
      if (_activeFilter == 'Lab') return isLab;
      return true;
    }).toList();

    return Column(
      key: const ValueKey('timeline_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs selector & Download button
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
            Icons.calendar_today_rounded,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Rechecking Schedule Matches',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No matching courses were found for the $_activeFilter filter.',
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

  Widget _buildTimelineCard(BuildContext context, TimetableDayEvent event, bool isDark) {
    final isLab = event.course.toLowerCase().contains('lab') ||
        event.course.toLowerCase().contains('laboratory') ||
        event.room.toLowerCase().contains('lab');

    final dayParts = event.day.split('|');
    final showingDate = dayParts[0];
    final examDate = dayParts.length > 1 ? dayParts[1] : null;

    final monthAbbr = _getMonthAbbr(showingDate);
    final dayNum = _getDayNum(showingDate);
    final year = _getYear(showingDate);
    final dayName = _getDayName(showingDate);

    final accentColor = isLab ? const Color(0xFF0D9488) : const Color(0xFF4F46E5);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Date Badge
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

                  // Right side: Event Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course type badge and code
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isLab
                                    ? const Color(0xFF0D9488).withValues(alpha: 0.1)
                                    : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isLab ? 'LAB' : 'THEORY',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isLab
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            Text(
                              dayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : _muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Course Title
                        Text(
                          event.course,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : _ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section and Teacher info
                        Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 14,
                              color: isDark ? Colors.grey[500] : _muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Section: ${event.originalSection.isNotEmpty ? event.originalSection : event.section}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 14,
                              color: isDark ? Colors.grey[500] : _muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              event.teacher,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 8),

                        // Venue and Time Details
                        Row(
                          children: [
                            Expanded(
                              child: Row(
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  size: 13,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  event.room,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : _ink,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (examDate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.15)
                      : const Color(0xFFEFF6FF),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : const Color(0xFFBFDBFE),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                          ),
                          children: [
                            const TextSpan(
                              text: 'Original Exam Date: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: examDate),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTableWidget(bool isDark, List<TimetableDayEvent> events) {
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
          // Header Section
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
                    'EXAM RECHECKING SCHEDULE',
                    style: const TextStyle(
                      color: Color(0xFFB45309), // Amber-orange highlight
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

          // Schedule Table
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
                  1: FlexColumnWidth(1.5), // Time
                  2: FlexColumnWidth(3.2), // Course Info
                  3: FlexColumnWidth(1.3), // Venue
                  4: FlexColumnWidth(1.8), // Original Exam
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Table Header Row
                  TableRow(
                    decoration: BoxDecoration(
                      color: headerBg,
                    ),
                    children: [
                      _buildTableHeaderCell('DATE', isDark),
                      _buildTableHeaderCell('TIME', isDark),
                      _buildTableHeaderCell('COURSE / DETAILS', isDark),
                      _buildTableHeaderCell('VENUE', isDark),
                      _buildTableHeaderCell('ORIGINAL EXAM', isDark),
                    ],
                  ),
                  // Table Body Rows
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
                        // Date Column
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getDayName(event.day.split('|')[0]),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_getDayNum(event.day.split('|')[0])} ${_getMonthAbbr(event.day.split('|')[0])} ${_getYear(event.day.split('|')[0])}',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Time Column
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.time,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Course & Teacher
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      event.course,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTypeBadge(event.course, event.room),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sec: ${event.originalSection.isNotEmpty ? event.originalSection : event.section}  •  ${event.teacher}',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Venue
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event.room,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Original Exam
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Text(
                            event.day.split('|').length > 1 ? event.day.split('|')[1].trim() : 'N/A',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
          const SizedBox(height: 24),
          // Footer
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

  Widget _buildTypeBadge(String courseName, String roomName) {
    final isLab = courseName.toLowerCase().contains('lab') ||
        courseName.toLowerCase().contains('laboratory') ||
        roomName.toLowerCase().contains('lab');

    final color = isLab ? const Color(0xFF0D9488) : const Color(0xFF4F46E5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isLab ? 'LAB' : 'THEORY',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _exportTableToGallery() async {
    try {
      // Check for permission first
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!mounted) return;
      if (!hasAccess) {
        CustomToast.showError(context, 'Gallery save permission is required to download the schedule.');
        return;
      }

      // Show progress dialog
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
                  Text('Generating schedule image...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Delay to ensure the repaint boundary is rendered
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

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Save to gallery
      await Gal.putImageBytes(pngBytes);

      if (mounted) {
        CustomToast.showSuccess(context, 'Rechecking schedule table saved to your gallery! 📸');
      }
    } catch (e) {
      debugPrint("Export table to gallery error: $e");
      if (mounted) {
        CustomToast.showError(context, 'Failed to save to gallery: $e');
      }
    }
  }
}
