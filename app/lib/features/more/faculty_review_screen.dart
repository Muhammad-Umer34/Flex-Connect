import 'package:flutter/material.dart';
import '../../models/faculty.dart';
import '../../models/faculty_review.dart';
import '../../services/faculty_review_storage.dart';
import 'widgets/faculty_avatar.dart';
import 'widgets/faculty_details_sheet.dart';


class FacultyReviewScreen extends StatefulWidget {
  const FacultyReviewScreen({super.key});

  @override
  State<FacultyReviewScreen> createState() => _FacultyReviewScreenState();
}

class _FacultyReviewScreenState extends State<FacultyReviewScreen> {
  List<Faculty> _allFaculty = [];
  List<Faculty> _filteredFaculty = [];
  Map<String, List<String>> _campusDepartmentsMap = {};
  List<String> _campusesList = [];
  List<String> _departmentsList = [];
  Map<String, List<FacultyReview>> _reviewsMap = {};

  String _selectedCampus = 'All Campuses';
  String _selectedDepartment = 'All Departments';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray
  static const Color _flatBg = Color(0xFFF8FAFC); // Slate 50
  static const Color _flatBorder = Color(0xFFF1F5F9); // Slate 100

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final facultyList = await Faculty.loadFromAssets();
    final campusDeps = await Faculty.loadCampusesAndDepartments();
    final reviewsMap = await FacultyReviewStorage.loadAllReviews();

    // Setup campus list
    final campuses = ['All Campuses', ...campusDeps.keys.toList()..sort()];

    if (mounted) {
      setState(() {
        _allFaculty = facultyList;
        _filteredFaculty = facultyList;
        _campusDepartmentsMap = campusDeps;
        _campusesList = campuses;
        _reviewsMap = reviewsMap;
        _updateDepartmentsList();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _filterFaculty();
  }

  void _updateDepartmentsList() {
    if (_selectedCampus == 'All Campuses') {
      // Get all unique departments across all campuses
      final allDepts = <String>{};
      for (final depts in _campusDepartmentsMap.values) {
        allDepts.addAll(depts);
      }
      _departmentsList = ['All Departments', ...allDepts.toList()..sort()];
    } else {
      // Get departments of selected campus
      final depts = _campusDepartmentsMap[_selectedCampus] ?? [];
      _departmentsList = ['All Departments', ...depts.toList()..sort()];
    }
  }

  void _filterFaculty() {
    final query = _searchController.text.toLowerCase().trim();
    final campus = _selectedCampus == 'All Campuses' ? null : _selectedCampus;
    final department = _selectedDepartment == 'All Departments' ? null : _selectedDepartment;

    setState(() {
      _filteredFaculty = _allFaculty.where((faculty) {
        final matchesQuery = query.isEmpty ||
            faculty.name.toLowerCase().contains(query) ||
            faculty.email.toLowerCase().contains(query);

        final matchesCampus = campus == null || faculty.campus.toLowerCase() == campus.toLowerCase();
        final matchesDept = department == null || faculty.department.toLowerCase() == department.toLowerCase();

        return matchesQuery && matchesCampus && matchesDept;
      }).toList();
    });
  }

  void _showFacultyDetails(Faculty faculty) {
    final email = faculty.email.trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FacultyDetailsSheet(
          faculty: faculty,
          reviews: _reviewsMap[email] ?? [],
          onReviewSubmitted: (updatedReviews) {
            setState(() {
              _reviewsMap[email] = updatedReviews;
            });
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: _accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Faculty Review',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name Search bar
        TextField(
          controller: _searchController,
          style: TextStyle(color: isDark ? Colors.white : _ink),
          decoration: InputDecoration(
            hintText: 'Search faculty by name...',
            hintStyle: TextStyle(color: isDark ? Colors.grey[400] : _muted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_outlined, color: _accent),
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            filled: true,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : _muted),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Campus and Department Dropdowns
        Row(
          children: [
            // Campus Dropdown
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('campus_$_selectedCampus'),
                initialValue: _selectedCampus,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Campus',
                  labelStyle: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.bold),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                items: _campusesList.map((campus) {
                  return DropdownMenuItem<String>(
                    value: campus,
                    child: Text(
                      campus,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCampus = val;
                      _selectedDepartment = 'All Departments';
                      _updateDepartmentsList();
                      _filterFaculty();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),

            // Department Dropdown
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('dept_${_selectedCampus}_$_selectedDepartment'),
                initialValue: _selectedDepartment,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Department',
                  labelStyle: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.bold),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                items: _departmentsList.map((dept) {
                  return DropdownMenuItem<String>(
                    value: dept,
                    child: Text(
                      dept,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedDepartment = val;
                      _filterFaculty();
                    });
                  }
                },
              ),
            ),
          ],
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
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _accent),
                    SizedBox(height: 16),
                    Text(
                      'Loading faculty directories...',
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Filter and Header panel at the top
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Column(
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 20),
                        _buildFilters(context),
                      ],
                    ),
                  ),
                  
                  // Results Count Indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FOUND ${_filteredFaculty.length} FACULTY MEMBERS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.grey[400] : _muted,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Faculty Directory List
                  Expanded(
                    child: _filteredFaculty.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_alt_outlined,
                                    size: 80,
                                    color: isDark ? Colors.grey[700] : Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No faculty found',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : _ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try matching filters or search spelling',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : _muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            itemCount: _filteredFaculty.length,
                            itemBuilder: (context, index) {
                              final faculty = _filteredFaculty[index];
                              final email = faculty.email.trim();
                              final reviews = _reviewsMap[email] ?? [];
                              final hasReviews = reviews.isNotEmpty;
                              final avgRating = hasReviews
                                  ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
                                  : 0.0;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : _flatBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : _flatBorder,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showFacultyDetails(faculty),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            // Avatar
                                            FacultyAvatar(faculty: faculty, size: 52),
                                            const SizedBox(width: 16),
                                            
                                            // Faculty Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Name, Rating and HEC badge row
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          faculty.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 15,
                                                            color: isDark ? Colors.white : _ink,
                                                          ),
                                                        ),
                                                      ),
                                                      if (hasReviews) ...[
                                                        const SizedBox(width: 8),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons.star_rounded,
                                                              color: Colors.amber,
                                                              size: 16,
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              avgRating.toStringAsFixed(1),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                                color: isDark ? Colors.white70 : _ink.withValues(alpha: 0.8),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                      if (faculty.hecApproved) ...[
                                                        const SizedBox(width: 6),
                                                        const Icon(
                                                          Icons.verified_rounded,
                                                          color: Color(0xFF059669),
                                                          size: 16,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  
                                                  // Designation
                                                  Text(
                                                    faculty.designation,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: isDark ? Colors.grey[300] : _ink.withValues(alpha: 0.8),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  
                                                  // Campus and Dept
                                                  Text(
                                                    '${faculty.department} • ${faculty.campus}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? Colors.grey[400] : _muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 20,
                                              color: isDark ? Colors.grey[500] : _muted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
