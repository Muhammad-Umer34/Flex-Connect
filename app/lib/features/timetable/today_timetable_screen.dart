import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/timetable_models.dart';
import '../../services/timetable_storage.dart';
import '../../services/datesheet_storage.dart';
import '../../services/datesheet_parser.dart';
import '../../services/home_widget_service.dart';
import 'timetable_screen.dart';
import 'utils/timetable_utils.dart';

class TodayTimetableScreen extends StatefulWidget {
  const TodayTimetableScreen({
    super.key,
    this.initialDay,
  });

  final String? initialDay;

  @override
  State<TodayTimetableScreen> createState() => _TodayTimetableScreenState();
}

class _TodayTimetableScreenState extends State<TodayTimetableScreen> {
  bool _isLoading = true;
  String? _section;
  String? _dept;
  List<TimetableDayEvent> _allEvents = [];
  List<DatesheetEvent> _datesheetEvents = [];

  late String _selectedDay;
  late final Timer _tickerTimer;
  DateTime _now = DateTime.now();

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _green = Color(0xFF10B981); // Emerald
  static const Color _purple = Color(0xFF8B5CF6);

  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? _getCurrentWeekdayName();
    _loadData();

    // Refresh time ticker every 30 seconds for live progress bar
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer.cancel();
    super.dispose();
  }

  String _getCurrentWeekdayName() {
    final weekday = DateTime.now().weekday;
    if (weekday >= 1 && weekday <= 6) {
      return _weekdays[weekday - 1];
    }
    return 'Monday';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final snapshot = await TimetableStorage.load();
    final dept = await TimetableStorage.loadSelectedDept();
    final section = await TimetableStorage.loadSelectedSection();
    final customEvents = await TimetableStorage.loadCustomEvents();
    final datesheet = await DatesheetStorage.load() ?? [];

    final events = <TimetableDayEvent>[];
    if (customEvents.isNotEmpty) {
      events.addAll(customEvents);
    } else if (snapshot != null && section != null) {
      for (final ev in snapshot.schedule) {
        if (ev.section.trim().toUpperCase() == section.trim().toUpperCase()) {
          events.add(ev);
        }
      }
    }

    if (mounted) {
      setState(() {
        _section = section;
        _dept = dept;
        _allEvents = events;
        _datesheetEvents = datesheet;
        _isLoading = false;
      });
    }
  }

  String _normalizeDay(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('mon')) return 'Monday';
    if (lower.startsWith('tue')) return 'Tuesday';
    if (lower.startsWith('wed')) return 'Wednesday';
    if (lower.startsWith('thu')) return 'Thursday';
    if (lower.startsWith('fri')) return 'Friday';
    if (lower.startsWith('sat')) return 'Saturday';
    return raw.trim();
  }

  List<_ParsedDayClass> _getClassesForSelectedDay() {
    final dayEvents = _allEvents.where((e) => _normalizeDay(e.day).toLowerCase() == _selectedDay.toLowerCase()).toList();

    final parsed = dayEvents.map((e) {
      final range = _parseClassTime(e.time);
      return _ParsedDayClass(
        event: e,
        startMinutes: range?['start'] ?? 0,
        endMinutes: range?['end'] ?? 0,
      );
    }).where((c) => c.startMinutes > 0 && c.endMinutes > 0).toList();

    parsed.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return parsed;
  }

  Map<String, int>? _parseClassTime(String timeStr) {
    try {
      final parts = timeStr.split('-');
      if (parts.length != 2) return null;

      final startClean = parts[0].replaceAll(RegExp(r'[ap]m', caseSensitive: false), '').trim();
      final endClean = parts[1].replaceAll(RegExp(r'[ap]m', caseSensitive: false), '').trim();

      final startParts = startClean.split(':');
      final endParts = endClean.split(':');
      if (startParts.length != 2 || endParts.length != 2) return null;

      var startH = int.parse(startParts[0].trim());
      final startM = int.parse(startParts[1].trim());
      var endH = int.parse(endParts[0].trim());
      final endM = int.parse(endParts[1].trim());

      if (startH >= 1 && startH <= 7) startH += 12;
      if (endH >= 1 && endH <= 7) endH += 12;

      return {
        'start': startH * 60 + startM,
        'end': endH * 60 + endM,
      };
    } catch (_) {
      return null;
    }
  }

  DatesheetEvent? _getTodayExam() {
    final todayDate = DateTime(_now.year, _now.month, _now.day);
    for (final exam in _datesheetEvents) {
      final clean = exam.date.trim();
      final parts = clean.split(RegExp(r'[-/\s,]+'));
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final monthName = parts[1].toLowerCase();
        final year = int.tryParse(parts[2]) ?? _now.year;

        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
          'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
          'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        final month = months[monthName.substring(0, monthName.length.clamp(0, 3))] ?? 1;
        if (day == todayDate.day && month == todayDate.month && year == todayDate.year) {
          return exam;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final isActualToday = _selectedDay.toLowerCase() == _getCurrentWeekdayName().toLowerCase();
    final todayExam = isActualToday ? _getTodayExam() : null;
    final classes = _getClassesForSelectedDay();

    final currentMinutes = _now.hour * 60 + _now.minute;

    _ParsedDayClass? ongoingClass;
    _ParsedDayClass? nextClass;
    var maxEndMinutes = 0;

    for (final c in classes) {
      if (c.endMinutes > maxEndMinutes) maxEndMinutes = c.endMinutes;
      if (isActualToday) {
        if (currentMinutes >= c.startMinutes && currentMinutes < c.endMinutes) {
          ongoingClass = c;
        } else if (currentMinutes < c.startMinutes && nextClass == null) {
          nextClass = c;
        }
      }
    }

    final allDone = isActualToday && classes.isNotEmpty && ongoingClass == null && nextClass == null && currentMinutes >= maxEndMinutes;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Timetable",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            if (_section != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _section!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _accent,
                      ),
                    ),
                  ),
                  if (_dept != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      getDeptFullName(_dept!),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Weekly Timetable',
            icon: const Icon(Icons.calendar_month_rounded, color: _accent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimetableScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: muted),
            onPressed: () async {
              await _loadData();
              await HomeWidgetService.updateNextClassWidget();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadData();
                await HomeWidgetService.updateNextClassWidget();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Day Selector Pills
                  _buildDaySelector(isDark: isDark, surface: surface, border: border, ink: ink, muted: muted),
                  const SizedBox(height: 16),

                  // Datesheet Exam Card (if today is exam day)
                  if (todayExam != null) ...[
                    _buildExamBanner(todayExam, isDark: isDark),
                    const SizedBox(height: 16),
                  ],

                  // Hero Live Status Card (only on actual today)
                  if (isActualToday) ...[
                    if (ongoingClass != null)
                      _buildHeroLiveCard(
                        ongoingClass: ongoingClass,
                        currentMinutes: currentMinutes,
                        nextClass: nextClass,
                        isDark: isDark,
                      )
                    else if (nextClass != null)
                      _buildHeroNextUpCard(
                        nextClass: nextClass,
                        currentMinutes: currentMinutes,
                        isDark: isDark,
                      )
                    else if (allDone)
                      _buildHeroAllDoneCard(isDark: isDark)
                    else if (classes.isEmpty && todayExam == null)
                      _buildHeroOffDayCard(isDark: isDark),
                    const SizedBox(height: 20),
                  ],

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 18, color: _accent),
                          const SizedBox(width: 8),
                          Text(
                            "$_selectedDay's Schedule",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${classes.length} ${classes.length == 1 ? 'class' : 'classes'}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Classes Timeline List
                  if (classes.isEmpty)
                    _buildEmptyScheduleCard(isDark: isDark, surface: surface, border: border, muted: muted)
                  else
                    for (int i = 0; i < classes.length; i++) ...[
                      _buildClassTimelineItem(
                        item: classes[i],
                        index: i,
                        isFirst: i == 0,
                        isLast: i == classes.length - 1,
                        isActualToday: isActualToday,
                        currentMinutes: currentMinutes,
                        isDark: isDark,
                        surface: surface,
                        border: border,
                        ink: ink,
                        muted: muted,
                      ),
                    ],

                  const SizedBox(height: 24),

                  // Quick Switch to Full Timetable button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TimetableScreen()),
                      );
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 18, color: _accent),
                    label: const Text(
                      "View Full Weekly Timetable",
                      style: TextStyle(fontWeight: FontWeight.bold, color: _accent),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDaySelector({
    required bool isDark,
    required Color surface,
    required Color border,
    required Color ink,
    required Color muted,
  }) {
    final currentDay = _getCurrentWeekdayName();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _weekdays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = _weekdays[index];
          final isSelected = day.toLowerCase() == _selectedDay.toLowerCase();
          final isToday = day.toLowerCase() == currentDay.toLowerCase();

          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _selectedDay = day;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _accent
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _accent : border,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.substring(0, 3),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isToday ? _accent : ink),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamBanner(DatesheetEvent exam, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF78350F), const Color(0xFF451A03)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade500.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        exam.type.toUpperCase(),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Exam Today",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  exam.courseName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      size: 13,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      exam.time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroLiveCard({
    required _ParsedDayClass ongoingClass,
    required int currentMinutes,
    _ParsedDayClass? nextClass,
    required bool isDark,
  }) {
    final duration = (ongoingClass.endMinutes - ongoingClass.startMinutes).clamp(1, 480);
    final elapsed = (currentMinutes - ongoingClass.startMinutes).clamp(0, duration);
    final progress = elapsed / duration;
    final remainingMins = ongoingClass.endMinutes - currentMinutes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: isDark ? 0.15 : 0.08),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "LIVE NOW",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "$remainingMins mins left",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ongoingClass.event.course,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF064E3B),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, size: 14, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)),
              const SizedBox(width: 4),
              Text(
                ongoingClass.event.time,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46),
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.location_on_rounded, size: 14, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)),
              const SizedBox(width: 4),
              Text(
                ongoingClass.event.room,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
          if (nextClass != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    "Next: ",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF065F46),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "${nextClass.event.course} (${nextClass.event.time})",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF047857),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroNextUpCard({
    required _ParsedDayClass nextClass,
    required int currentMinutes,
    required bool isDark,
  }) {
    final minsUntil = nextClass.startMinutes - currentMinutes;
    final hours = minsUntil ~/ 60;
    final mins = minsUntil % 60;
    final timeStr = hours > 0 ? "$hours h $mins m" : "$mins mins";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF172554)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: isDark ? 0.15 : 0.08),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 5),
                    Text(
                      "NEXT UP",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "Starts in $timeStr",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nextClass.event.course,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
              const SizedBox(width: 4),
              Text(
                nextClass.event.time,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E40AF),
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.location_on_rounded, size: 14, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
              const SizedBox(width: 4),
              Text(
                nextClass.event.room,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAllDoneCard({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration_rounded, color: _purple, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "All Classes Done Today",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "You're free for the rest of the day. Relax and prepare for tomorrow.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroOffDayCard({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.coffee_rounded, color: _accent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No Classes Today",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Enjoy your free day or catch up on coursework.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyScheduleCard({
    required bool isDark,
    required Color surface,
    required Color border,
    required Color muted,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: muted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              "No classes scheduled for $_selectedDay",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Take a break or check other days above.",
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassTimelineItem({
    required _ParsedDayClass item,
    required int index,
    required bool isFirst,
    required bool isLast,
    required bool isActualToday,
    required int currentMinutes,
    required bool isDark,
    required Color surface,
    required Color border,
    required Color ink,
    required Color muted,
  }) {
    final isOngoing = isActualToday && currentMinutes >= item.startMinutes && currentMinutes < item.endMinutes;
    final isDone = isActualToday && currentMinutes >= item.endMinutes;

    Color statusColor = _accent;
    String statusLabel = "Upcoming";
    IconData statusIcon = Icons.access_time_rounded;

    if (isOngoing) {
      statusColor = _green;
      statusLabel = "In Progress";
      statusIcon = Icons.radio_button_checked_rounded;
    } else if (isDone) {
      statusColor = muted;
      statusLabel = "Completed";
      statusIcon = Icons.check_circle_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Indicator Bar
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? _green
                        : (isDone ? muted : surface),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOngoing ? _green : (isDone ? muted : _accent),
                      width: 2.5,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone ? border : _accent.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Class Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOngoing
                    ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                    : surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOngoing
                      ? _green.withValues(alpha: 0.6)
                      : border,
                  width: isOngoing ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.event.time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOngoing ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)) : ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.event.course,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDone ? muted : ink,
                      decoration: isDone ? TextDecoration.none : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: muted),
                            const SizedBox(width: 4),
                            Text(
                              item.event.room.isNotEmpty ? item.event.room : "TBA",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.event.section.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.event.section,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedDayClass {
  final TimetableDayEvent event;
  final int startMinutes;
  final int endMinutes;

  _ParsedDayClass({
    required this.event,
    required this.startMinutes,
    required this.endMinutes,
  });
}
