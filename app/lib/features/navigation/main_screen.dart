import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../transcript/transcript_screen.dart';
import '../attendance/attendance_screen.dart';
import '../marks/marks_screen.dart';
import '../gpa/gpa_screen.dart';
import '../more/more_screen.dart';
import '../../services/update_service.dart';
import '../../services/marks_storage.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;
  final GlobalKey<TranscriptScreenState> _transcriptKey = GlobalKey();
  final GlobalKey<AttendanceScreenState> _attendanceKey = GlobalKey();
  final GlobalKey<MarksScreenState> _marksKey = GlobalKey();
  final GlobalKey<GpaScreenState> _gpaKey = GlobalKey();

  /// Track which tabs have been visited so we only build them once needed.
  final Set<int> _visitedTabs = {0}; // Home is always visited

  @override
  void initState() {
    super.initState();
    MarksStorage.updateHighlightsNotifier();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  late final List<Widget> pages = [
    const HomeScreen(),
    TranscriptScreen(key: _transcriptKey),
    AttendanceScreen(key: _attendanceKey),
    MarksScreen(key: _marksKey),
    GpaScreen(key: _gpaKey),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: index,
        sizing: StackFit.expand,
        children: [
          for (int i = 0; i < pages.length; i++)
            _visitedTabs.contains(i)
                ? pages[i]
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  selectedIcon: Icons.home_rounded,
                  unselectedIcon: Icons.home_outlined,
                  label: "Home",
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 1,
                  selectedIcon: Icons.receipt_long_rounded,
                  unselectedIcon: Icons.receipt_long_outlined,
                  label: "Transcript",
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 2,
                  selectedIcon: Icons.how_to_reg_rounded,
                  unselectedIcon: Icons.how_to_reg_outlined,
                  label: "Attendance",
                  isDark: isDark,
                ),
                ValueListenableBuilder<List<String>>(
                  valueListenable: MarksStorage.highlightedCoursesNotifier,
                  builder: (context, highlighted, _) {
                    return _buildNavItem(
                      index: 3,
                      selectedIcon: Icons.grading_rounded,
                      unselectedIcon: Icons.grading_outlined,
                      label: "Marks",
                      isDark: isDark,
                      hasBadge: highlighted.isNotEmpty,
                    );
                  },
                ),
                _buildNavItem(
                  index: 4,
                  selectedIcon: Icons.leaderboard_rounded,
                  unselectedIcon: Icons.leaderboard_outlined,
                  label: "GPA",
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 5,
                  selectedIcon: Icons.more_horiz_rounded,
                  unselectedIcon: Icons.more_horiz_outlined,
                  label: "More",
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required bool isDark,
    bool hasBadge = false,
  }) {
    final isSelected = this.index == index;
    final activeColor = const Color(0xFF2563EB); // Royal Blue
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B); // Slate Gray

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            this.index = index;
            _visitedTabs.add(index);
          });
          if (index == 1) {
            _transcriptKey.currentState?.reload();
          }
          if (index == 2) {
            _attendanceKey.currentState?.reload();
          }
          if (index == 3) {
            _marksKey.currentState?.reload();
          }
          if (index == 4) {
            _gpaKey.currentState?.reload();
          }
        },
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated top indicator line
            Positioned(
              top: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: 3,
                width: isSelected ? 36 : 0,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ),
            ),
            // Tab content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : unselectedIcon,
                      color: isSelected ? activeColor : inactiveColor,
                      size: 22,
                    ),
                    if (hasBadge)
                      Positioned(
                        top: -2,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
