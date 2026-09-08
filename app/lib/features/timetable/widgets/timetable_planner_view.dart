import 'package:flutter/material.dart';
import '../../../models/timetable_models.dart';
import '../utils/timetable_utils.dart';

class TimetablePlannerView extends StatefulWidget {
  const TimetablePlannerView({
    super.key,
    required this.selectedDept,
    required this.snapshot,
    required this.selectedSection,
    required this.customEvents,
    required this.onAddCourse,
    required this.onRemoveCourse,
    required this.onChangeCourseSection,
    required this.isCourseSelected,
    required this.getSelectedSectionForCourse,
    required this.getAvailableSectionsForCourse,
    required this.doesSectionClashWithTimetable,
    required this.sectionMatches,
    required this.formatCourseEventsSubtitle,
  });

  final String? selectedDept;
  final TimetableSnapshot? snapshot;
  final String? selectedSection;
  final List<TimetableDayEvent> customEvents;
  final Function(String courseName, String section) onAddCourse;
  final Function(String courseName) onRemoveCourse;
  final Function(String courseName, String section) onChangeCourseSection;
  final bool Function(String courseName) isCourseSelected;
  final String? Function(String courseName) getSelectedSectionForCourse;
  final List<String> Function(String courseName) getAvailableSectionsForCourse;
  final bool Function(String courseName, String section) doesSectionClashWithTimetable;
  final bool Function(String section, String parentSection) sectionMatches;
  final String Function(List<TimetableDayEvent> events) formatCourseEventsSubtitle;

  @override
  State<TimetablePlannerView> createState() => _TimetablePlannerViewState();
}

class _TimetablePlannerViewState extends State<TimetablePlannerView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _searchedCourseName;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFF2563EB);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchSection(Color deptColor, bool isDark) {
    if (widget.snapshot == null || widget.selectedDept == null) return const SizedBox.shrink();

    final textInk = isDark ? Colors.white : _ink;
    final textMuted = isDark ? const Color(0xFF94A3B8) : _muted;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final fieldFill = isDark ? const Color(0xFF0F172A) : Colors.white;
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // 1. Get all unique courses in this department
    final deptSections = widget.snapshot!.sections[widget.selectedDept!] ?? [];
    final allDeptEvents = widget.snapshot!.schedule.where((e) => deptSections.contains(e.section)).toList();
    final allDeptCourses = allDeptEvents.map((e) => e.course.trim()).toSet().toList()..sort();

