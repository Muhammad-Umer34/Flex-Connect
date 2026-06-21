import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

import '../../models/attendance_models.dart';
import '../../models/marks_models.dart';
import '../../models/transcript_models.dart';
import '../../services/attendance_storage.dart';
import '../../services/marks_storage.dart';
import '../../services/transcript_storage.dart';
import '../auth/university_login_webview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _credentialsKey = 'uni_credentials';
  static const String _dashboardDataKey = 'flex_dashboard_data';

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray
  static const Color _containerBg = Color(0xFFF8FAFC); // Light Gray/Slate
  static const Color _containerBorder = Color(0xFFF1F5F9); // Lighter Border

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
    } else {
      // Build dropdown options for first-time users (no transcript)
      final defaultCode = _getDefaultSemesterCode(_rollNumber);
      if (defaultCode.length >= 5) {
        final yrStr = defaultCode.substring(0, 4);
        final termChar = defaultCode.substring(4);
        final yr = int.tryParse(yrStr) ?? DateTime.now().year;
        String termName = 'Fall';
        if (termChar == '1') {
          termName = 'Spring';
        } else if (termChar == '2') {
          termName = 'Summer';
        }
        options.add({'name': '$termName $yr', 'code': defaultCode});
      } else {
        options.add({'name': 'Fall ${DateTime.now().year}', 'code': '${DateTime.now().year}3'});
      }
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



  String _getDefaultSemesterCode(String? rollNumber) {
    if (rollNumber != null && rollNumber.isNotEmpty) {
      final cleanRoll = rollNumber.trim();
      if (cleanRoll.length >= 2) {
        final yrPart = int.tryParse(cleanRoll.substring(0, 2));
        if (yrPart != null) {
          final yr = 2000 + yrPart;
          return '${yr}3'; // Term 3 is Fall
        }
      }
    }

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    if (month >= 1 && month <= 5) {
      return '${year}1';
    } else if (month >= 6 && month <= 7) {
      return '${year}2';
    } else {
      return '${year}3';
    }
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

    var savedSemCode = preferences.getString('flex_selected_sync_semester');
    if (savedSemCode == null) {
      savedSemCode = _getDefaultSemesterCode(savedRollNumber);
      await preferences.setString('flex_selected_sync_semester', savedSemCode);
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
      _selectedSemesterCode = savedSemCode;
      _isLoading = false;
      _recomputeCachedValues();
    });
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
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
                    color: const Color(0xFFF8FAFC),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: _accent, size: 20),
                            SizedBox(width: 8),
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
                          icon: const Icon(Icons.close_rounded, color: _muted),
                          onPressed: _onCancelSync,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                    color: const Color(0xFFF8FAFC),
                    width: double.infinity,
                    child: const Text(
                      'Solve the reCAPTCHA above to proceed with data synchronization.',
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
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                      style: const TextStyle(
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
                const Text(
                  'FLEX CONNECT',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
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
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
                    const Text(
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
                      style: const TextStyle(
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
                          _buildMiniBadge(_rollNumber!.trim(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
                        if (_degree != null && _degree!.isNotEmpty)
                          _buildMiniBadge(_degree!.trim(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
                        if (_campus != null && _campus!.isNotEmpty)
                          _buildMiniBadge(_campus!.trim(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
                        if (_batch != null && _batch!.isNotEmpty)
                          _buildMiniBadge(_batch!.trim(), const Color(0xFFF1F5F9), const Color(0xFF475569)),
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
              const Text(
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
              const Text(
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
                style: const TextStyle(
                  color: Color(0xFF1E293B),
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
              const Text(
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
                style: const TextStyle(
                  color: _muted,
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

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'Not Sync\'d';
    final localTime = dateTime.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[localTime.month - 1];
    final day = localTime.day;
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$month $day, $hour:$minute';
  }

  Widget _buildSyncStatusRow(String label, bool isCaptured, DateTime? timestamp) {
    final statusColor = isCaptured ? const Color(0xFF10B981) : _muted;
    final icon = isCaptured ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _ink,
            ),
          ),
          const Spacer(),
          Text(
            isCaptured ? _formatTimestamp(timestamp) : 'Not Sync\'d',
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSyncCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _containerBorder, width: 1),
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
                ),
                child: const Icon(
                  Icons.sync,
                  color: _accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SMART SYNC',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _isLoading ? null : _openUniversityLogin,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: const [
                      Icon(Icons.sync, size: 14, color: _accent),
                      SizedBox(width: 4),
                      Text(
                        'Sync Now',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
              const SizedBox(width: 8),
              const Text(
                'Active Semester:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _containerBorder, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSemesterCode,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: _muted),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: Colors.white,
                      items: _cachedSemesterOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['code'],
                          child: Text(opt['name']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSelectedSemester(val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: _containerBorder, height: 1),
          const SizedBox(height: 12),
          _buildSyncStatusRow('Last Synced', _hasAnyData, _latestSyncTime),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    final List<Widget> riskItems = [];

    // Check attendance courses risks
    for (final course in _attendanceCourses) {
      final status = CourseBunkStatus.calculate(course);
      final percentage = status.percentage;

      if (course.totalLectures > 0) {
        if (status.isBelow80) {
          riskItems.add(_buildDangerItem(
            '${course.displayTitle}: attendance is ${percentage.toStringAsFixed(1)}%',
            'Attend next ${status.minConsecutiveToAttend} classes to recover',
            const Color(0xFFEF4444),
            Icons.warning_amber_rounded,
          ));
        } else if (status.maxMissable == 0) {
          riskItems.add(_buildDangerItem(
            '${course.displayTitle}: attendance is ${percentage.toStringAsFixed(1)}%',
            'Do not miss next class',
            const Color(0xFFF59E0B),
            Icons.error_outline_rounded,
          ));
        } else if (percentage >= 80 && percentage < 85) {
          riskItems.add(_buildDangerItem(
            '${course.displayTitle}: attendance is ${percentage.toStringAsFixed(1)}%',
            'Near danger threshold (can miss ${status.maxMissable} class${status.maxMissable == 1 ? '' : 'es'})',
            const Color(0xFFD97706),
            Icons.info_outline,
          ));
        }
      }
    }

    // Check missing transcript data
    if (!_hasTranscriptData) {
      riskItems.add(_buildDangerItem(
        'Missing Transcript Data',
        'Sync using credentials to view latest CGPA/SGPA',
        const Color(0xFFEF4444),
        Icons.receipt_long_outlined,
      ));
    }

    // Check missing marks data
    if (!_hasMarksData) {
      riskItems.add(_buildDangerItem(
        'Missing Marks Data',
        'Sync using credentials to view course marks',
        const Color(0xFFEF4444),
        Icons.grading_outlined,
      ));
    }

    final isClear = riskItems.isEmpty;

    if (isClear) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _containerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _containerBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: const [
            Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Academic Status: Safe & Verified',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _containerBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_outlined, color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              const Text(
                'DANGER ZONE',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${riskItems.length} alert${riskItems.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: riskItems.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Color(0xFFE2E8F0), height: 1),
            ),
            itemBuilder: (context, index) => riskItems[index],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerItem(String title, String subtitle, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpaSnapshot() {
    if (!_hasTranscriptData) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _containerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _containerBorder, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.leaderboard_outlined, color: _muted, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sync transcript to unlock GPA snapshot.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _muted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final latestSem = _transcriptSnapshot!.semesters.last;
    final totalSemesters = _transcriptSnapshot!.semesters.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _containerBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPA SNAPSHOT',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestSem.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Semesters: $totalSemesters',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 42,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CGPA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestSem.cgpa ?? '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 42,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SGPA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestSem.sgpa ?? '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAndBunkHeader(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Text(
            'ATTENDANCE & BUNK STATUS',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
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
        child: const Text(
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
                child: _CourseAttendanceCard(
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
      backgroundColor: Colors.white,
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
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
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

class _CourseAttendanceCard extends StatelessWidget {
  const _CourseAttendanceCard({
    required this.course,
    this.marksCourse,
  });

  final AttendanceCourse course;
  final MarksCourse? marksCourse;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _present = Color(0xFF10B981);
  static const Color _late = Color(0xFFF59E0B);
  static const Color _absent = Color(0xFFEF4444);
  static const Color _containerBg = Color(0xFFF8FAFC);
  static const Color _containerBorder = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final status = CourseBunkStatus.calculate(course);
    final percentage = status.percentage;

    final Color statusColor;
    final IconData statusIcon;
    final String statusMessage;

    if (course.totalLectures == 0) {
      statusColor = HomeScreenStateColor._accent;
      statusIcon = Icons.info_outline;
      statusMessage = 'No lectures captured yet';
    } else if (status.isBelow80) {
      statusColor = _absent;
      statusIcon = Icons.warning_amber_rounded;
      statusMessage = 'Attend next ${status.minConsecutiveToAttend} classes to recover';
    } else if (status.maxMissable == 0) {
      statusColor = _late;
      statusIcon = Icons.error_outline_rounded;
      statusMessage = 'Do not miss next class';
    } else {
      statusColor = _present;
      statusIcon = Icons.check_circle_outline_rounded;
      statusMessage = 'You can miss ${status.maxMissable} class${status.maxMissable == 1 ? '' : 'es'}';
    }

    final marksInfo = marksCourse?.weightedScore;
    final obtainedMarks = marksInfo?['obtained'] ?? 0.0;
    final totalWeightage = marksInfo?['totalWeight'] ?? 0.0;
    final hasMarks = totalWeightage > 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _containerBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.displayTitle,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.subtitle!,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Text(
                  course.totalLectures == 0 ? '—' : '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: course.totalLectures > 0 ? (course.attendedCount / course.totalLectures) : 0.0,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLASSES ATTENDED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course.attendedCount} / ${course.totalLectures}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'P: ${course.presentCount} | L: ${course.lateCount} | A: ${course.absentCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OBTAINED MARKS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasMarks
                          ? '${obtainedMarks.toStringAsFixed(1)} / ${totalWeightage.toStringAsFixed(1)}'
                          : '—',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasMarks
                          ? 'Weightage: ${(obtainedMarks / totalWeightage * 100).toStringAsFixed(1)}%'
                          : 'No marks uploaded yet',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: _containerBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMessage,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeScreenStateColor {
  static const Color _accent = Color(0xFF2563EB);
}

class CourseBunkStatus {
  final AttendanceCourse course;
  final int attended;
  final int total;
  final double percentage;
  final bool isBelow80;
  final int maxMissable;
  final int minConsecutiveToAttend;

  CourseBunkStatus({
    required this.course,
    required this.attended,
    required this.total,
    required this.percentage,
    required this.isBelow80,
    required this.maxMissable,
    required this.minConsecutiveToAttend,
  });

  factory CourseBunkStatus.calculate(AttendanceCourse course) {
    final attended = course.attendedCount;
    final total = course.totalLectures;
    final double pct = total > 0 ? (attended / total) * 100 : 0.0;
    final isBelow = pct < 80.0;

    int maxMiss = 0;
    int minAttend = 0;

    if (total > 0) {
      if (!isBelow) {
        maxMiss = ((attended / 0.80) - total).floor();
        if (maxMiss < 0) maxMiss = 0;
      } else {
        minAttend = 4 * total - 5 * attended;
        if (minAttend < 0) minAttend = 0;
      }
    }

    return CourseBunkStatus(
      course: course,
      attended: attended,
      total: total,
      percentage: pct,
      isBelow80: isBelow,
      maxMissable: maxMiss,
      minConsecutiveToAttend: minAttend,
    );
  }
}
