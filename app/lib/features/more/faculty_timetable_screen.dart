import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/timetable_models.dart';
import '../../services/timetable_storage.dart';
import '../../models/faculty.dart';
import '../../models/faculty_review.dart';
import '../../services/faculty_review_storage.dart';
import 'widgets/faculty_details_sheet.dart';
import 'widgets/faculty_avatar.dart';

class FacultyTimetableScreen extends StatefulWidget {
  const FacultyTimetableScreen({super.key});

  @override
  State<FacultyTimetableScreen> createState() => _FacultyTimetableScreenState();
}

class _FacultyTimetableScreenState extends State<FacultyTimetableScreen> {
  bool _isLoading = true;
  bool _timetableNotConfigured = false;
  
  List<_TeacherItem> _allTeachers = [];
  List<_TeacherItem> _filteredTeachers = [];
  _TeacherItem? _selectedTeacher;
  
  final TextEditingController _searchController = TextEditingController();
  List<TimetableDayEvent> _teacherSchedule = [];

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  @override
  void initState() {
    super.initState();
    _loadProfessors();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessors() async {
    try {
      final snapshot = await TimetableStorage.load();
      final allFaculty = await Faculty.loadFromAssets();
      
      final prefs = await SharedPreferences.getInstance();
      final studentCampus = prefs.getString('student_campus') ?? 'Islamabad';

      if (snapshot == null) {
        setState(() {
          _isLoading = false;
          _timetableNotConfigured = true;
        });
        return;
      }

      // Extract unique teacher names from timetable schedule events
      final uniqueNames = snapshot.schedule
          .map((e) => e.teacher.trim())
          .where((t) => t.isNotEmpty && t.toLowerCase() != 'staff' && t.toLowerCase() != 'n/a')
          .toSet()
          .toList();

      final resolvedTeachers = <_TeacherItem>[];

      for (final name in uniqueNames) {
        final matchedFaculty = _findMatchingFaculty(name, allFaculty);
        
        // Filter by user's campus if faculty directory details are available
        if (matchedFaculty != null) {
          if (matchedFaculty.campus.toLowerCase().trim() == studentCampus.toLowerCase().trim()) {
            resolvedTeachers.add(_TeacherItem(
              timetableName: name,
              faculty: matchedFaculty,
            ));
          }
        } else {
          // If no matching faculty in directory, default-keep them as we assume the timetable 
          // uploaded is specific to the student's campus anyway
          resolvedTeachers.add(_TeacherItem(
            timetableName: name,
            faculty: null,
          ));
        }
      }

      // Sort alphabetically
      resolvedTeachers.sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted) {
        setState(() {
          _allTeachers = resolvedTeachers;
          _filteredTeachers = resolvedTeachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading faculty timetable tracker: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredTeachers = _allTeachers.where((teacher) {
        final matchesTimetableName = teacher.timetableName.toLowerCase().contains(query);
        final matchesFacultyName = teacher.faculty?.name.toLowerCase().contains(query) ?? false;
        final matchesEmail = teacher.faculty?.email.toLowerCase().contains(query) ?? false;
        return matchesTimetableName || matchesFacultyName || matchesEmail;
      }).toList();
    });
  }

  void _selectTeacher(_TeacherItem teacher) async {
    final snapshot = await TimetableStorage.load();
    if (snapshot == null) return;

    // Filter all events for this teacher
    final schedule = snapshot.schedule
        .where((e) => e.teacher.trim().toLowerCase() == teacher.timetableName.toLowerCase())
        .toList();

    setState(() {
      _selectedTeacher = teacher;
      _teacherSchedule = schedule;
      _searchController.clear();
    });
  }

  /// word-overlap matching logic to link timetable name to official faculty profile
  Faculty? _findMatchingFaculty(String timetableName, List<Faculty> facultyList) {
    final cleanTimetable = _normalizeName(timetableName);
    if (cleanTimetable.isEmpty) return null;

    // 1. Check exact match after normalization
    for (final f in facultyList) {
      final cleanFaculty = _normalizeName(f.name);
      if (cleanFaculty == cleanTimetable) return f;
    }

    // 2. Try word-overlap matching
    final timetableWords = cleanTimetable.split(' ');
    Faculty? bestMatch;
    double bestScore = 0.0;

    for (final f in facultyList) {
      final cleanFaculty = _normalizeName(f.name);
      final facultyWords = cleanFaculty.split(' ');
      
      int commonWords = 0;
      for (final tw in timetableWords) {
        if (facultyWords.contains(tw)) {
          commonWords++;
        }
      }

      if (commonWords > 0) {
        final score = commonWords / (timetableWords.length + facultyWords.length - commonWords);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = f;
        }
      }
    }

    // Accept match if overlap similarity score is high (e.g. at least 40% match)
    if (bestScore >= 0.4) {
      return bestMatch;
    }
    return null;
  }

  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\b(dr|mr|ms|mrs|prof|engr|phd)\.?\b'), '')
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
    );
    try {
      // Launch external application mode prompts Gmail or default mail composer
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open email compose to $email')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening email client: $e')),
        );
      }
    }
  }

  void _showFacultyReviews(Faculty faculty) async {
    setState(() => _isLoading = true);
    final reviewsMap = await FacultyReviewStorage.loadAllReviews();
    final reviews = reviewsMap[faculty.email.trim()] ?? [];
    
    if (mounted) {
      setState(() => _isLoading = false);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return FacultyDetailsSheet(
            faculty: faculty,
            reviews: reviews,
            onReviewSubmitted: (_) {}, // Read-only trigger wrapper
          );
        },
      );
    }
  }

  /// Checks if teacher is currently taking a class based on current time & day
  TimetableDayEvent? _getBusyClass() {
    final now = DateTime.now();
    final todayName = _getWeekdayName(now.weekday);

    final todayClasses = _teacherSchedule
        .where((e) => e.day.trim().toLowerCase() == todayName.toLowerCase())
        .toList();

    for (final c in todayClasses) {
      if (_isClassCurrentlyActive(c.time)) {
        return c;
      }
    }
    return null;
  }

  bool _isClassCurrentlyActive(String timeStr) {
    try {
      final now = DateTime.now();
      final parts = timeStr.split('-');
      if (parts.length != 2) return false;

      final startParts = parts[0].trim().split(':');
      final endParts = parts[1].trim().split(':');

      if (startParts.length != 2 || endParts.length != 2) return false;

      var startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      var endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      // Normalize 12-hour afternoon slots (01:00 to 07:00) to 24-hour clock (13 to 19)
      if (startHour >= 1 && startHour <= 7) {
        startHour += 12;
      }
      if (endHour >= 1 && endHour <= 7) {
        endHour += 12;
      }

      final start = DateTime(now.year, now.month, now.day, startHour, startMin);
      final end = DateTime(now.year, now.month, now.day, endHour, endMin);

      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }

  String _getWeekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    if (weekday >= 1 && weekday <= 7) {
      return names[weekday - 1];
    }
    return 'Monday';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color inkColor = isDark ? const Color(0xFFF1F5F9) : _ink;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: inkColor,
        title: const Text(
          'Faculty Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedTeacher != null) {
              setState(() {
                _selectedTeacher = null;
                _teacherSchedule = [];
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timetableNotConfigured
              ? _buildNotConfiguredState(isDark, cardBgColor, borderColor, inkColor)
              : _selectedTeacher != null
                  ? _buildTeacherDetailView(isDark, cardBgColor, borderColor, inkColor)
                  : _buildTeacherSearchView(isDark, cardBgColor, borderColor, inkColor),
    );
  }

  Widget _buildNotConfiguredState(bool isDark, Color cardBg, Color borderCol, Color ink) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'No Timetable Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Please upload and configure your campus timetable Excel sheet under the Timetable Generator utility tab first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSearchView(bool isDark, Color cardBg, Color borderCol, Color ink) {
    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: _muted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search professors...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    style: TextStyle(fontSize: 14, color: ink),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Icon(Icons.clear, color: _muted, size: 18),
                  ),
              ],
            ),
          ),
        ),
        // List results
        Expanded(
          child: _filteredTeachers.isEmpty
              ? Center(
                  child: Text(
                    'No professors found.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredTeachers.length,
                  itemBuilder: (context, index) {
                    final item = _filteredTeachers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _accent.withOpacity(0.08),
                          child: Text(
                            item.displayName[0].toUpperCase(),
                            style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          item.displayName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ink),
                        ),
                        subtitle: item.faculty != null
                            ? Text(
                                '${item.faculty!.designation} • ${item.faculty!.department}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : const Text(
                                'Campus Directory Info Unavailable',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => _selectTeacher(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeacherDetailView(bool isDark, Color cardBg, Color borderCol, Color ink) {
    final teacher = _selectedTeacher!;
    final faculty = teacher.faculty;
    final busyClass = _getBusyClass();
    final todayName = _getWeekdayName(DateTime.now().weekday);

    // Group teacher events by Day of the week
    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final scheduleMap = <String, List<TimetableDayEvent>>{};
    for (final day in daysOfWeek) {
      scheduleMap[day] = _teacherSchedule
          .where((e) => e.day.trim().toLowerCase() == day.toLowerCase())
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher Header profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                // Avatar representation
                faculty != null
                    ? FacultyAvatar(
                        faculty: faculty,
                        size: 80,
                      )
                    : CircleAvatar(
                        radius: 40,
                        backgroundColor: _accent.withOpacity(0.08),
                        child: Text(
                          teacher.displayName[0].toUpperCase(),
                          style: const TextStyle(color: _accent, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
                const SizedBox(height: 16),
                Text(
                  teacher.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ink),
                ),
                if (faculty != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    faculty.designation,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  Text(
                    faculty.department,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Contact details click actions
                  GestureDetector(
                    onTap: () => _launchEmail(faculty.email.trim()),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.email_outlined, size: 18, color: _accent),
                        const SizedBox(width: 8),
                        Text(
                          faculty.email.trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showFacultyReviews(faculty),
                    icon: const Icon(Icons.reviews_rounded, size: 18),
                    label: const Text('View Faculty Reviews'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Campus Directory profile details not linked.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real-time Class Status Card (Shown only if busy)
          if (busyClass != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT STATUS: IN CLASS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${busyClass.course} (${busyClass.section})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${busyClass.room}  •  🕒 ${busyClass.time}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Weekly timetable list
          Text(
            'WEEKLY SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Days Loop
          ...daysOfWeek.map((day) {
            final events = scheduleMap[day] ?? [];
            if (events.isEmpty) return const SizedBox.shrink();

            final isToday = day.toLowerCase() == todayName.toLowerCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday ? _accent : borderCol,
                  width: isToday ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isToday ? _accent : ink,
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Class list
                  ...events.map((e) {
                    final isCurrentlyActive = isToday && _isClassCurrentlyActive(e.time);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrentlyActive
                                  ? const Color(0xFFFEF2F2)
                                  : isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e.time,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurrentlyActive ? const Color(0xFFEF4444) : ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.course,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '📍 ${e.room}  •  Section: ${e.section}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _TeacherItem {
  final String timetableName;
  final Faculty? faculty;

  _TeacherItem({
    required this.timetableName,
    required this.faculty,
  });

  String get displayName {
    if (faculty != null) {
      return faculty!.name.trim();
    }
    return timetableName;
  }
}