    // 2. Filter based on _searchQuery
    final filteredCourses = _searchQuery.isEmpty
        ? <String>[]
        : allDeptCourses
            .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: deptColor),
              const SizedBox(width: 8),
              Text(
                'Search & Add Course',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textInk),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: textInk),
            decoration: InputDecoration(
              hintText: 'Type course name...',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : textMuted),
              prefixIcon: Icon(Icons.search_outlined, color: isDark ? const Color(0xFF64748B) : textMuted),
              fillColor: fieldFill,
              filled: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: textMuted),
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
                borderSide: BorderSide(color: fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: fieldBorder),
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
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fieldBorder),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCourses.length,
                itemBuilder: (context, idx) {
                  final courseName = filteredCourses[idx];
                  return ListTile(
                    title: Text(courseName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textInk)),
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
            Divider(color: cardBorder),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Result:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textMuted),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textMuted),
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
              final availableSections = widget.getAvailableSectionsForCourse(courseName);
              if (availableSections.isEmpty) {
                return Text('No sections offering this course.', style: TextStyle(color: textMuted));
              }
              
              final isSelected = widget.isCourseSelected(courseName);
              final currentSection = widget.getSelectedSectionForCourse(courseName) ?? 
                  (availableSections.contains(widget.selectedSection) ? widget.selectedSection! : availableSections.first);
              
              final displayEvents = widget.snapshot!.schedule.where((e) =>
                e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
                widget.sectionMatches(e.section, currentSection)
              ).toList();

              final currentSectionClashes = widget.doesSectionClashWithTimetable(courseName, currentSection);

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentSectionClashes
                        ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                        : fieldBorder,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textInk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.formatCourseEventsSubtitle(displayEvents),
                      style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
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
                            Text('Sec: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textInk)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: fieldBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: SizedBox(
                                  height: 20,
                                  child: DropdownButton<String>(
                                    value: currentSection,
                                    isDense: true,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 11),
                                    onChanged: (String? newSec) {
                                      if (newSec != null) {
                                        if (isSelected) {
                                          widget.onChangeCourseSection(courseName, newSec);
                                        } else {
                                          widget.onAddCourse(courseName, newSec);
                                        }
                                        setState(() {});
                                      }
                                    },
                                    items: availableSections.map<DropdownMenuItem<String>>((s) {
                                      final itemClashes = widget.doesSectionClashWithTimetable(courseName, s);
                                      return DropdownMenuItem<String>(
                                        value: s,
                                        child: Text(
                                          itemClashes ? '$s (Clash)' : s,
                                          style: TextStyle(color: isDark ? Colors.white : _ink),
                                        ),
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
                              widget.onRemoveCourse(courseName);
                            } else {
                              widget.onAddCourse(courseName, currentSection);
                            }
                            setState(() {});
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

  @override
  Widget build(BuildContext context) {
    if (widget.snapshot == null || widget.selectedSection == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textInk = isDark ? Colors.white : _ink;
    final textMuted = isDark ? const Color(0xFF94A3B8) : _muted;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final deptColor = widget.selectedDept != null ? getDeptColor(widget.selectedDept!) : Colors.indigo;

    // 1. Get all courses in the parent section (e.g. CS-6B)
    final parentEvents = widget.snapshot!.schedule.where((e) => widget.sectionMatches(e.section, widget.selectedSection!)).toList();
    final parentCourseNames = parentEvents.map((e) => e.course.trim()).toSet().toList()..sort();

    // 2. Custom cross-section choices (courses not in parent section)
    final parentCourseNamesLower = parentCourseNames.map((e) => e.toLowerCase().trim()).toSet();
    final customOtherEvents = widget.customEvents.where((e) =>
      !parentCourseNamesLower.contains(e.course.toLowerCase().trim())
    ).toList();
    final customOtherCourseNames = customOtherEvents.map((e) => e.course.trim()).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Autocomplete search interface
        _buildSearchSection(deptColor, isDark),
        const SizedBox(height: 24),

        // Primary classes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classes for Section ${widget.selectedSection}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textInk),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _accent),
              onPressed: () async {
                for (final courseName in parentCourseNames) {
                  if (!widget.isCourseSelected(courseName)) {
                    await widget.onAddCourse(courseName, widget.selectedSection!);
                  }
                }
                setState(() {});
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
            final isSelected = widget.isCourseSelected(courseName);
            final currentSection = widget.getSelectedSectionForCourse(courseName) ?? widget.selectedSection!;
            
            final displayEvents = widget.snapshot!.schedule.where((e) =>
              e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
              widget.sectionMatches(e.section, currentSection)
            ).toList();

            final availableSections = widget.getAvailableSectionsForCourse(courseName);
            final currentSectionClashes = isSelected && widget.doesSectionClashWithTimetable(courseName, currentSection);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: currentSectionClashes
                      ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                      : cardBorder,
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textInk),
                        ),
                      ),
                      Switch(
                        activeThumbColor: Colors.white,
                        activeTrackColor: _accent,
                        value: isSelected,
                        onChanged: (bool val) {
                          if (val) {
                            widget.onAddCourse(courseName, widget.selectedSection!);
                          } else {
                            widget.onRemoveCourse(courseName);
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.formatCourseEventsSubtitle(displayEvents),
                    style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
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
                        Icon(Icons.compare_arrows_rounded, size: 16, color: textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Section:',
                          style: TextStyle(fontSize: 12, color: textInk, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: fieldBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: SizedBox(
                              height: 24,
                              child: DropdownButton<String>(
                                value: currentSection,
                                isDense: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 12),
                                onChanged: (String? newSection) {
                                  if (newSection != null) {
                                    widget.onChangeCourseSection(courseName, newSection);
                                    setState(() {});
                                  }
                                },
                                items: availableSections.map<DropdownMenuItem<String>>((String sec) {
                                  final itemClashes = widget.doesSectionClashWithTimetable(courseName, sec);
                                  return DropdownMenuItem<String>(
                                    value: sec,
                                    child: Text(
                                      itemClashes ? '$sec (Clash)' : sec,
                                      style: TextStyle(color: isDark ? Colors.white : _ink),
                                    ),
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
        Text(
          'Custom & Cross-Section Selections',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textInk),
        ),
        const SizedBox(height: 8),

        (() {
          if (customOtherCourseNames.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Center(
                child: Text(
                  'No cross-section or junior courses added yet.',
                  style: TextStyle(color: textMuted, fontSize: 12),
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
              final currentSection = widget.getSelectedSectionForCourse(courseName)!;
              
              final displayEvents = widget.snapshot!.schedule.where((e) =>
                e.course.toLowerCase().trim() == courseName.toLowerCase().trim() &&
                widget.sectionMatches(e.section, currentSection)
              ).toList();

              final availableSections = widget.getAvailableSectionsForCourse(courseName);
              final currentSectionClashes = widget.doesSectionClashWithTimetable(courseName, currentSection);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentSectionClashes
                        ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                        : cardBorder,
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textInk),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            widget.onRemoveCourse(courseName);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.formatCourseEventsSubtitle(displayEvents),
                      style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
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
                          Icon(Icons.compare_arrows_rounded, size: 16, color: textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Section:',
                            style: TextStyle(fontSize: 12, color: textInk, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: fieldBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: SizedBox(
                                height: 24,
                                child: DropdownButton<String>(
                                  value: currentSection,
                                  isDense: true,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  onChanged: (String? newSection) {
                                    if (newSection != null) {
                                      widget.onChangeCourseSection(courseName, newSection);
                                      setState(() {});
                                    }
                                  },
                                  items: availableSections.map<DropdownMenuItem<String>>((String sec) {
                                    final itemClashes = widget.doesSectionClashWithTimetable(courseName, sec);
                                    return DropdownMenuItem<String>(
                                      value: sec,
                                      child: Text(
                                        itemClashes ? '$sec (Clash)' : sec,
                                        style: TextStyle(color: isDark ? Colors.white : _ink),
                                      ),
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
}
