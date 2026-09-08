import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

import '../../models/attendance_models.dart';
import '../../models/marks_models.dart';
import '../../models/transcript_models.dart';
import '../../models/marks_changelog.dart';
import '../../models/course_bunk_status.dart';
import '../../services/attendance_storage.dart';
import '../../services/marks_storage.dart';
import '../../services/marks_changelog_storage.dart';
import '../../services/transcript_storage.dart';
import '../../services/home_widget_service.dart';
import '../auth/university_login_webview.dart';
import 'widgets/course_attendance_card.dart';
import 'widgets/gpa_snapshot_card.dart';
import 'widgets/danger_zone_card.dart';
import 'widgets/smart_sync_card.dart';
import 'widgets/marks_changelog_sheet.dart';
import 'widgets/quick_actions_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _credentialsKey = 'uni_credentials';
  static const String _dashboardDataKey = 'flex_dashboard_data';

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _containerBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white;
  Color get _containerBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  String? _rollNumber;
  String? _studentName;
  String? _profilePhotoUrl;
  String? _profilePhotoBase64;
  String? _degree;
  String? _campus;
  String? _batch;
  String? _status;
  bool _isLoading = true;
  String? _selectedSemesterCode;

  // Background Sync state
  bool _isSyncing = false;
  bool _showCaptchaWebView = false;
  String _syncStatusMessage = 'Connecting to university portal...';
  Map<String, String>? _syncCredentials;

  // Cached computed values — refreshed only when data changes
  List<CourseBunkStatus> _cachedBunkStatuses = const [];
  List<Map<String, String>> _cachedSemesterOptions = const [];

  AttendanceSnapshot? _attendanceSnapshot;
  MarksSnapshot? _marksSnapshot;
  TranscriptSnapshot? _transcriptSnapshot;
  List<MarksChangelogEntry> _recentMarksChanges = [];

  List<AttendanceCourse> get _attendanceCourses =>
      _attendanceSnapshot?.courses ?? const [];




  // Safe helper: reading latest transcript CGPA/SGPA
  String? get _latestTranscriptCgpa {
    if (_transcriptSnapshot == null || _transcriptSnapshot!.semesters.isEmpty) {
      return null;
    }
    return _transcriptSnapshot!.semesters.last.cgpa;
  }

  String? get _latestTranscriptSgpa {
    if (_transcriptSnapshot == null || _transcriptSnapshot!.semesters.isEmpty) {
      return null;
    }
    return _transcriptSnapshot!.semesters.last.sgpa;
  }

  // Safe helper: detecting whether marks/transcript/attendance data exists
  bool get _hasAttendanceData =>
      _attendanceSnapshot != null && _attendanceSnapshot!.courses.isNotEmpty;

  bool get _hasMarksData =>
      _marksSnapshot != null && _marksSnapshot!.courses.isNotEmpty;

  bool get _hasTranscriptData =>
      _transcriptSnapshot != null && _transcriptSnapshot!.semesters.isNotEmpty;

  bool get _hasAnyData =>
      _hasAttendanceData || _hasMarksData || _hasTranscriptData;

  DateTime? get _latestSyncTime {
    DateTime? latest;
    if (_attendanceSnapshot?.capturedAt != null) {
      latest = _attendanceSnapshot!.capturedAt;
    }
    if (_marksSnapshot?.capturedAt != null) {
      final t = _marksSnapshot!.capturedAt!;
      if (latest == null || t.isAfter(latest)) {
        latest = t;
      }
    }
    if (_transcriptSnapshot?.capturedAt != null) {
      final t = _transcriptSnapshot!.capturedAt!;
      if (latest == null || t.isAfter(latest)) {
        latest = t;
      }
    }
    return latest;
  }

  void _recomputeCachedValues() {
    // Bunk statuses
    final statuses =
        _attendanceCourses.map((c) => CourseBunkStatus.calculate(c)).toList();
    statuses.sort((a, b) {
      if (a.isBelow80 && !b.isBelow80) return -1;
      if (!a.isBelow80 && b.isBelow80) return 1;
      final aCanMiss0 = a.maxMissable == 0;
      final bCanMiss0 = b.maxMissable == 0;
      if (aCanMiss0 && !bCanMiss0) return -1;
      if (!aCanMiss0 && bCanMiss0) return 1;
      return a.maxMissable.compareTo(b.maxMissable);
    });
    _cachedBunkStatuses = statuses;


    final options = <Map<String, String>>[];
    if (_transcriptSnapshot != null && _transcriptSnapshot!.semesters.isNotEmpty) {
      final seenCodes = <String>{};
      for (final sem in _transcriptSnapshot!.semesters) {
        final semName = sem.name.trim();
        if (semName.isNotEmpty) {
          final parts = semName.split(RegExp(r'\s+'));
          if (parts.length == 2) {
            final term = parts[0];
            final yrStr = parts[1];
            final yr = int.tryParse(yrStr);
            if (yr != null) {
              final termLower = term.toLowerCase();
              int termCode = 3; // Fall
              if (termLower.contains('spring')) {
                termCode = 1;
              } else if (termLower.contains('summer')) {
                termCode = 2;
              }
              final code = '$yr$termCode';
              if (!seenCodes.contains(code)) {
                seenCodes.add(code);
                final formattedName = '${term[0].toUpperCase()}${term.substring(1).toLowerCase()} $yr';
                options.add({'name': formattedName, 'code': code});
              }
            }
          }
        }
      }
      // Sort in descending order of code (latest semester first)
      options.sort((a, b) => int.parse(b['code']!).compareTo(int.parse(a['code']!)));
    } else if (_attendanceSnapshot != null && _attendanceSnapshot!.semesters.isNotEmpty) {
      final seenCodes = <String>{};
      for (final sem in _attendanceSnapshot!.semesters) {
        final code = sem.id.trim();
        final name = sem.name.trim();
        if (code.isNotEmpty && !seenCodes.contains(code)) {
          seenCodes.add(code);
          options.add({'name': name.isNotEmpty ? name : 'Semester $code', 'code': code});
        }
      }
      options.sort((a, b) => (int.tryParse(b['code']!) ?? 0).compareTo(int.tryParse(a['code']!) ?? 0));
    } else {
      // First-time users before sync: show a generic loading placeholder
      options.add({'name': 'Latest Semester', 'code': ''});
    }
    _cachedSemesterOptions = options;

    // Ensure selected semester code is valid and present in options
    if (options.isNotEmpty) {
      final hasSelected = options.any((opt) => opt['code'] == _selectedSemesterCode);
      if (!hasSelected) {
        _selectedSemesterCode = options.first['code'];
      }
    }
  }

  // Safe helper: parsing stored dashboard/profile data
  Map<String, String?> _parseDashboardData(String? storedDashboard) {
    String? studentName;
    String? profilePhotoUrl;
    String? profilePhotoBase64;
    String? attendanceLink;
    String? marksLink;
    String? transcriptLink;
    String? rollNumber;
    String? degree;
    String? campus;
    String? batch;
    String? status;

    if (storedDashboard != null && storedDashboard.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedDashboard);
        if (decoded is Map<String, dynamic>) {
          final name = decoded['name'];
          final image = decoded['profileImageUrl'];
          final imageBase64 = decoded['profileImageBase64'];
          final links = decoded['links'];

          rollNumber = decoded['rollNumber'];
          degree = decoded['degree'];
          campus = decoded['campus'];
          batch = decoded['batch'];
          status = decoded['status'];

          if (name is String && name.isNotEmpty) {
            studentName = name;
          }
          if (image is String && image.isNotEmpty) {
            profilePhotoUrl = image;
          }
          if (imageBase64 is String && imageBase64.isNotEmpty) {
            profilePhotoBase64 = imageBase64;
          }

          if (links is Map<String, dynamic>) {
            final attendance = links['attendance'];
            final marks = links['marks'];
            final transcript = links['transcript'];

            if (attendance is String && attendance.isNotEmpty) {
              attendanceLink = attendance;
            }
            if (marks is String && marks.isNotEmpty) {
              marksLink = marks;
            }
            if (transcript is String && transcript.isNotEmpty) {
              transcriptLink = transcript;
            }
          }
        }
      } catch (_) {}
    }

    return {
      'studentName': studentName,
      'profilePhotoUrl': profilePhotoUrl,
      'profilePhotoBase64': profilePhotoBase64,
      'attendanceLink': attendanceLink,
      'marksLink': marksLink,
      'transcriptLink': transcriptLink,
      'rollNumber': rollNumber,
      'degree': degree,
      'campus': campus,
      'batch': batch,
      'status': status,
    };
  }



  String? _getDefaultSemesterCode(String? rollNumber) {
    if (_transcriptSnapshot != null && _transcriptSnapshot!.semesters.isNotEmpty) {
      final lastSem = _transcriptSnapshot!.semesters.last.name.trim();
      final parts = lastSem.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final term = parts[0].toLowerCase();
        final yr = int.tryParse(parts[1]);
        if (yr != null) {
          int tCode = 3;
          if (term.contains('spring')) {
            tCode = 1;
          } else if (term.contains('summer')) {
            tCode = 2;
          }
          return '$yr$tCode';
        }
      }
    }
    return null;
  }


  Future<void> _updateSelectedSemester(String val) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('flex_selected_sync_semester', val);
    setState(() {
      _selectedSemesterCode = val;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCredentials = preferences.getString(_credentialsKey);
    final storedDashboard = preferences.getString(_dashboardDataKey);
    String? rollNumber;

    if (storedCredentials != null && storedCredentials.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedCredentials);
        if (decoded is Map<String, dynamic>) {
          final value = decoded['roll_number'];
          if (value is String && value.isNotEmpty) {
            rollNumber = value;
          }
        }
      } catch (_) {
        rollNumber = null;
      }
    }

    final parsedDashboard = _parseDashboardData(storedDashboard);

    String? profilePhotoBase64 = parsedDashboard['profilePhotoBase64'];
    final storedProfileBase64 = preferences.getString(
      'student_profile_photo_base64',
    );
    if (storedProfileBase64 != null && storedProfileBase64.isNotEmpty) {
      profilePhotoBase64 = storedProfileBase64;
    }

    final savedDegree = preferences.getString('student_degree') ?? parsedDashboard['degree'];
    final savedCampus = preferences.getString('student_campus') ?? parsedDashboard['campus'];
    final savedBatch = preferences.getString('student_batch') ?? parsedDashboard['batch'];
    final savedStatus = preferences.getString('student_status') ?? parsedDashboard['status'];
    final savedRollNumber = preferences.getString('student_roll_number') ?? rollNumber ?? parsedDashboard['rollNumber'];

    final attendanceSnapshot = await AttendanceStorage.load();
    final marksSnapshot = await MarksStorage.load();
    final transcriptSnapshot = await TranscriptStorage.load();
    final changelog = await MarksChangelogStorage.load();

    var savedSemCode = preferences.getString('flex_selected_sync_semester');
    if (savedSemCode == null && transcriptSnapshot != null && transcriptSnapshot.semesters.isNotEmpty) {
      savedSemCode = _getDefaultSemesterCode(savedRollNumber);
      if (savedSemCode != null) {
        await preferences.setString('flex_selected_sync_semester', savedSemCode);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _rollNumber = savedRollNumber;
      _studentName = parsedDashboard['studentName'];
      _profilePhotoUrl = parsedDashboard['profilePhotoUrl'];
      _profilePhotoBase64 = profilePhotoBase64;
      _degree = savedDegree;
      _campus = savedCampus;
      _batch = savedBatch;
      _status = savedStatus;
      _attendanceSnapshot = attendanceSnapshot;
      _marksSnapshot = marksSnapshot;
      _transcriptSnapshot = transcriptSnapshot;
      _recentMarksChanges = changelog;
      _selectedSemesterCode = savedSemCode;
      _isLoading = false;
      _recomputeCachedValues();
    });

    // Check if user has zero cached data (First-time user after entering credentials)
    final hasZeroData = !_hasAnyData;
    final isAutoSyncEnabled = preferences.getBool('auto_sync_on_launch') ?? false;

    if ((hasZeroData || isAutoSyncEnabled) && !_isSyncing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openUniversityLogin();
        }
      });
    }
  }

  Future<Map<String, String>?> _readStoredCredentials() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCredentials = preferences.getString(_credentialsKey);

    if (storedCredentials == null || storedCredentials.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(storedCredentials);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final rollNumber = decoded['roll_number'];
      final password = decoded['password'];

      if (rollNumber is! String || password is! String) {
        return null;
      }

      return {'rollNumber': rollNumber, 'password': password};
    } catch (_) {
      return null;
    }
  }

  Future<void> _openUniversityLogin() async {
    if (_isSyncing) return;

    final credentials = await _readStoredCredentials();

    if (!mounted) {
      return;
    }

    if (credentials == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved university credentials found.')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _showCaptchaWebView = false;
      _syncStatusMessage = 'Initializing sync...';
      _syncCredentials = credentials;
    });
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
              SizedBox(width: 12),
              Text(
                'Logout & Reset App',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout? This will permanently delete all saved credentials, attendance, marks, and transcripts from this device.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _isLoading = true;
                });
                
                final preferences = await SharedPreferences.getInstance();
                await preferences.clear();
                MarksStorage.highlightedCoursesNotifier.value = [];
                await HomeWidgetService.updateNextClassWidget();
                
                if (!mounted) return;
                RestartWidget.restartApp(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout & Wipe',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onSyncComplete() {
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _showCaptchaWebView = false;
      _syncCredentials = null;
    });
    _loadHomeData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Synced successfully!'),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSyncProgress(String message) {
    if (!mounted) return;
    setState(() {
      _syncStatusMessage = message;
    });
  }

  void _onSyncError(String error) {
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _showCaptchaWebView = false;
      _syncCredentials = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Sync failed: $error')),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onCancelSync() {
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _showCaptchaWebView = false;
      _syncCredentials = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sync cancelled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCaptchaOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final credentials = _syncCredentials;
    if (credentials == null) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _onCancelSync,
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: _accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Verification Required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: _muted),
                          onPressed: _onCancelSync,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  SizedBox(
                    height: 520,
                    child: UniversityLoginWebViewScreen(
                      rollNumber: credentials['rollNumber']!,
                      password: credentials['password']!,
                      onCaptchaRequired: () {
                        if (mounted && !_showCaptchaWebView) {
                          setState(() {
                            _showCaptchaWebView = true;
                          });
                        }
                      },
                      onCaptchaSolved: () {
                        if (mounted && _showCaptchaWebView) {
                          setState(() {
                            _showCaptchaWebView = false;
                            _syncStatusMessage = 'Captcha solved. Submitting...';
                          });
                        }
                      },
                      onSyncComplete: _onSyncComplete,
                      onSyncProgress: _onSyncProgress,
                      onSyncError: _onSyncError,
                      onCancel: _onCancelSync,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    width: double.infinity,
                    child: Text(
                      'Complete the verification challenge above to proceed with data synchronization.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundSyncingProgressHUD() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SYNCING PORTAL IN BACKGROUND',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _accent,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _syncStatusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 20),
                onPressed: _onCancelSync,
                tooltip: 'Cancel Sync',
              ),
            ],
          ),
        ),
      ),
    );
  }




  ImageProvider<Object>? _profileImageProvider() {
    final base64Value = _profilePhotoBase64;
    if (base64Value != null && base64Value.startsWith('data:image')) {
      try {
        final encoded = base64Value.split(',').last;
        final bytes = base64Decode(encoded);
        if (bytes.isNotEmpty) {
          return MemoryImage(bytes);
        }
      } catch (_) {
        return null;
      }
    }

    final url = _profilePhotoUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }

    return null;
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final imageProvider = _profileImageProvider();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/logo.jpg',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'FLEX CONNECT',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.sync,
                      color: _accent,
                      size: 18,
                    ),
                    tooltip: 'Sync Data',
                    onPressed: _isLoading ? null : _openUniversityLogin,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFFEE2E2),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    tooltip: 'Logout & Wipe Data',
                    onPressed: _isLoading ? null : _showLogoutConfirmationDialog,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFF8FAFC),
                      backgroundImage: imageProvider,
                      onBackgroundImageError: imageProvider == null ? null : (_, _) {},
                      child: imageProvider == null
                          ? const Icon(Icons.person, size: 28, color: _accent)
                          : null,
                    ),
                  ),
                  if (_status?.trim().toLowerCase() == 'current')
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _studentName?.trim() ?? 'Student',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_rollNumber != null && _rollNumber!.isNotEmpty)
                          _buildMiniBadge(
                            _rollNumber!.trim(),
                            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569),
                          ),
                        if (_degree != null && _degree!.isNotEmpty)
                          _buildMiniBadge(
                            _degree!.trim(),
                            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569),
                          ),
                        if (_campus != null && _campus!.isNotEmpty)
                          _buildMiniBadge(
                            _campus!.trim(),
                            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569),
                          ),
                        if (_batch != null && _batch!.isNotEmpty)
                          _buildMiniBadge(
                            _batch!.trim(),
                            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarksAlertBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = _recentMarksChanges.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'NEW MARKS DETECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$count mark ${count == 1 ? "entry has" : "entries have"} been updated on your portal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              MarksChangelogSheet.show(
                context,
                entries: _recentMarksChanges,
                onDismissed: () async {
                  await MarksChangelogStorage.clear();
                  MarksStorage.highlightedCoursesNotifier.value = [];
                  if (mounted) {
                    setState(() {
                      _recentMarksChanges = [];
                    });
                  }
                },
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textCol,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final cgpaVal = _latestTranscriptCgpa ?? '-';
    final sgpaVal = _latestTranscriptSgpa ?? '-';

    final dangerCount = _attendanceCourses.where((c) => c.isInDanger).length;
    final dangerCoursesVal = _hasAttendanceData ? '$dangerCount' : '-';
    final Color dangerColor = dangerCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DANGER COURSES',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                dangerCoursesVal,
                style: TextStyle(
                  color: dangerColor,
                  fontSize: 44,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CUMULATIVE CGPA',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                cgpaVal,
                style: TextStyle(
                  color: _ink,
                  fontSize: 44,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LATEST SGPA',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                sgpaVal,
                style: TextStyle(
                  color: _ink,
                  fontSize: 44,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSmartSyncCard() {
    return SmartSyncCard(
      isLoading: _isLoading,
      onSyncPressed: _openUniversityLogin,
      selectedSemesterCode: _selectedSemesterCode,
      cachedSemesterOptions: _cachedSemesterOptions,
      onSemesterChanged: _updateSelectedSemester,
      hasAnyData: _hasAnyData,
      latestSyncTime: _latestSyncTime,
    );
  }

  Widget _buildDangerZone() {
    return DangerZoneCard(
      attendanceCourses: _attendanceCourses,
      hasTranscriptData: _hasTranscriptData,
      hasMarksData: _hasMarksData,
    );
  }

  Widget _buildGpaSnapshot() {
    return GpaSnapshotCard(
      transcriptSnapshot: _transcriptSnapshot,
    );
  }

  Widget _buildAttendanceAndBunkHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.event_available_outlined,
          color: _ink,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'Attendance & Bunk Status',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCourseBunkList() {
    if (_cachedBunkStatuses.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _containerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _containerBorder, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          'No course attendance data stored yet. Pull to refresh or tap the sync button to fetch.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Column(
      children: _cachedBunkStatuses
          .map(
            (status) {
              // Find matching marks course
              MarksCourse? matchedMarks;
              if (_marksSnapshot != null) {
                final code = status.course.courseCode.trim().replaceAll(' ', '').toUpperCase();
                final paneId = status.course.paneId.trim().toUpperCase();
                for (final c in _marksSnapshot!.courses) {
                  final cCode = c.courseCode.trim().replaceAll(' ', '').toUpperCase();
                  final cPaneId = c.paneId.trim().toUpperCase();
                  if ((code.isNotEmpty && cCode == code) || cPaneId == paneId) {
                    matchedMarks = c;
                    break;
                  }
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CourseAttendanceCard(
                  course: status.course,
                  marksCourse: matchedMarks,
                ),
              );
            },
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadHomeData,
                    color: _accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context),
                          if (_recentMarksChanges.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildMarksAlertBanner(),
                          ],
                          const SizedBox(height: 24),
                          const QuickActionsGrid(),
                          const SizedBox(height: 24),
                          _buildStatsSection(context),
                          const SizedBox(height: 32),
                          _buildSmartSyncCard(),
                          const SizedBox(height: 16),
                          _buildDangerZone(),
                          const SizedBox(height: 16),
                          _buildGpaSnapshot(),
                          const SizedBox(height: 32),
                          _buildAttendanceAndBunkHeader(context),
                          const SizedBox(height: 16),
                          _buildCourseBunkList(),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Background sync will keep your records up to date without interrupting your experience.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_isSyncing) ...[
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showCaptchaWebView,
                child: AnimatedOpacity(
                  opacity: _showCaptchaWebView ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _buildCaptchaOverlay(),
                ),
              ),
            ),
            if (!_showCaptchaWebView)
              _buildBackgroundSyncingProgressHUD(),
          ],
        ],
      ),
    );
  }
}

