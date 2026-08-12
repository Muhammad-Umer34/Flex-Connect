import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/marks_storage.dart';

class UniversityLoginWebViewScreen extends StatefulWidget {
  const UniversityLoginWebViewScreen({
    super.key,
    required this.rollNumber,
    required this.password,
    this.onCaptchaRequired,
    this.onCaptchaSolved,
    this.onSyncComplete,
    this.onSyncProgress,
    this.onSyncError,
    this.onCancel,
  });

  final String rollNumber;
  final String password;
  final VoidCallback? onCaptchaRequired;
  final VoidCallback? onCaptchaSolved;
  final VoidCallback? onSyncComplete;
  final void Function(String message)? onSyncProgress;
  final void Function(String error)? onSyncError;
  final VoidCallback? onCancel;

  @override
  State<UniversityLoginWebViewScreen> createState() =>
      _UniversityLoginWebViewScreenState();
}

class _UniversityLoginWebViewScreenState
    extends State<UniversityLoginWebViewScreen> {
  static const String _dashboardDataKey = 'flex_dashboard_data';
  static const String _attendanceDataKey = 'flex_attendance_data';
  static const String _marksDataKey = 'flex_marks_data';
  static const String _transcriptDataKey = 'flex_transcript_data';
  late final WebViewController _controller;
  bool _isCaptchaReady = false;
  bool _hasInjectedCredentials = false;
  bool _hasAttachedAutoSubmit = false;
  bool _hasCompletedLogin = false;
  bool _dashboardCaptured = false;
  bool _hasNavigatedToAttendance = false;
  bool _attendanceCaptured = false;
  bool _hasNavigatedToMarks = false;
  bool _marksCaptured = false;
  bool _hasNavigatedToTranscript = false;
  bool _transcriptCaptured = false;
  String? _marksUrl;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!url.contains('/Login') && !_hasCompletedLogin) {
              widget.onCaptchaSolved?.call();
            }
          },
          onPageFinished: (url) async {
            if (!mounted) {
              return;
            }

            if (_isLoginPage(url)) {
              widget.onCaptchaRequired?.call();
              if (!_hasInjectedCredentials) {
                await _injectCredentials();
                await _attachAutoSubmitWhenCaptchaSolved();
              }

              await _waitForCaptchaAndIsolate();
              return;
            }

            if (_isTranscriptPage(url)) {
              if (!_transcriptCaptured) {
                final captured = await _waitForTranscriptAndCapture();
                if (captured) {
                  _transcriptCaptured = true;
                  await _resolveLatestSemesterAndNavigateToAttendance();
                }
              }
              return;
            }

            if (_isAttendancePage(url)) {
              if (!_attendanceCaptured) {
                final captured = await _waitForAttendanceAndCapture();
                if (captured) {
                  _attendanceCaptured = true;
                  await _navigateToMarksPage();
                }
              }
              return;
            }

            if (_isMarksPage(url)) {
              if (!_marksCaptured) {
                final captured = await _waitForMarksAndCapture();
                if (captured) {
                  _marksCaptured = true;
                  await _closeWebView();
                }
              }
              return;
            }

            if (_isPortalPage(url)) {
              if (_dashboardCaptured) {
                return;
              }

              widget.onSyncProgress?.call('Capturing student profile info...');
              String? attendanceUrl;
              for (var attempt = 0; attempt < 20; attempt++) {
                if (!mounted) {
                  return;
                }

                attendanceUrl = await _captureDashboardData();
                if (attendanceUrl != null) {
                  break;
                }

                await Future<void>.delayed(const Duration(milliseconds: 300));
              }

              if (attendanceUrl == null) {
                widget.onSyncError?.call('Failed to parse dashboard data.');
                return;
              }

              _dashboardCaptured = true;

              if (!_hasNavigatedToTranscript) {
                await _navigateToTranscriptPage();
              } else {
                await _closeWebView();
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://flexstudent.nu.edu.pk/Login'));
  }

  bool _isLoginPage(String url) => url.contains('/Login');

  bool _isPortalPage(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('flexstudent.nu.edu.pk')) {
      return false;
    }

    final path = uri.path.toLowerCase();
    return !path.contains('/login') &&
        !path.contains('/student/studentattendance') &&
        !path.contains('/student/studentmarks') &&
        !path.contains('/student/transcript');
  }

  bool _isAttendancePage(String url) =>
      url.contains('/Student/StudentAttendance');

  bool _isMarksPage(String url) => url.contains('/Student/StudentMarks');

  bool _isTranscriptPage(String url) => url.contains('/Student/Transcript');

  Future<void> _resolveLatestSemesterAndNavigateToAttendance() async {
    if (_hasNavigatedToAttendance) {
      await _closeWebView();
      return;
    }

    _hasNavigatedToAttendance = true;
    final prefs = await SharedPreferences.getInstance();

    // Use the active selected semester set on the Home Screen
    String? semId = prefs.getString('flex_selected_sync_semester');
    final attendanceUrl = prefs.getString('student_link_attendance') ?? 'https://flexstudent.nu.edu.pk/Student/StudentAttendance';
    final targetUrl = (semId != null && semId.isNotEmpty)
        ? _modifyUrlSemester(attendanceUrl, semId)
        : attendanceUrl;

    widget.onSyncProgress?.call('Loading attendance page...');
    await _controller.loadRequest(Uri.parse(targetUrl));
  }

  Future<void> _navigateToMarksPage() async {
    if (_hasNavigatedToMarks) {
      await _closeWebView();
      return;
    }

    _hasNavigatedToMarks = true;
    final prefs = await SharedPreferences.getInstance();
    final semId = prefs.getString('flex_selected_sync_semester');
    var marksUrl = _marksUrl ?? await _readStoredMarksUrl() ?? 'https://flexstudent.nu.edu.pk/Student/StudentMarks';
    if (semId != null && semId.isNotEmpty) {
      marksUrl = _modifyUrlSemester(marksUrl, semId);
    }
    widget.onSyncProgress?.call('Loading course marks page...');
    await _controller.loadRequest(Uri.parse(marksUrl));
  }

  String _modifyUrlSemester(String url, String semId) {
    try {
      final uri = Uri.parse(url);
      final queryParams = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        if (key.toLowerCase() != 'semid') {
          queryParams[key] = value;
        }
      });
      queryParams['SemId'] = semId;
      return uri.replace(queryParameters: queryParams).toString();
    } catch (_) {
      return url;
    }
  }

  Future<String?> _readStoredMarksUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('student_link_marks');
  }

  Future<void> _navigateToTranscriptPage() async {
    if (_hasNavigatedToTranscript) {
      await _closeWebView();
      return;
    }

    _hasNavigatedToTranscript = true;
    final preferences = await SharedPreferences.getInstance();
    final transcriptUrl =
        preferences.getString('student_link_transcript') ??
        'https://flexstudent.nu.edu.pk/Student/Transcript';

    widget.onSyncProgress?.call('Loading transcript page...');
    await _controller.loadRequest(Uri.parse(transcriptUrl));
  }

  Future<void> _closeWebView() async {
    if (_hasCompletedLogin || !mounted) {
      return;
    }

    _hasCompletedLogin = true;
    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mounted) {
      return;
    }

    if (widget.onSyncComplete != null) {
      widget.onSyncComplete!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<String?> _captureDashboardData() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const toText = (value) => (value || '').replace(/\\s+/g, ' ').trim();
          const toAbsolute = (value) => {
            if (!value) {
              return null;
            }
            try {
              return new URL(value, window.location.origin).toString();
            } catch (_) {
              return value;
            }
          };

          const findSpanValue = (label) => {
            const paragraphs = Array.from(document.querySelectorAll('p'));
            for (const p of paragraphs) {
              const boldSpan = p.querySelector('span.m--font-boldest, span.m-portlet__head-text, span');
              if (boldSpan && toText(boldSpan.textContent).toLowerCase().includes(label.toLowerCase())) {
                const spans = Array.from(p.querySelectorAll('span'));
                if (spans.length >= 2) {
                  return toText(spans[1].textContent);
                }
              }
            }
            const boldSpans = Array.from(document.querySelectorAll('span'));
            for (let i = 0; i < boldSpans.length; i++) {
              if (toText(boldSpans[i].textContent).toLowerCase().includes(label.toLowerCase())) {
                if (i + 1 < boldSpans.length) {
                  return toText(boldSpans[i + 1].textContent);
                }
              }
            }
            return null;
          };

          const nameCandidates = [
            document.querySelector('#m_header_topbar .m-topbar__username .m-link'),
            document.querySelector('#m_header_topbar .m-topbar__username'),
            document.querySelector('.m-topbar__username .m-link'),
            document.querySelector('.m-topbar_username .m-link'),
            document.querySelector('.m-topbar_username'),
            document.querySelector('li.m-topbar__user-profile .m-link'),
            document.querySelector('li.m-topbar_user-profile .m-link'),
            document.querySelector('#m_header_nav .m-topbar__username'),
          ];
          const nameNode = nameCandidates.find((node) => toText(node && node.textContent));

          const imageCandidates = [
            document.querySelector('#m_header_topbar img.m-topbar__pic'),
            document.querySelector('#m_header_topbar .m-topbar__userpic img[src]'),
            document.querySelector('.m-topbar__userpic img[src]'),
            document.querySelector('li.m-topbar__user-profile img[src]'),
            document.querySelector('li.m-topbar_user-profile img[src]'),
            document.querySelector('.m-topbar_userpic img[src]'),
            document.querySelector('img[src*="GetImage"]'),
            document.querySelector('img[src*="StudentImage"]'),
            document.querySelector('img[src*="ProfileImage"]'),
          ];
          const imageNode = imageCandidates.find((node) => node && node.getAttribute('src'));

          const rollNumber = findSpanValue('Roll No');
          const degree = findSpanValue('Degree');
          const campus = findSpanValue('Campus');
          const batch = findSpanValue('Batch');
          const status = findSpanValue('Status');

          const links = {
            attendance: null,
            marks: null,
            transcript: null,
          };

          document.querySelectorAll('#m_header_menu a[href], .m-menu__link, a.m-menu__link, a[href]').forEach((anchor) => {
            const labelNode = anchor.querySelector('.m-menu__link-text, .m-menu_link-text');
            const label = toText(labelNode ? labelNode.textContent : anchor.textContent).toLowerCase();
            const href = toAbsolute(anchor.getAttribute('href'));

            if (!href) {
              return;
            }

            if (!links.attendance && (label.includes('attendance') || href.toLowerCase().includes('studentattendance'))) {
              links.attendance = href;
            }

            if (!links.marks && (label.includes('marks') || href.toLowerCase().includes('studentmarks'))) {
              links.marks = href;
            }

            if (!links.transcript && (label.includes('transcript') || href.toLowerCase().includes('transcript'))) {
              links.transcript = href;
            }
          });

          if (!links.attendance) {
            links.attendance = toAbsolute('/Student/StudentAttendance');
          }

          if (!links.marks) {
            links.marks = toAbsolute('/Student/StudentMarks');
          }

          const hasMeaningfulData = !!toText(nameNode ? nameNode.textContent : '') ||
            !!links.attendance || !!links.marks || !!links.transcript;

          return JSON.stringify({
            sourceUrl: window.location.href,
            capturedAt: new Date().toISOString(),
            name: toText(nameNode ? nameNode.textContent : ''),
            profileImageUrl: toAbsolute(imageNode ? imageNode.getAttribute('src') : null),
            rollNumber: rollNumber || null,
            degree: degree || null,
            campus: campus || null,
            batch: batch || null,
            status: status || null,
            links,
            hasMeaningfulData,
          });
        })();
      ''');

      final payload = _normalizeJavaScriptResult(result);
      if (payload.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final hasMeaningfulData =
          decoded['hasMeaningfulData'] == true ||
          ((decoded['name'] as String?)?.isNotEmpty ?? false) ||
          (decoded['links'] is Map<String, dynamic> &&
              ((decoded['links'] as Map<String, dynamic>)['attendance']
                          as String?)
                       ?.isNotEmpty ==
                  true);

      if (!hasMeaningfulData) {
        return null;
      }

      final image = decoded['profileImageUrl'];
      if (image is String && image.isNotEmpty) {
        final base64Image = await _fetchProfileImageBase64(image);
        if (base64Image != null && base64Image.isNotEmpty) {
          decoded['profileImageBase64'] = base64Image;
        }
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_dashboardDataKey, jsonEncode(decoded));

      final name = decoded['name'];
      final base64Image = decoded['profileImageBase64'];
      final links = decoded['links'];
      if (name is String && name.isNotEmpty) {
        await preferences.setString('student_name', name);
      }
      if (image is String && image.isNotEmpty) {
        await preferences.setString('student_profile_photo', image);
      }
      if (base64Image is String && base64Image.isNotEmpty) {
        await preferences.setString(
          'student_profile_photo_base64',
          base64Image,
        );
      }

      final extractedRoll = decoded['rollNumber'];
      final degree = decoded['degree'];
      final campus = decoded['campus'];
      final batch = decoded['batch'];
      final status = decoded['status'];

      if (extractedRoll is String && extractedRoll.isNotEmpty) {
        await preferences.setString('student_roll_number', extractedRoll);
      }
      if (degree is String && degree.isNotEmpty) {
        await preferences.setString('student_degree', degree);
      }
      if (campus is String && campus.isNotEmpty) {
        await preferences.setString('student_campus', campus);
      }
      if (batch is String && batch.isNotEmpty) {
        await preferences.setString('student_batch', batch);
      }
      if (status is String && status.isNotEmpty) {
        await preferences.setString('student_status', status);
      }

      if (links is Map<String, dynamic>) {
        final attendance = links['attendance'];
        final marks = links['marks'];
        final transcript = links['transcript'];
        if (attendance is String && attendance.isNotEmpty) {
          await preferences.setString('student_link_attendance', attendance);
        }
        if (marks is String && marks.isNotEmpty) {
          await preferences.setString('student_link_marks', marks);
        }
        if (transcript is String && transcript.isNotEmpty) {
          await preferences.setString('student_link_transcript', transcript);
        }
      }

      if (links is Map<String, dynamic>) {
        final marks = links['marks'];
        if (marks is String && marks.isNotEmpty) {
          _marksUrl = marks;
        }
      }

      if (_marksUrl == null || _marksUrl!.isEmpty) {
        _marksUrl = 'https://flexstudent.nu.edu.pk/Student/StudentMarks';
      }

      final attendanceUrl = links is Map<String, dynamic>
          ? links['attendance'] as String?
          : null;
      if (attendanceUrl != null && attendanceUrl.isNotEmpty) {
        return attendanceUrl;
      }

      return 'https://flexstudent.nu.edu.pk/Student/StudentAttendance';
    } catch (_) {
      // Intentionally ignored: parsing can fail while the page is still loading.
      return null;
    }
  }

  Future<String?> _fetchProfileImageBase64(String imageUrl) async {
    await _controller.runJavaScript('''
      window.flexProfileImageResult = null;
      (async function() {
        try {
          const response = await fetch(${_jsString(imageUrl)}, { credentials: 'include' });
          if (!response.ok) {
            window.flexProfileImageResult = '';
            return;
          }
          const blob = await response.blob();
          const reader = new FileReader();
          reader.onloadend = function() {
            window.flexProfileImageResult = reader.result || '';
          };
          reader.readAsDataURL(blob);
        } catch (_) {
          window.flexProfileImageResult = '';
        }
      })();
    ''');

    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final result = await _controller.runJavaScriptReturningResult(
        'window.flexProfileImageResult',
      );
      final normalized = _normalizeJavaScriptResult(result);
      if (normalized.isEmpty || normalized == 'null') {
        continue;
      }

      if (normalized.startsWith('data:image')) {
        return normalized;
      }
    }

    return null;
  }

  Future<void> _activateAllAttendanceTabs() async {
    final countResult = await _controller.runJavaScriptReturningResult('''
      (function() {
        return document.querySelectorAll(
          'a.m-tabs_link[href^="#"], .nav-tabs a[href^="#"], a[data-toggle="tab"][href^="#"]'
        ).length;
      })();
    ''');

    final tabCount = int.tryParse(_normalizeJavaScriptResult(countResult)) ?? 0;
    for (var index = 0; index < tabCount; index++) {
      await _controller.runJavaScript('''
        (function() {
          const tabs = document.querySelectorAll(
            'a.m-tabs_link[href^="#"], .nav-tabs a[href^="#"], a[data-toggle="tab"][href^="#"]'
          );
          if (tabs[$index]) {
            tabs[$index].click();
          }
        })();
      ''');
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  Future<bool> _attendanceHasCourseData() async {
    final result = await _controller.runJavaScriptReturningResult('''
      (function() {
        const panes = document.querySelectorAll('.tab-content .tab-pane[id], .tab-pane[role="tabpanel"]');
        if (panes.length === 0) {
          return false;
        }

        for (const pane of panes) {
          if (pane.querySelectorAll('table tbody tr').length > 0) {
            return true;
          }
        }

        return panes.length > 0;
      })();
    ''');

    return result == true;
  }

  Future<bool> _waitForAttendanceAndCapture() async {
    widget.onSyncProgress?.call('Scraping attendance records...');
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) {
        return false;
      }

      await _activateAllAttendanceTabs();
      await _captureAttendanceData();

      if (await _attendanceHasCourseData()) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    await _activateAllAttendanceTabs();
    await _captureAttendanceData();
    return true;
  }

  Future<void> _captureAttendanceData() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const toText = (value) => (value || '').replace(/\\s+/g, ' ').trim();

          const toAbsolute = (value) => {
            if (!value) {
              return null;
            }
            try {
              return new URL(value, window.location.origin).toString();
            } catch (_) {
              return value;
            }
          };

          const semesterSelect = document.querySelector('#SemId');
          const semesters = [];
          let selectedSemester = null;

          if (semesterSelect) {
            semesterSelect.querySelectorAll('option').forEach((option) => {
              const entry = {
                id: toText(option.value),
                name: toText(option.textContent),
                selected: !!option.selected,
              };
              semesters.push(entry);
              if (entry.selected) {
                selectedSemester = entry;
              }
            });
          }

          const tabsByPane = {};
          document.querySelectorAll(
            'a.m-tabs_link[href^="#"], .nav-tabs a[href^="#"], a[data-toggle="tab"][href^="#"]'
          ).forEach((tab) => {
            const href = tab.getAttribute('href') || '';
            const paneId = href.startsWith('#') ? href.substring(1) : href;
            if (!paneId) {
              return;
            }
            tabsByPane[paneId] = {
              code: toText(tab.textContent),
              title: toText(tab.getAttribute('title') || tab.getAttribute('data-original-title') || ''),
            };
          });

          const courses = [];
          document.querySelectorAll(
            '.tab-content .tab-pane[id], .tab-pane[role="tabpanel"][id]'
          ).forEach((pane) => {
            const paneId = pane.getAttribute('id') || '';
            const tabMeta = tabsByPane[paneId] || {};
            const headingNode = pane.querySelector('h5, h4, .m-portlet__head-text');
            const heading = toText(headingNode ? headingNode.textContent : '');

            const rows = [];
            pane.querySelectorAll('table tbody tr').forEach((tr) => {
              const cells = Array.from(tr.querySelectorAll('td')).map((cell) => toText(cell.textContent));
              if (cells.length < 4) {
                return;
              }
              rows.push({
                lectureNo: cells[0],
                date: cells[1],
                durationHours: cells[2],
                presence: cells[3],
              });
            });

            if (!paneId && rows.length === 0) {
              return;
            }

            courses.push({
              paneId,
              courseCode: tabMeta.code || '',
              courseTitle: tabMeta.title || '',
              heading,
              attendanceRows: rows,
            });
          });

          return JSON.stringify({
            sourceUrl: window.location.href,
            capturedAt: new Date().toISOString(),
            selectedSemester,
            semesters,
            courses,
            dashboardLinks: {
              attendance: toAbsolute('/Student/StudentAttendance'),
              marks: toAbsolute('/Student/StudentMarks'),
              transcript: toAbsolute('/Student/Transcript'),
            }
          });
        })();
      ''');

      final payload = _normalizeJavaScriptResult(result);
      if (payload.isEmpty) {
        return;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_attendanceDataKey, jsonEncode(decoded));
    } catch (_) {
      // Intentionally ignored: attendance table can render after page-finished.
    }
  }

  Future<void> _activateAllMarksTabs() async {
    final countResult = await _controller.runJavaScriptReturningResult('''
      (function() {
        return document.querySelectorAll(
          'a.m-tabs_link[href^="#"], .nav-tabs a[href^="#"], a[data-toggle="tab"][href^="#"]'
        ).length;
      })();
    ''');

    final tabCount = int.tryParse(_normalizeJavaScriptResult(countResult)) ?? 0;
    for (var index = 0; index < tabCount; index++) {
      await _controller.runJavaScript('''
        (function() {
          const tabs = document.querySelectorAll(
            'a.m-tabs_link[href^="#"], .nav-tabs a[href^="#"], a[data-toggle="tab"][href^="#"]'
          );
          if (tabs[$index]) {
            tabs[$index].click();
          }
        })();
      ''');
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  Future<void> _expandAllMarksSections() async {
    await _controller.runJavaScript('''
      (function() {
        document.querySelectorAll(
          '.card-header button[data-toggle="collapse"], .card-header .btn-link'
        ).forEach((button) => {
          if (button.classList.contains('collapsed')) {
            button.click();
          }
        });
      })();
    ''');
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<bool> _waitForTranscriptAndCapture() async {
    widget.onSyncProgress?.call('Scraping academic transcript...');
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) {
        return false;
      }

      await _captureTranscriptData();

      if (await _transcriptHasCourseData()) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    await _captureTranscriptData();
    return true;
  }

  Future<bool> _transcriptHasCourseData() async {
    final result = await _controller.runJavaScriptReturningResult('''
      (function() {
        const blocks = document.querySelectorAll('.col-md-6');
        for (const block of blocks) {
          if (block.querySelector('h5') && block.querySelectorAll('table tbody tr').length > 0) {
            return true;
          }
        }
        return false;
      })();
    ''');

    return result == true;
  }

  Future<void> _captureTranscriptData() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const toText = (value) => (value || '').replace(/\\s+/g, ' ').trim();

          const parseStat = (label) => {
            const node = Array.from(document.querySelectorAll('.pull-right span')).find(
              (span) => toText(span.textContent).toLowerCase().startsWith(label.toLowerCase())
            );
            if (!node) {
              return '';
            }
            const text = toText(node.textContent);
            const parts = text.split(':');
            return parts.length > 1 ? toText(parts.slice(1).join(':')) : text;
          };

          const semesters = [];
          document.querySelectorAll('.col-md-6').forEach((block) => {
            const semesterNameNode = block.querySelector('h5');
            const table = block.querySelector('table');
            if (!semesterNameNode || !table) {
              return;
            }

            const semesterName = toText(semesterNameNode.textContent);
            const statsContainer = block.querySelector('.pull-right');
            const stats = statsContainer
                ? Array.from(statsContainer.querySelectorAll('span')).map((span) => ({
                    label: toText(span.textContent).split(':')[0] || '',
                    value: toText(span.textContent).split(':').slice(1).join(':').trim(),
                  }))
                : [];

            const courses = [];
            table.querySelectorAll('tbody tr').forEach((tr) => {
              const cells = Array.from(tr.querySelectorAll('td')).map((cell) => toText(cell.textContent));
              if (cells.length < 8) {
                return;
              }

              courses.push({
                code: cells[0],
                courseName: cells[1],
                section: cells[2],
                creditHours: cells[3],
                grade: cells[4],
                points: cells[5],
                type: cells[6],
                remarks: cells[7],
              });
            });

            semesters.push({
              name: semesterName,
              stats: stats.length > 0
                  ? stats
                  : [
                      { label: 'Cr. Att', value: parseStat('Cr. Att') },
                      { label: 'Cr. Ernd', value: parseStat('Cr. Ernd') },
                      { label: 'CGPA', value: parseStat('CGPA') },
                      { label: 'SGPA', value: parseStat('SGPA') },
                    ],
              courses: courses,
            });
          });

          return JSON.stringify({
            sourceUrl: window.location.href,
            capturedAt: new Date().toISOString(),
            semesters: semesters,
          });
        })();
      ''');

      final payload = _normalizeJavaScriptResult(result);
      if (payload.isEmpty) {
        return;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_transcriptDataKey, jsonEncode(decoded));

      // Populate flex_selected_sync_semester automatically from transcript ONLY if user has not selected one yet
      final existingSem = preferences.getString('flex_selected_sync_semester');
      if (existingSem == null || existingSem.isEmpty) {
        if (decoded['semesters'] is List) {
          final sems = decoded['semesters'] as List;
          if (sems.isNotEmpty) {
            final lastSem = sems.last;
            if (lastSem is Map<String, dynamic>) {
              final semName = (lastSem['name'] as String? ?? '').trim();
              final parts = semName.split(RegExp(r'\s+'));
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
                  final autoSemId = '$yr$tCode';
                  await preferences.setString('flex_selected_sync_semester', autoSemId);
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Transcript content can render after the page finishes loading.
    }
  }

  Future<bool> _waitForMarksAndCapture() async {
    widget.onSyncProgress?.call('Scraping marks evaluations...');
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) {
        return false;
      }

      await _activateAllMarksTabs();
      await _expandAllMarksSections();
      final captured = await _captureMarksData();

      if (captured) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    await _activateAllMarksTabs();
    await _expandAllMarksSections();
    return _captureMarksData();
  }

  Future<bool> _captureMarksData() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const toText = (value) => (value || '').replace(/\\s+/g, ' ').trim();

          const cellText = (row, selector, fallbackIndex) => {
            const cell = row.querySelector(selector);
            if (cell) {
              return toText(cell.textContent);
            }
            const cells = row.querySelectorAll('td');
            if (fallbackIndex >= 0 && cells[fallbackIndex]) {
              return toText(cells[fallbackIndex].textContent);
            }
            return '';
          };

          const semesterSelect = document.querySelector('#SemId');
          let selectedSemester = null;

          if (semesterSelect) {
            semesterSelect.querySelectorAll('option').forEach((option) => {
              const entry = {
                id: toText(option.value),
                name: toText(option.textContent),
                selected: !!option.selected,
              };
              if (entry.selected) {
                selectedSemester = entry;
              }
            });
          }

          const tabsByPane = {};
          document.querySelectorAll(
            'a.m-tabs_link[href^="#"], .nav-tabs a[href^="#"], a[data-toggle="tab"][href^="#"]'
          ).forEach((tab) => {
            const href = tab.getAttribute('href') || '';
            const paneId = href.startsWith('#') ? href.substring(1) : href;
            if (!paneId) {
              return;
            }
            tabsByPane[paneId] = toText(tab.textContent);
          });

          const courses = [];
          document.querySelectorAll(
            '.tab-content .tab-pane[id], .tab-pane[role="tabpanel"][id]'
          ).forEach((pane) => {
            const paneId = pane.getAttribute('id') || '';
            const headingNode = pane.querySelector('h5, h4, .m-portlet__head-text, .card-header h5, .card-header h4');
            const heading = toText(headingNode ? headingNode.textContent : '');

            let courseCode = tabsByPane[paneId] || paneId;
            let courseTitle = '';
            const headingMatch = heading.match(/^([A-Za-z]{2}\\d{4})\\s*[-–]\\s*(.+)\$/);
            if (headingMatch) {
              courseCode = headingMatch[1].toUpperCase();
              courseTitle = toText(headingMatch[2]);
            } else if (heading) {
              courseTitle = heading;
            }

            const sections = [];
            pane.querySelectorAll('.card').forEach((card) => {
              const headerNode = card.querySelector(
                '.card-header button, .card-header .btn-link, .card-header h5, .card-header h4, .card-header a, .card-header'
              );
              const table = card.querySelector('table.sum_table, table');
              if (!table) {
                return;
              }

              const sectionName = toText(headerNode ? headerNode.textContent : '') ||
                toText((table.querySelector('thead th') || {}).textContent || '') ||
                'Section';

              const itemLabel = toText(
                (table.querySelector('thead th') || {}).textContent || 'Item'
              );

              const rows = [];
              table.querySelectorAll('tbody tr.calculationrow, tbody tr, tr.GrandtotalColumn').forEach((tr) => {
                const isGrandTotal = tr.classList.contains('GrandtotalColumn') || tr.closest('tfoot') !== null;
                
                let itemNo, weightage, obtained, total, average, stdDev, minimum, maximum;
                
                if (isGrandTotal) {
                  itemNo = '';
                  weightage = '';
                  obtained = cellText(tr, 'td.GrandtotalObtMarks', 1);
                  total = cellText(tr, 'td.GrandtotalColMarks', 0);
                  average = cellText(tr, 'td.GrandtotalClassAvg', 2);
                  minimum = cellText(tr, 'td.GrandtotalClassMin', 3);
                  maximum = cellText(tr, 'td.GrandtotalClassMax', 4);
                  stdDev = cellText(tr, 'td.GrandtotalClassStdDev', 5);
                } else {
                  itemNo = cellText(tr, 'td:first-child', 0);
                  weightage = cellText(tr, 'td.weightage', 1);
                  obtained = cellText(tr, 'td.ObtMarks', 2);
                  total = cellText(tr, 'td.GrandTotal', 3);
                  average = cellText(tr, 'td.AverageMarks', 4);
                  stdDev = cellText(tr, 'td.StdDev', 5);
                  minimum = cellText(tr, 'td.MinMarks', 6);
                  maximum = cellText(tr, 'td.MaxMarks', 7);
                }

                if (!itemNo && !obtained && !total) {
                  return;
                }

                rows.push({
                  itemNo,
                  weightage,
                  obtained,
                  total,
                  average,
                  stdDev,
                  minimum,
                  maximum,
                });
              });

              sections.push({
                sectionName,
                itemLabel,
                rows,
              });
            });

            if (!paneId && !heading && sections.length === 0) {
              return;
            }

            courses.push({
              paneId,
              courseCode,
              courseTitle,
              heading,
              sections,
            });
          });

          return JSON.stringify({
            sourceUrl: window.location.href,
            capturedAt: new Date().toISOString(),
            selectedSemester,
            courses,
          });
        })();
      ''');

      final payload = _normalizeJavaScriptResult(result);
      if (payload.isEmpty) {
        return false;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final courses = decoded['courses'];
      final hasCapturedMarks =
          courses is List &&
          courses.any((course) {
            if (course is! Map) {
              return false;
            }

            final sections = course['sections'];
            if (sections is! List) {
              return false;
            }

            return sections.any((section) {
              if (section is! Map) {
                return false;
              }

              final rows = section['rows'];
              return rows is List && rows.isNotEmpty;
            });
          });

      if (!hasCapturedMarks) {
        return false;
      }

      final preferences = await SharedPreferences.getInstance();
      final oldJsonString = preferences.getString(_marksDataKey);
      await MarksStorage.compareAndHighlightNewMarks(decoded, oldJsonString);
      await preferences.setString(_marksDataKey, jsonEncode(decoded));
      return true;
    } catch (_) {
      // Intentionally ignored: marks tables can render after page-finished.
      return false;
    }
  }

  String _normalizeJavaScriptResult(Object? result) {
    if (result == null) {
      return '';
    }

    if (result is String) {
      final raw = result.trim();
      if (raw.isEmpty) {
        return '';
      }

      if (raw.startsWith('"') && raw.endsWith('"')) {
        try {
          final unwrapped = jsonDecode(raw);
          if (unwrapped is String) {
            return unwrapped;
          }
        } catch (_) {
          return raw;
        }
      }

      return raw;
    }

    return result.toString();
  }

  Future<void> _injectCredentials() async {
    _hasInjectedCredentials = true;

    await _controller.runJavaScript('''
      (function() {
        const usernameField = document.querySelector('input[name="username"]');
        const passwordField = document.querySelector('input#pass[name="password"]');

        if (usernameField) {
          usernameField.value = ${_jsString(widget.rollNumber)};
          usernameField.dispatchEvent(new Event('input', { bubbles: true }));
          usernameField.dispatchEvent(new Event('change', { bubbles: true }));
        }

        if (passwordField) {
          passwordField.value = ${_jsString(widget.password)};
          passwordField.dispatchEvent(new Event('input', { bubbles: true }));
          passwordField.dispatchEvent(new Event('change', { bubbles: true }));
        }
      })();
    ''');
  }

  Future<void> _waitForCaptchaAndIsolate() async {
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) {
        return;
      }

      final ready = await _isolateCaptchaOnly();
      if (ready == true) {
        if (mounted) {
          setState(() {
            _isCaptchaReady = true;
          });
        }
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<bool?> _isolateCaptchaOnly() async {
    return _controller
        .runJavaScriptReturningResult('''
      (function() {
        const captcha = document.querySelector('.g-recaptcha');
        if (!captcha) {
          return false;
        }

        if (document.getElementById('flex-captcha-only-style')) {
          return true;
        }

        const style = document.createElement('style');
        style.id = 'flex-captcha-only-style';
        const isRecaptchaElement = (element) => {
          if (!element || element === document.body || element === document.documentElement) {
            return true;
          }

          if (element === captcha || captcha.contains(element) || element.contains(captcha)) {
            return true;
          }

          if (element.tagName === 'SCRIPT' || element.tagName === 'STYLE' || element.tagName === 'LINK') {
            return true;
          }

          if (element.tagName === 'IFRAME') {
            const src = (element.getAttribute('src') || '').toLowerCase();
            const title = (element.getAttribute('title') || '').toLowerCase();
            if (src.includes('recaptcha') || title.includes('recaptcha')) {
              return true;
            }
          }

          if (element.tagName === 'DIV') {
            const iframe = element.querySelector('iframe[src*="recaptcha"], iframe[title*="recaptcha"]');
            if (iframe) {
              return true;
            }
          }

          return false;
        };

        const revealRecaptchaElements = () => {
          // Hide all elements that are not part of the recaptcha system
          document.querySelectorAll('body *').forEach((element) => {
            if (isRecaptchaElement(element)) {
              return;
            }

            element.style.setProperty('display', 'none', 'important');
          });

          // Style and show the recaptcha elements and their ancestors
          document.querySelectorAll('.g-recaptcha, iframe[src*="recaptcha"], iframe[title*="recaptcha"]').forEach((element) => {
            let node = element;
            while (node) {
              if (node !== document.body && node !== document.documentElement) {
                // Check if this node is the wrapper parent of a challenge iframe
                const challengeIframe = document.querySelector('iframe[src*="bframe"], iframe[title*="challenge"]');
                const isChallengeWrapper = challengeIframe && node === challengeIframe.parentElement;

                if (isChallengeWrapper) {
                  node.style.setProperty('display', 'block', 'important');
                  node.style.setProperty('visibility', 'visible', 'important');
                  node.style.setProperty('overflow', 'visible', 'important');
                  node.style.setProperty('position', 'fixed', 'important');
                  node.style.setProperty('top', '50%', 'important');
                  node.style.setProperty('left', '50%', 'important');
                  node.style.setProperty('z-index', '2000000000', 'important');
                  node.style.setProperty('background-color', '#ffffff', 'important');
                  node.style.setProperty('border', '1px solid #d3d3d3', 'important');
                  node.style.setProperty('border-radius', '8px', 'important');
                  node.style.setProperty('box-shadow', '0 4px 15px rgba(0,0,0,0.15)', 'important');
                  node.style.setProperty('padding', '0', 'important');
                  node.style.setProperty('margin', '0', 'important');

                  // Scale the challenge window if it exceeds the viewport size
                  const screenWidth = window.innerWidth;
                  const screenHeight = window.innerHeight;
                  const wrapperWidth = node.offsetWidth || 400;
                  const wrapperHeight = node.offsetHeight || 580;
                  let scaleX = 1;
                  let scaleY = 1;
                  if (screenWidth < wrapperWidth + 20) {
                    scaleX = (screenWidth - 20) / wrapperWidth;
                  }
                  if (screenHeight < wrapperHeight + 20) {
                    scaleY = (screenHeight - 20) / wrapperHeight;
                  }
                  const scale = Math.min(scaleX, scaleY);
                  node.style.setProperty('transform', `translate(-50%, -50%) scale(\${scale})`, 'important');
                  node.style.setProperty('transform-origin', 'center center', 'important');
                } else {
                  // Regular ancestor element
                  node.style.setProperty('display', 'block', 'important');
                  node.style.setProperty('visibility', 'visible', 'important');
                  node.style.setProperty('overflow', 'visible', 'important');
                  node.style.setProperty('background', 'transparent', 'important');
                  node.style.setProperty('border', 'none', 'important');
                  node.style.setProperty('padding', '0', 'important');
                  node.style.setProperty('margin', '0', 'important');
                }
              } else {
                // Ensure body/html are visible
                node.style.setProperty('visibility', 'visible', 'important');
                node.style.setProperty('overflow', 'visible', 'important');
              }
              node = node.parentElement;
            }
          });
        };

        style.textContent = `
          html, body {
            margin: 0 !important;
            padding: 0 !important;
            background: #ffffff !important;
            overflow: visible !important;
            height: 100% !important;
          }

          #g-recaptcha-response {
            display: none !important;
          }
        `;
        document.head.appendChild(style);

        revealRecaptchaElements();

        captcha.style.cssText = [
          'display:block',
          'visibility:visible',
          'position:relative',
          'margin:0 auto',
          'z-index:1'
        ].join(' !important;') + ' !important;';

        document.body.style.setProperty('background', '#ffffff', 'important');
        document.body.style.setProperty('display', 'flex', 'important');
        document.body.style.setProperty('flex-direction', 'column', 'important');
        document.body.style.setProperty('align-items', 'center', 'important');
        document.body.style.setProperty('justify-content', 'center', 'important');
        document.body.style.setProperty('height', '100vh', 'important');
        document.body.style.setProperty('min-height', '100vh', 'important');
        document.body.style.setProperty('margin', '0', 'important');
        document.documentElement.style.setProperty('background', '#ffffff', 'important');

        if (!window.flexRecaptchaObserver) {
          window.flexRecaptchaObserver = new MutationObserver(revealRecaptchaElements);
          window.flexRecaptchaObserver.observe(document.body, {
            childList: true,
            subtree: true
          });
        }

        return true;
      })();
    ''')
        .then((result) => result == true);
  }

  Future<void> _attachAutoSubmitWhenCaptchaSolved() async {
    if (_hasAttachedAutoSubmit) {
      return;
    }

    _hasAttachedAutoSubmit = true;

    await _controller.runJavaScript('''
      (function() {
        const form = document.getElementById('frmlogin');
        const captchaResponse = document.getElementById('g-recaptcha-response');
        const submitButton = document.getElementById('m_login_signin_submit');

        if (!form || !captchaResponse || !submitButton) {
          return;
        }

        const submitWhenSolved = () => {
          if (captchaResponse.value && !submitButton.dataset.flexAutoSubmitted) {
            submitButton.dataset.flexAutoSubmitted = 'true';
            submitButton.click();
          }
        };

        submitWhenSolved();

        const observer = new MutationObserver(submitWhenSolved);
        observer.observe(captchaResponse, { attributes: true, attributeFilter: ['value'] });

        const timer = setInterval(submitWhenSolved, 1000);

        form.addEventListener('submit', () => {
          clearInterval(timer);
          observer.disconnect();
        });
      })();
    ''');
  }

  String _jsString(String value) {
    return jsonEncode(value);
  }

  double _sheetHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.78).clamp(560.0, screenHeight * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = _sheetHeight(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: Colors.white,
        child: SizedBox(
          height: sheetHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _isCaptchaReady ? 1 : 0,
                  child: WebViewWidget(controller: _controller),
                ),
              ),
              if (!_isCaptchaReady)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
