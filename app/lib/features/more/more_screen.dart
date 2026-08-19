import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/marks_storage.dart';
import '../../main.dart';
import '../timetable/timetable_screen.dart';
import 'past_papers_screen.dart';
import 'absolute_grading_calculator_screen.dart';
import 'relative_grading_calculator_screen.dart';
import 'faculty_review_screen.dart';
import 'faculty_timetable_screen.dart';
import 'free_room_finder_screen.dart';
import 'rechecking_schedule_screen.dart';
import 'datesheet_screen.dart';
import 'feedback_screen.dart';
import '../gpa/cgpa_roadmap_simulator_screen.dart';

import '../auth/credential_gate.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                
                final preferences = await SharedPreferences.getInstance();
                await preferences.clear();
                MarksStorage.highlightedCoursesNotifier.value = [];
                
                if (context.mounted) {
                  RestartWidget.restartApp(context);
                }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        foregroundColor: isDark ? Colors.white : _ink,
        title: const Text(
          'More Features',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // Section: ACADEMIC UTILITIES
          _buildCategoryHeader(context, 'Academic Utilities'),
          _buildCategoryContainer(
            isDark: isDark,
            children: [
              _buildModernTile(
                context: context,
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'Timetable Generator',
                subtitle: 'Upload and filter classes easily',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TimetableScreen()),
                  );
                },
                showDivider: true,
              ),

              _buildModernTile(
                context: context,
                icon: Icons.event_note_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Datesheet Generator',
                subtitle: 'Generate customized exam schedule',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DatesheetScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.calculate_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Grading Calculator',
                subtitle: 'NUCES Absolute Grading Scheme tool',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AbsoluteGradingCalculatorScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.analytics_rounded,
                iconColor: const Color(0xFF0D9488),
                title: 'Relative Calculator',
                subtitle: 'Mean Average relative grading mapping',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RelativeGradingCalculatorScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.auto_graph_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Graduation CGPA Simulator',
                subtitle: 'Simulate target SGPA needed for remaining semesters',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CgpaRoadmapSimulatorScreen()),
                  );
                },
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section: CAMPUS RESOURCES
          _buildCategoryHeader(context, 'Campus Resources'),
          _buildCategoryContainer(
            isDark: isDark,
            children: [
              _buildModernTile(
                context: context,
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: 'Past Papers & Resources',
                subtitle: 'Drive archives for exams & assignments',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PastPapersScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.assignment_turned_in_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Exam Rechecking Schedule',
                subtitle: 'Paper showing and rechecking deadlines',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RecheckingScheduleScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF0284C7),
                title: 'Faculty Review',
                subtitle: 'Search faculty profile directory',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FacultyReviewScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFFEA580C),
                title: 'Faculty Timetable Tracker',
                subtitle: 'Find teachers and check their current status',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FacultyTimetableScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildModernTile(
                context: context,
                icon: Icons.meeting_room_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Free Room Finder',
                subtitle: 'Find empty classrooms and study spaces',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FreeRoomFinderScreen()),
                  );
                },
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section: APP & SUPPORT
          _buildCategoryHeader(context, 'App Settings & Support'),
          _buildCategoryContainer(
            isDark: isDark,
            children: [
              _buildModernTile(
                context: context,
                icon: Icons.feedback_rounded,
                iconColor: const Color(0xFFE11D48),
                title: 'Send Feedback',
                subtitle: 'Report issues or suggest enhancements',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FeedbackScreen()),
                  );
                },
                showDivider: true,
              ),
              _buildAutoSyncSettingTile(context, isDark: isDark),
              _buildThemeSettingTile(context, isDark: isDark),
              _buildModernTile(
                context: context,
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Logout & Reset App',
                subtitle: 'Wipe all cached university details',
                onTap: () => _showLogoutConfirmationDialog(context),
                isDestructive: true,
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeSettingTile(BuildContext context, {required bool isDark}) {
    return _buildModernTile(
      context: context,
      icon: Icons.palette_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'App Theme',
      subtitle: 'Change appearance (System, Light, Dark)',
      onTap: () => _showThemeSelectionDialog(context),
      showDivider: true,
    );
  }

  Future<void> _showThemeSelectionDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppEntry.themeNotifier,
          builder: (context, currentMode, _) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Choose Theme',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeOptionTile(dialogContext, 'System Default', ThemeMode.system, isDark),
                  _buildThemeOptionTile(dialogContext, 'Light Mode', ThemeMode.light, isDark),
                  _buildThemeOptionTile(dialogContext, 'Dark Mode', ThemeMode.dark, isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOptionTile(BuildContext context, String title, ThemeMode mode, bool isDark) {
    final currentMode = AppEntry.themeNotifier.value;
    final isSelected = currentMode == mode;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: mode == ThemeMode.system
          ? const Text(
              'Matches your device light/dark appearance',
              style: TextStyle(fontSize: 11, color: _muted),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
          : null,
      onTap: () async {
        Navigator.of(context).pop();

        final prefs = await SharedPreferences.getInstance();
        String themeStr = 'system';
        if (mode == ThemeMode.light) {
          themeStr = 'light';
        } else if (mode == ThemeMode.dark) {
          themeStr = 'dark';
        }
        await prefs.setString('app_theme', themeStr);

        AppEntry.themeNotifier.value = mode;
      },
    );
  }

  Widget _buildAutoSyncSettingTile(BuildContext context, {required bool isDark}) {
    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            final prefs = snapshot.data;
            final isAutoSyncEnabled = prefs?.getBool('auto_sync_on_launch') ?? false;

            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                : const Color(0xFF2563EB).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.autorenew_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-sync on Launch',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sync portal automatically on app open',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isAutoSyncEnabled,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (value) async {
                            if (prefs != null) {
                              await prefs.setBool('auto_sync_on_launch', value);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCategoryContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildModernTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showDivider,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color textPrimary = isDestructive
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
        : (isDark ? Colors.white : _ink);
    
    final Color textSecondary = isDestructive
        ? (isDark ? const Color(0xFFFECACA).withValues(alpha: 0.7) : const Color(0xFFEF4444).withValues(alpha: 0.8))
        : (isDark ? const Color(0xFF94A3B8) : _muted);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2))
                          : (isDark ? iconColor.withValues(alpha: 0.12) : iconColor.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: isDestructive
                            ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                            : iconColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isDestructive) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
            ),
          ),
      ],
    );
  }
}
