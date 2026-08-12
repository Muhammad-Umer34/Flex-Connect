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
import '../../widgets/custom_toast.dart';

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



  // Custom Timetable & Search States
  List<TimetableDayEvent> _customEvents = [];
  int _activeTab = 0; // 0 = Grid, 1 = Planner
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _searchedCourseName;
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
    _searchController.dispose();
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

  String _getDeptFullName(String dept) {
    switch (dept.toUpperCase()) {
      case 'CS':
        return 'Computer Science';
      case 'SE':
        return 'Software Engineering';
      case 'AI':
        return 'Artificial Intelligence';
      case 'DS':
        return 'Data Science';
      case 'CY':
        return 'Cyber Security';
      case 'BA':
        return 'Business Administration';
      case 'FT':
        return 'FinTech';
      default:
        return 'Department of $dept';
    }
  }

  Color _getDeptColor(String dept) {
    switch (dept.toUpperCase()) {
      case 'CS':
        return Colors.indigo;
      case 'SE':
        return Colors.teal;
      case 'AI':
        return Colors.deepPurple;
      case 'DS':
        return Colors.blue;
      case 'CY':
        return Colors.redAccent;
      case 'BA':
        return Colors.orange;
      case 'FT':
        return Colors.green;
      default:
        return Colors.blueGrey;
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
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Academic Timetable',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (_step == 4)
          IconButton(
            icon: const Icon(Icons.refresh, color: _muted),
            tooltip: 'Upload New Timetable',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Timetable'),
                  content: const Text(
                    'Are you sure you want to upload a new Excel file? This will overwrite your current timetable.',
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
          style: const TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle.toUpperCase(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _accent),
                    SizedBox(height: 16),
                    Text(
                      'Processing your spreadsheet...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _ink),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This might take a moment.',
                      style: TextStyle(color: _muted),
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
        return _buildStep1Upload(isDark);
      case 4:
        return _buildStep4TimetableGrid(isDark);
      default:
        return _buildStep1Upload(isDark);
    }
  }
  // STEP 1: Upload and Parameters Selection
  Widget _buildStep1Upload(bool isDark) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExcelUploadForm(isDark),
      ],
    );
  }

  Widget _buildExcelUploadForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                    ),
                    child: const Icon(Icons.group_outlined, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Class Section Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'ENTER YOUR SECTION (E.G. BCS-6B)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sectionInputController,
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w500),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  const SectionInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g. BCS-6B',
                  hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(Icons.class_outlined, color: _muted),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'UPLOAD EXCEL SHEET',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: _selectedBytes != null
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedBytes != null
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedBytes != null
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedBytes != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: _selectedBytes != null ? _accent : _muted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedBytes != null ? 'Excel Selected' : 'Choose Spreadsheet File',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedFileName ?? 'Supported formats: .xlsx, .xls',
                  style: const TextStyle(color: _muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: const Color(0xFF94A3B8),
            ),
            onPressed: _selectedBytes != null ? _generateTimetable : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Generate Timetable',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // PDF upload UI removed (moved to dedicated Rechecking Schedule feature)
  // STEP 2: Choose Department


  // STEP 4: Timetable Render Grid
  Widget _buildStep4TimetableGrid(bool isDark) {
    if (_snapshot == null || _selectedSection == null) return const SizedBox.shrink();

    final deptColor = _getDeptColor(_selectedDept ?? '');

    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection summary card
        Container(
          decoration: BoxDecoration(
            color: deptColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: deptColor.withValues(alpha: 0.15), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: deptColor.withValues(alpha: 0.1),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_getDeptFullName(_selectedDept ?? '')} • ${_snapshot!.campus}',
                      style: const TextStyle(color: _muted, fontSize: 12),
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
            color: const Color(0xFFF1F5F9),
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
                      color: _activeTab == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _activeTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
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
                        color: _activeTab == 0 ? _ink : _muted,
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
                      color: _activeTab == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _activeTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
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
                        color: _activeTab == 1 ? _ink : _muted,
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
        _activeTab == 0 ? _buildGridTab(isDark) : _buildPlannerTab(isDark),
      ],
    );
  }

  // Final Timetable weekly grid/table
  Widget _buildGridTab(bool isDark) {
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

    // Determine what columns to show dynamically based on selections
    int maxActiveBlock = 4; // default to show up to 16:00
    for (final event in _customEvents) {
      final blocks = _getEventBlockIndices(event);
      for (final b in blocks) {
        if (b > maxActiveBlock && b < blockTimes.length) {
          maxActiveBlock = b;
        }
      }
    }

    final columnsToShow = List.generate(maxActiveBlock + 1, (i) => i);
    final daysToShow = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final hasSunday = _customEvents.any((e) => e.day.toLowerCase() == 'sunday');
    if (hasSunday) {
      daysToShow.add('Sunday');
    }

    if (_customEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text(
                'Timetable is Empty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _muted),
              ),
              const SizedBox(height: 4),
              const Text(
                'Go to "Customize & Search" tab to add classes.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Schedule Grid',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
                  ),
                  Text(
                    'Scroll horizontally to see all periods. Tap any class to view details.',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: _accent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _exportGridToGallery,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Save to Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: RepaintBoundary(
              key: _gridBoundaryKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FLEX CONNECT',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'WEEKLY ACADEMIC TIMETABLE',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 48),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'SECTION: ${_selectedSection ?? "N/A"}',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Campus: ${_snapshot?.campus ?? "N/A"}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Table(
                          defaultColumnWidth: const FixedColumnWidth(140),
                          border: TableBorder.all(
                            color: const Color(0xFFF1F5F9),
                            width: 0.8,
                          ),
                          children: [
                            // Header Row
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                              ),
                              children: [
                                const TableCell(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    child: Center(
                                      child: Text(
                                        'Day',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _ink),
                                      ),
                                    ),
                                  ),
                                ),
                                ...columnsToShow.map((bIdx) => TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    child: Center(
                                      child: Text(
                                        blockTimes[bIdx],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _muted),
                                      ),
                                    ),
                                  ),
                                )),
                              ],
                            ),
                            // Day Rows
                            ...daysToShow.map((day) {
                              return TableRow(
                                children: [
                                  // Day name cell
                                  TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      color: const Color(0xFFF8FAFC),
                                      child: Center(
                                        child: Text(
                                          day.substring(0, 3),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Time block cells
                                  ...columnsToShow.map((bIdx) {
                                    final cellEvents = _customEvents.where((e) {
                                      if (e.day.toLowerCase() != day.toLowerCase()) return false;
                                      final blocks = _getEventBlockIndices(e);
                                      return blocks.contains(bIdx);
                                    }).toList();

                                    return TableCell(
                                      child: _buildGridCell(cellEvents, isDark),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Flex Connect Utility System - Keep track of your academic schedule.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCell(List<TimetableDayEvent> cellEvents, bool isDark) {
    if (cellEvents.isEmpty) {
      return Container(
        height: 75,
        color: Colors.transparent,
      );
    }

    final hasClash = cellEvents.length > 1;

    return Container(
      height: 75,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: hasClash ? Colors.red.withValues(alpha: 0.08) : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasClash) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 9, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'CLASH',
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
          ],
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cellEvents.length,
              itemBuilder: (context, index) {
                final event = cellEvents[index];
                final deptColor = _getDeptColor(event.section.split('-')[0]);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: GestureDetector(
                    onTap: () => _showEventDetailsBottomSheet(event),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: deptColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasClash ? Colors.red.withValues(alpha: 0.6) : deptColor.withValues(alpha: 0.3),
                          width: hasClash ? 1.2 : 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.course,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: deptColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Icon(Icons.room, size: 8, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  event.room,
                                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.school, size: 8, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  event.section,
                                  style: const TextStyle(fontSize: 7, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDetailsBottomSheet(TimetableDayEvent event) {
    final deptColor = _getDeptColor(event.section.split('-')[0]);

    showModalBottomSheet(
      context: context,
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
                        color: deptColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.section,
                        style: TextStyle(color: deptColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.course,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${event.day} • ${event.time}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.room, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Room: ${event.room}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Teacher: ${event.teacher}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
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
  Widget _buildPlannerTab(bool isDark) {
    final deptColor = _selectedDept != null ? _getDeptColor(_selectedDept!) : Colors.indigo;

    // 1. Get all courses in the parent section (e.g. CS-6B)
    final parentEvents = _snapshot!.schedule.where((e) => _sectionMatches(e.section, _selectedSection!)).toList();
    final parentCourseNames = parentEvents.map((e) => e.course.trim()).toSet().toList()..sort();

    // 2. Custom cross-section choices (courses not in parent section)
    final parentCourseNamesLower = parentCourseNames.map((e) => e.toLowerCase().trim()).toSet();
    final customOtherEvents = _customEvents.where((e) =>
      !parentCourseNamesLower.contains(e.course.toLowerCase().trim())
    ).toList();
    final customOtherCourseNames = customOtherEvents.map((e) => e.course.trim()).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Autocomplete search interface
        _buildSearchSection(isDark),
        const SizedBox(height: 24),

        // Primary classes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classes for Section $_selectedSection',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _accent),
              onPressed: () async {
                for (final courseName in parentCourseNames) {
                  if (!_isCourseSelected(courseName)) {
                    await _addCourse(courseName, _selectedSection!);
                  }
                }
              },
              child: const Text('Add All', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: parentCourseNames.length,
          itemBuilder: (context, index) {
            final courseName = parentCourseNames[index];
            final isSelected = _isCourseSelected(courseName);
            final currentSection = _getSelectedSectionForCourse(courseName) ?? _selectedSection!;
            
            final displayEvents = _snapshot!.schedule.where((e) =>
              e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
              _sectionMatches(e.section, currentSection)
            ).toList();

            final availableSections = _getAvailableSectionsForCourse(courseName);
            final currentSectionClashes = isSelected && _doesSectionClashWithTimetable(courseName, currentSection);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: currentSectionClashes ? const Color(0xFFFCA5A5) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          courseName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _ink),
                        ),
                      ),
                      Switch(
                        activeThumbColor: Colors.white,
                        activeTrackColor: _accent,
                        value: isSelected,
                        onChanged: (bool val) {
                          if (val) {
                            _addCourse(courseName, _selectedSection!);
                          } else {
                            _removeCourse(courseName);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCourseEventsSubtitle(displayEvents),
                    style: const TextStyle(fontSize: 12, color: _muted, height: 1.3),
                  ),
                  if (currentSectionClashes) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Time conflict with another course!',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                  if (isSelected && availableSections.length > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.compare_arrows_rounded, size: 16, color: _muted),
                        const SizedBox(width: 6),
                        const Text(
                          'Section:',
                          style: TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: SizedBox(
                              height: 24,
                              child: DropdownButton<String>(
                                value: currentSection,
                                isDense: true,
                                dropdownColor: Colors.white,
                                style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 12),
                                onChanged: (String? newSection) {
                                  if (newSection != null) {
                                    _changeCourseSection(courseName, newSection);
                                  }
                                },
                                items: availableSections.map<DropdownMenuItem<String>>((String sec) {
                                  final itemClashes = _doesSectionClashWithTimetable(courseName, sec);
                                  return DropdownMenuItem<String>(
                                    value: sec,
                                    child: Text(itemClashes ? '$sec (Clash)' : sec),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Custom cross-section choices
        const Text(
          'Custom & Cross-Section Selections',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
        ),
        const SizedBox(height: 8),

        (() {
          if (customOtherCourseNames.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Center(
                child: Text(
                  'No cross-section or junior courses added yet.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customOtherCourseNames.length,
            itemBuilder: (context, index) {
              final courseName = customOtherCourseNames[index];
              final currentSection = _getSelectedSectionForCourse(courseName)!;
              
              final displayEvents = _snapshot!.schedule.where((e) =>
                e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
                _sectionMatches(e.section, currentSection)
              ).toList();

              final availableSections = _getAvailableSectionsForCourse(courseName);
              final currentSectionClashes = _doesSectionClashWithTimetable(courseName, currentSection);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentSectionClashes ? const Color(0xFFFCA5A5) : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            courseName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _ink),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeCourse(courseName),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCourseEventsSubtitle(displayEvents),
                      style: const TextStyle(fontSize: 12, color: _muted, height: 1.3),
                    ),
                    if (currentSectionClashes) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Time conflict with another course!',
                            style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    if (availableSections.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.compare_arrows_rounded, size: 16, color: _muted),
                          const SizedBox(width: 6),
                          const Text(
                            'Section:',
                            style: TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: SizedBox(
                                height: 24,
                                child: DropdownButton<String>(
                                  value: currentSection,
                                  isDense: true,
                                  dropdownColor: Colors.white,
                                  style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  onChanged: (String? newSection) {
                                    if (newSection != null) {
                                      _changeCourseSection(courseName, newSection);
                                    }
                                  },
                                  items: availableSections.map<DropdownMenuItem<String>>((String sec) {
                                    final itemClashes = _doesSectionClashWithTimetable(courseName, sec);
                                    return DropdownMenuItem<String>(
                                      value: sec,
                                      child: Text(itemClashes ? '$sec (Clash)' : sec),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        })(),
      ],
    );
  }

  Widget _buildSearchSection(bool isDark) {
    if (_snapshot == null || _selectedDept == null) return const SizedBox.shrink();

    // 1. Get all unique courses in this department
    final deptSections = _snapshot!.sections[_selectedDept!] ?? [];
    final allDeptEvents = _snapshot!.schedule.where((e) => deptSections.contains(e.section)).toList();
    final allDeptCourses = allDeptEvents.map((e) => e.course.trim()).toSet().toList()..sort();

    // 2. Filter based on _searchQuery
    final filteredCourses = _searchQuery.isEmpty
        ? <String>[]
        : allDeptCourses
            .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    final deptColor = _getDeptColor(_selectedDept!);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: deptColor),
              const SizedBox(width: 8),
              const Text(
                'Search & Add Course',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: _ink),
            decoration: InputDecoration(
              hintText: 'Type course name...',
              hintStyle: const TextStyle(color: _muted),
              prefixIcon: const Icon(Icons.search_outlined, color: _muted),
              fillColor: Colors.white,
              filled: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: _muted),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: deptColor),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          
          // Suggestion list
          if (filteredCourses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCourses.length,
                itemBuilder: (context, idx) {
                  final courseName = filteredCourses[idx];
                  return ListTile(
                    title: Text(courseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _ink)),
                    onTap: () {
                      setState(() {
                        _searchedCourseName = courseName;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  );
                },
              ),
            ),
          ],
          
          // Selected searched course details container
          if (_searchedCourseName != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search Result:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _muted),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: _muted),
                  onPressed: () {
                    setState(() {
                      _searchedCourseName = null;
                    });
                  },
                ),
              ],
            ),
            (() {
              final courseName = _searchedCourseName!;
              final availableSections = _getAvailableSectionsForCourse(courseName);
              if (availableSections.isEmpty) {
                return const Text('No sections offering this course.', style: TextStyle(color: _muted));
              }
              
              final isSelected = _isCourseSelected(courseName);
              final currentSection = _getSelectedSectionForCourse(courseName) ?? 
                  (availableSections.contains(_selectedSection) ? _selectedSection! : availableSections.first);
              
              final displayEvents = _snapshot!.schedule.where((e) =>
                e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
                _sectionMatches(e.section, currentSection)
              ).toList();

              final currentSectionClashes = _doesSectionClashWithTimetable(courseName, currentSection);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentSectionClashes ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCourseEventsSubtitle(displayEvents),
                      style: const TextStyle(fontSize: 12, color: _muted, height: 1.3),
                    ),
                    if (currentSectionClashes) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Time conflict with another course!',
                            style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Sec: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _ink)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: SizedBox(
                                  height: 20,
                                  child: DropdownButton<String>(
                                    value: currentSection,
                                    isDense: true,
                                    dropdownColor: Colors.white,
                                    style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 11),
                                    onChanged: (String? newSec) {
                                      if (newSec != null) {
                                        if (isSelected) {
                                          _changeCourseSection(courseName, newSec);
                                        } else {
                                          _addCourse(courseName, newSec);
                                        }
                                      }
                                    },
                                    items: availableSections.map<DropdownMenuItem<String>>((s) {
                                      final itemClashes = _doesSectionClashWithTimetable(courseName, s);
                                      return DropdownMenuItem<String>(
                                        value: s,
                                        child: Text(itemClashes ? '$s (Clash)' : s),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: isSelected ? Colors.red : Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          onPressed: () {
                            if (isSelected) {
                              _removeCourse(courseName);
                            } else {
                              _addCourse(courseName, currentSection);
                            }
                          },
                          child: Text(
                            isSelected ? 'Remove' : 'Add to Timetable',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            })(),
          ],
        ],
      ),
    );
  }

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
    if (!mounted) return;
    
    CustomToast.showSuccess(context, 'Added "$courseName" (Section $section) to final timetable.');
  }

  Future<void> _removeCourse(String courseName) async {
    setState(() {
      _customEvents.removeWhere((e) => e.course.toLowerCase().trim() == courseName.toLowerCase().trim());
    });
    await TimetableStorage.saveCustomEvents(_customEvents);
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

class SectionInputFormatter extends TextInputFormatter {
  const SectionInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Force uppercase
    String text = newValue.text.toUpperCase();
    int selectionIndex = newValue.selection.end;

    // If deleting text, retain deletion normally
    if (newValue.text.length < oldValue.text.length) {
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: selectionIndex),
      );
    }

    // Auto-format rule 1: If user types 3 letter degree prefix (e.g. "BCS", "BSE", "BAI"), auto insert "-"
    if (text.length == 3 && !text.contains('-')) {
      if (RegExp(r'^[A-Z]{3}$').hasMatch(text)) {
        text = '$text-';
        selectionIndex = text.length;
      }
    }
    // Auto-format rule 2: If typed/pasted without hyphen (e.g., "BCS7C" or "BSE6B")
    else if (text.length > 3 && !text.contains('-')) {
      final reg = RegExp(r'^([A-Z]{2,4})([0-9].*)$');
      final match = reg.firstMatch(text);
      if (match != null) {
        text = '${match.group(1)}-${match.group(2)}';
        selectionIndex = text.length;
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
