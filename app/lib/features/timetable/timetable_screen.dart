import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/timetable_models.dart';
import '../../services/timetable_parser.dart';
import '../../services/timetable_storage.dart';
import '../../services/home_widget_service.dart';
import '../../widgets/custom_toast.dart';
import 'utils/timetable_utils.dart';
import 'widgets/timetable_setup_wizard.dart';
import 'widgets/timetable_grid_view.dart';
import 'widgets/timetable_planner_view.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  // Wizard steps: 1 = Config/Upload, 4 = Timetable View
  int _step = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Configuration State
  Uint8List? _selectedBytes;
  String? _selectedFileName;
  final TextEditingController _sectionInputController = TextEditingController();

  // Parsed Response State
  TimetableSnapshot? _snapshot;
  String? _selectedDept;
  String? _selectedSection;



  // Custom Timetable States
  List<TimetableDayEvent> _customEvents = [];
  int _activeTab = 0; // 0 = Grid, 1 = Planner
  final GlobalKey _gridBoundaryKey = GlobalKey();

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  static const Map<String, String> _deptMapping = {
    'BCS': 'CS',
    'BSE': 'SE',
    'BAI': 'AI',
    'BDS': 'DS',
    'BSD': 'DS',
    'BCY': 'CY',
    'BBA': 'BA',
    'BFT': 'FT',
    'BS': 'CS',
    'MCS': 'CS',
    'MS': 'MS',
    'MSP': 'MS',
    'MCY': 'CY',
    'MDS': 'DS',
    'PHD': 'PhD',
  };


  @override
  void initState() {
    super.initState();
    _loadStoredTimetable();
  }

  @override
  void dispose() {
    _sectionInputController.dispose();
    super.dispose();
  }






  Future<void> _loadStoredTimetable() async {
    setState(() => _isLoading = true);
    final snapshot = await TimetableStorage.load();
    final dept = await TimetableStorage.loadSelectedDept();
    final section = await TimetableStorage.loadSelectedSection();
    final customEvents = await TimetableStorage.loadCustomEvents();

    if (snapshot != null && dept != null && section != null) {
      setState(() {
        _snapshot = snapshot;
        _selectedDept = dept;
        _selectedSection = section;
        _customEvents = customEvents;
        _step = 4;
        _isLoading = false;
      });
      _sectionInputController.text = section;
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _parseSectionInput(String input) {
    final cleanInput = input.trim().replaceAll(' ', '').toUpperCase();
    final regex = RegExp(r'^([A-Za-z]+)-?([0-9]+)([A-Za-z]*[0-9]*)$');
    final match = regex.firstMatch(cleanInput);
    if (match == null) return null;

    final rawDept = match.group(1)!;
    final semesterStr = match.group(2)!;
    final sectionLetter = match.group(3) ?? '';

    final mappedDept = _deptMapping[rawDept] ?? rawDept;
    final semester = int.tryParse(semesterStr) ?? 1;

    return {
      'dept': mappedDept,
      'semester': semester,
      'letter': sectionLetter,
      'canonicalSection': '$mappedDept-$semester$sectionLetter',
    };
  }

  bool _sectionMatches(String eventSection, String targetSection) {
    if (eventSection == targetSection) return true;
    if (eventSection.startsWith(targetSection)) {
      final suffix = eventSection.substring(targetSection.length);
      return RegExp(r'^[0-9]+$').hasMatch(suffix);
    }
    return false;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        Uint8List? fileBytes = result.files.single.bytes;
        
        // On mobile, bytes might be null. Try reading path if available
        if (fileBytes == null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          fileBytes = await file.readAsBytes();
        }

        if (fileBytes != null) {
          setState(() {
            _selectedBytes = fileBytes;
            _selectedFileName = result.files.single.name;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = 'Could not read file contents. Please try again.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _generateTimetable() async {
    if (_selectedBytes == null || _selectedFileName == null) {
      setState(() {
        _errorMessage = 'Please select a timetable Excel file first.';
      });
      return;
    }

    final sectionText = _sectionInputController.text.trim();
    if (sectionText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your section (e.g. BCS-6B).';
      });
      return;
    }

    final parsedSection = _parseSectionInput(sectionText);
    if (parsedSection == null) {
      setState(() {
        _errorMessage = 'Invalid section format. Please enter a format like "BCS-6B".';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('------------------- LOCAL TIMETABLE PARSE -------------------');
      debugPrint('File: $_selectedFileName');
      debugPrint('Section Text: $sectionText');

      // Load user campus and degree dynamically from SharedPreferences
      final preferences = await SharedPreferences.getInstance();
      final campus = preferences.getString('student_campus')?.trim() ?? 'Islamabad';
      final degreeText = (preferences.getString('student_degree') ?? '').toLowerCase();
      final degreeLevel = degreeText.contains('master') || degreeText.contains('ms') || degreeText.contains('phd')
          ? 'masters'
          : 'bachelors';

      debugPrint('Dynamic User Campus: $campus, Degree Level: $degreeLevel');

      final parsedSnapshot = await TimetableParser.parse(
        fileBytes: _selectedBytes!,
        campus: campus,
        degreeLevel: degreeLevel,
      );

      final finalSection = parsedSection['canonicalSection'];
      final dept = parsedSection['dept'];
      final semester = parsedSection['semester'];

      debugPrint('Parsed successfully.');
      debugPrint('Checking for section: $finalSection');

      // Check if section exists in schedule
      final sectionExists = parsedSnapshot.schedule.any((e) => _sectionMatches(e.section, finalSection));

      if (!sectionExists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Section "$sectionText" (parsed as "$finalSection") was not found in the uploaded timetable. Please verify the section code.';
        });
        return;
      }

      final sectionEvents = parsedSnapshot.schedule.where((e) => _sectionMatches(e.section, finalSection)).toList();
      debugPrint('Section events for "$finalSection": ${sectionEvents.length}');
      final coreSectionEvents = sectionEvents.where((e) => _isCoreCourse(e.course, dept, semester, parsedSnapshot)).toList();
      debugPrint('Core section events: ${coreSectionEvents.length}');
      
      final currentCustom = await TimetableStorage.loadCustomEvents();
      final oldSection = await TimetableStorage.loadSelectedSection();
      final hasSectionChanged = oldSection != finalSection;

      final finalEvents = (currentCustom.isNotEmpty && !hasSectionChanged)
          ? currentCustom
          : coreSectionEvents;
      debugPrint('Final events count: ${finalEvents.length} (hasSectionChanged=$hasSectionChanged, currentCustom=${currentCustom.length})');

      setState(() {
        _snapshot = parsedSnapshot;
        _selectedDept = dept;
        _selectedSection = finalSection;
        _customEvents = finalEvents;
        _step = 4;
        _isLoading = false;
      });

      await TimetableStorage.save(parsedSnapshot);
      await TimetableStorage.saveSelectedDept(dept);
      await TimetableStorage.saveSelectedSection(finalSection);
      await TimetableStorage.saveCustomEvents(finalEvents);
      
      // Update next class home screen widget
      await HomeWidgetService.updateNextClassWidget();

      debugPrint('Saved all data to local SharedPreferences successfully.');
      debugPrint('------------------------------------------------------------');
    } catch (e) {
      debugPrint('Parse error: $e');
      debugPrint('------------------------------------------------------------');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error parsing Excel file: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }



  Future<void> _resetTimetable() async {
    await TimetableStorage.clear();
    _sectionInputController.clear();
    setState(() {
      _snapshot = null;
      _selectedDept = null;
      _selectedSection = null;
      _selectedBytes = null;
      _selectedFileName = null;
      _step = 1;
      _errorMessage = null;
    });
  }

  // PDF extract methods removed (moved to dedicated Rechecking Schedule feature)

  Widget _buildAcademicTimetableHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Always show Back/Exit navigation button (pops the screen to return to More)
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
            const SizedBox(width: 12),

            // Show Step-Back button if we are beyond Step 1 (allows stepping back in the wizard)
            if (_step > 1 && _step < 4) ...[
              GestureDetector(
                onTap: () => setState(() => _step--),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? Colors.grey[400] : _muted,
                        size: 16,
                      ),
                      Text(
                        'Prev',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Academic Timetable',
              style: TextStyle(
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (_step == 4)
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.grey[400] : _muted),
            tooltip: 'Upload New Timetable',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  title: Text(
                    'Reset Timetable',
                    style: TextStyle(color: isDark ? Colors.white : _ink),
                  ),
                  content: Text(
                    'Are you sure you want to upload a new Excel file? This will overwrite your current timetable.',
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
                        _resetTimetable();
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

  Widget _buildTitleSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String title = 'Timetable';
    String subtitle = 'STEP 1 OF 2 • CONFIGURE EXCEL';
    
    switch (_step) {
      case 1:
        title = 'Timetable';
        subtitle = 'STEP 1 OF 2 • CONFIGURE EXCEL';
        break;
      case 4:
        title = 'Weekly Planner';
        subtitle = _selectedSection ?? 'ACTIVE SCHEDULE';
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle.toUpperCase(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: _accent),
                    const SizedBox(height: 16),
                    Text(
                      'Processing your spreadsheet...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This might take a moment.',
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
                    _buildAcademicTimetableHeader(context),
                    const SizedBox(height: 48),
                    _buildTitleSection(context),
                    const SizedBox(height: 36),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildStepContent(isDark),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_step) {
      case 1:
        return TimetableSetupWizard(
          sectionInputController: _sectionInputController,
          onPickFile: _pickFile,
          selectedBytes: _selectedBytes,
          selectedFileName: _selectedFileName,
          errorMessage: _errorMessage,
          onGenerateTimetable: _generateTimetable,
        );
      case 4:
        if (_snapshot == null || _selectedSection == null) return const SizedBox.shrink();

        final deptColor = getDeptColor(_selectedDept ?? '');

        return Column(
          key: const ValueKey(4),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection summary card
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : deptColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : deptColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: deptColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school, color: deptColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSection!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${getDeptFullName(_selectedDept ?? '')} • ${_snapshot!.campus}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : _muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sliding Segmented Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 0
                              ? (isDark ? const Color(0xFF334155) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _activeTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Weekly Grid',
                          style: TextStyle(
                            color: _activeTab == 0
                                ? (isDark ? Colors.white : _ink)
                                : (isDark ? const Color(0xFF94A3B8) : _muted),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 1
                              ? (isDark ? const Color(0xFF334155) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _activeTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Customize & Search',
                          style: TextStyle(
                            color: _activeTab == 1
                                ? (isDark ? Colors.white : _ink)
                                : (isDark ? const Color(0xFF94A3B8) : _muted),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            _activeTab == 0
                ? TimetableGridView(
                    customEvents: _customEvents,
                    gridBoundaryKey: _gridBoundaryKey,
                    selectedSection: _selectedSection,
                    snapshot: _snapshot,
                    onExportGridToGallery: _exportGridToGallery,
                    onEventPressed: (event) => _showEventDetailsBottomSheet(event, isDark),
                  )
                : TimetablePlannerView(
                    selectedDept: _selectedDept,
                    snapshot: _snapshot,
                    selectedSection: _selectedSection,
                    customEvents: _customEvents,
                    onAddCourse: _addCourse,
                    onRemoveCourse: _removeCourse,
                    onChangeCourseSection: _changeCourseSection,
                    isCourseSelected: _isCourseSelected,
                    getSelectedSectionForCourse: _getSelectedSectionForCourse,
                    getAvailableSectionsForCourse: _getAvailableSectionsForCourse,
                    doesSectionClashWithTimetable: _doesSectionClashWithTimetable,
                    sectionMatches: _sectionMatches,
                    formatCourseEventsSubtitle: _formatCourseEventsSubtitle,
                  ),
          ],
        );
      default:
        return TimetableSetupWizard(
          sectionInputController: _sectionInputController,
          onPickFile: _pickFile,
          selectedBytes: _selectedBytes,
          selectedFileName: _selectedFileName,
          errorMessage: _errorMessage,
          onGenerateTimetable: _generateTimetable,
        );
    }
  }

  void _showEventDetailsBottomSheet(TimetableDayEvent event, bool isDark) {
    final deptColor = getDeptColor(event.section.split('-')[0]);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: deptColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.section,
                        style: TextStyle(color: deptColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.course,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time, color: isDark ? Colors.grey[400] : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${event.day} • ${event.time}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.room, color: isDark ? Colors.grey[400] : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Room: ${event.room}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person, color: isDark ? Colors.grey[400] : Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Teacher: ${event.teacher}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50,
                      foregroundColor: isDark ? const Color(0xFFFCA5A5) : Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF991B1B) : Colors.red.shade200,
                        ),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _removeCourse(event.course);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 8),
                        Text(
                          'Remove from Timetable',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Customize and Search classes


  List<int> _getEventBlockIndices(TimetableDayEvent event) {
    final blockTimes = [
      "08:30-10:00",
      "10:00-11:30",
      "11:30-13:00",
      "13:00-14:30",
      "14:30-16:00",
      "16:00-17:30",
      "17:30-19:00",
      "19:00-20:30"
    ];

    try {
      final parts = event.time.split('-');
      if (parts.length != 2) return [0];
      final start = parts[0].trim();
      final end = parts[1].trim();

      int startIndex = -1;
      int endIndex = -1;

      for (int i = 0; i < blockTimes.length; i++) {
        final bParts = blockTimes[i].split('-');
        if (bParts[0].trim() == start) {
          startIndex = i;
        }
        if (bParts[1].trim() == end) {
          endIndex = i;
        }
      }

      if (startIndex == -1) {
        startIndex = 0;
        int minDiff = 9999;
        for (int i = 0; i < blockTimes.length; i++) {
          final bStart = blockTimes[i].split('-')[0].trim();
          final diff = _diffInMinutes(start, bStart);
          if (diff < minDiff) {
            minDiff = diff;
            startIndex = i;
          }
        }
      }

      if (endIndex == -1) {
        endIndex = startIndex;
        int minDiff = 9999;
        for (int i = startIndex; i < blockTimes.length; i++) {
          final bEnd = blockTimes[i].split('-')[1].trim();
          final diff = _diffInMinutes(end, bEnd);
          if (diff < minDiff) {
            minDiff = diff;
            endIndex = i;
          }
        }
      }

      if (startIndex > endIndex) {
        final temp = startIndex;
        startIndex = endIndex;
        endIndex = temp;
      }

      return List.generate(endIndex - startIndex + 1, (index) => startIndex + index);
    } catch (_) {
      return [0];
    }
  }

  int _diffInMinutes(String t1, String t2) {
    try {
      final p1 = t1.split(':');
      final p2 = t2.split(':');
      int h1 = int.parse(p1[0]);
      int m1 = int.parse(p1[1].replaceAll(RegExp(r'[^0-9]'), ''));
      int h2 = int.parse(p2[0]);
      int m2 = int.parse(p2[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (h1 < 8) h1 += 12;
      if (h2 < 8) h2 += 12;
      return ((h1 * 60 + m1) - (h2 * 60 + m2)).abs();
    } catch (_) {
      return 9999;
    }
  }



  List<String> _getAvailableSectionsForCourse(String courseName) {
    if (_snapshot == null || _selectedDept == null) return [];
    final deptSections = _snapshot!.sections[_selectedDept!] ?? [];
    return _snapshot!.schedule
        .where((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim() && deptSections.contains(e.section))
        .map((e) => e.section)
        .toSet()
        .toList()
      ..sort();
  }

  String? _getSelectedSectionForCourse(String courseName) {
    final events = _customEvents.where((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim()).toList();
    if (events.isEmpty) return null;
    return events.first.section;
  }

  bool _isCourseSelected(String courseName) {
    return _customEvents.any((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim());
  }

  Future<void> _addCourse(String courseName, String section) async {
    if (_snapshot == null) return;
    
    // 1. Remove old slots if they exist
    _customEvents.removeWhere((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim());
    
    // 2. Add all matching slots for this course and section
    final newEvents = _snapshot!.schedule.where((e) =>
      e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
      e.section == section
    ).toList();
    
    setState(() {
      _customEvents.addAll(newEvents);
    });
    
    await TimetableStorage.saveCustomEvents(_customEvents);
    await HomeWidgetService.updateNextClassWidget();
    if (!mounted) return;
    
    CustomToast.showSuccess(context, 'Added "$courseName" (Section $section) to final timetable.');
  }

  Future<void> _removeCourse(String courseName) async {
    setState(() {
      _customEvents.removeWhere((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim());
    });
    await TimetableStorage.saveCustomEvents(_customEvents);
    await HomeWidgetService.updateNextClassWidget();
    if (!mounted) return;
    
    CustomToast.showSuccess(context, 'Removed "$courseName" from final timetable.');
  }

  Future<void> _changeCourseSection(String courseName, String newSection) async {
    if (_snapshot == null) return;
    
    // Find all events for the course in the new section
    final newEvents = _snapshot!.schedule.where((e) =>
      e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
      e.section == newSection
    ).toList();
    
    setState(() {
      // Remove old events
      _customEvents.removeWhere((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim());
      // Add new events
      _customEvents.addAll(newEvents);
    });
    
    await TimetableStorage.saveCustomEvents(_customEvents);
    await HomeWidgetService.updateNextClassWidget();
    if (!mounted) return;
    
    CustomToast.showSuccess(context, 'Changed "$courseName" section to $newSection.');
  }

  String _formatCourseEventsSubtitle(List<TimetableDayEvent> events) {
    if (events.isEmpty) return 'No classes scheduled';
    final slotsStr = events.map((e) => '${e.day.substring(0, 3)} ${e.time} (${e.room})').join(' • ');
    final teachers = events.map((e) => e.teacher.trim()).where((t) => t.isNotEmpty).toSet().join(', ');
    return '$slotsStr\nTeacher: ${teachers.isNotEmpty ? teachers : 'N/A'}';
  }

  bool _doesSectionClashWithTimetable(String courseName, String section) {
    if (_snapshot == null) return false;
    
    final newEvents = _snapshot!.schedule.where((e) =>
      e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
      e.section == section
    ).toList();
    
    for (final e1 in newEvents) {
      final e1Blocks = _getEventBlockIndices(e1);
      
      final otherCourseEvents = _customEvents.where((e2) =>
        e2.course.toLowerCase().trim() != courseName.toLowerCase().trim() &&
        e2.day.toLowerCase() == e1.day.toLowerCase()
      );
      
      for (final e2 in otherCourseEvents) {
        final e2Blocks = _getEventBlockIndices(e2);
        if (e1Blocks.any((b) => e2Blocks.contains(b))) {
          return true;
        }
      }
    }
    
    return false;
  }

  Future<void> _exportGridToGallery() async {
    try {
      // Check for permission first
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!mounted) return;
      if (!hasAccess) {
        CustomToast.showError(context, 'Gallery save permission is required to download the timetable.');
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
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Generating timetable image...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Delay to ensure the repaint boundary is rendered
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      final boundary = _gridBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        throw Exception("Could not locate timetable boundary renderer.");
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
        CustomToast.showSuccess(context, 'Timetable image saved to your gallery! 📸');
      }
    } catch (e) {
      debugPrint("Export to gallery error: $e");
      if (mounted) {
        CustomToast.showError(context, 'Failed to save to gallery: $e');
      }
    }
  }

  bool _isCoreCourse(String course, String dept, int semester, [TimetableSnapshot? snapshotOverride]) {
    final snap = snapshotOverride ?? _snapshot;
    if (snap == null) return false;

    // 1. Get all parent sections (e.g. CS-6A, CS-6B) in this department and semester
    final regex = RegExp('^${RegExp.escape(dept)}-$semester([A-Z]+)\$', caseSensitive: false);
    
    final allSectionsInDeptSem = snap.schedule
        .map((e) => e.section.replaceAll(RegExp(r'[0-9]+$'), ''))
        .where((s) => regex.hasMatch(s))
        .toSet()
        .toList();

    if (allSectionsInDeptSem.isEmpty) return false;

    // 2. Count unique parent sections that have this course scheduled
    final sectionsWithThisCourse = snap.schedule
        .where((e) => e.course.toLowerCase().trim() == course.toLowerCase().trim())
        .map((e) => e.section.replaceAll(RegExp(r'[0-9]+$'), ''))
        .where((s) => allSectionsInDeptSem.contains(s))
        .toSet();

    final ratio = sectionsWithThisCourse.length / allSectionsInDeptSem.length;
    return ratio >= 0.7;
  }
}

