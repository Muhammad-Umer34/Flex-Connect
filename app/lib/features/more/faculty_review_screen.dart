import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/faculty.dart';
import '../../models/faculty_review.dart';
import '../../services/faculty_review_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching URL: $e')),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
    );
    try {
      if (!await launchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open email client for $email')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching email: $e')),
        );
      }
    }
  }

  Widget _buildAvatar(Faculty faculty, {double size = 48}) {
    final imgUrl = faculty.imgUrl.trim();
    final hasImage = imgUrl.isNotEmpty && 
        (imgUrl.startsWith('http://') || imgUrl.startsWith('https://'));

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imgUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar(faculty.name, size);
          },
        ),
      );
    } else {
      return _buildInitialsAvatar(faculty.name, size);
    }
  }

  Widget _buildInitialsAvatar(String name, double size) {
    final initials = name
        .split(' ')
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'dr.' && s.toLowerCase() != 'mr.' && s.toLowerCase() != 'ms.')
        .map((s) => s[0])
        .take(2)
        .join('')
        .toUpperCase();

    final displayInitials = initials.isNotEmpty
        ? initials
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF), // Soft Blue
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        displayInitials,
        style: TextStyle(
          color: const Color(0xFF2563EB), // Royal Blue
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  void _showFacultyDetails(Faculty faculty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Pull Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      // Large Avatar
                      _buildAvatar(faculty, size: 96),
                      const SizedBox(height: 16),
                      
                      // Name
                      Text(
                        faculty.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Designation
                      Text(
                        faculty.designation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : _muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // HEC Status Badge
                      if (faculty.hecApproved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Color(0xFF065F46), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'HEC Approved Supervisor',
                                style: TextStyle(
                                  color: Color(0xFF065F46),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      
                      // Details List
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : _flatBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : _flatBorder,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              context,
                              icon: Icons.business_outlined,
                              label: 'Campus',
                              value: faculty.campus,
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              context,
                              icon: Icons.school_outlined,
                              label: 'Department',
                              value: faculty.department,
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              context,
                              icon: Icons.mail_outline,
                              label: 'Email',
                              value: faculty.email,
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: faculty.email));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Email copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (faculty.extension.isNotEmpty && faculty.extension != '-') ...[
                              const Divider(height: 24),
                              _buildDetailRow(
                                context,
                                icon: Icons.phone_in_talk_outlined,
                                label: 'Extension',
                                value: faculty.extension,
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Ratings & Reviews Section
                      _buildReviewsSection(context, faculty),
                      const SizedBox(height: 24),
                      
                      // Social & Profile Actions
                      Row(
                        children: [
                          if (faculty.profileUrl.isNotEmpty)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _launchURL(faculty.profileUrl),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.language_rounded, size: 18),
                                label: const Text('View Profile'),
                              ),
                            ),
                          if (faculty.profileUrl.isNotEmpty && faculty.linkedin.isNotEmpty)
                            const SizedBox(width: 12),
                          if (faculty.linkedin.isNotEmpty)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _launchURL(faculty.linkedin),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A66C2), // LinkedIn Blue
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.link_rounded, size: 18),
                                label: const Text('LinkedIn'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Direct email button
                      OutlinedButton.icon(
                        onPressed: () => _launchEmail(faculty.email),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: _accent),
                          foregroundColor: _accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Send Email'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsSection(BuildContext context, Faculty faculty) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final email = faculty.email.trim();
        final reviews = _reviewsMap[email] ?? [];
        final hasReviews = reviews.isNotEmpty;
        final avgRating = hasReviews
            ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RATINGS & REVIEWS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.grey[400] : _muted,
                    letterSpacing: 1.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddReviewDialog(faculty, setSheetState),
                  icon: const Icon(Icons.rate_review_outlined, size: 16, color: _accent),
                  label: const Text(
                    'Write a Review',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Average rating summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : _flatBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : _flatBorder,
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            hasReviews ? avgRating.toStringAsFixed(1) : '—',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : _ink,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ 5.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : _muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on ${reviews.length} reviews',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : _muted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Stars row
                  Row(
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      return Icon(
                        starVal <= avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: starVal <= avgRating.round() ? Colors.amber : Colors.grey.shade400,
                        size: 24,
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Reviews List
            if (!hasReviews)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No reviews yet. Be the first to rate this professor!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey[400] : _muted,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (context, idx) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final review = reviews[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              review.userName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : _ink,
                              ),
                            ),
                            const Spacer(),
                            // Small stars indicator
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < review.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: i < review.rating.round() ? Colors.amber : Colors.grey.shade400,
                                  size: 14,
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          review.comment,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : _ink.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(review.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[500] : _muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _showAddReviewDialog(Faculty faculty, StateSetter setSheetState) {
    double selectedRating = 5.0;
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(
                'Rate ${faculty.name}',
                style: TextStyle(
                  color: isDark ? Colors.white : _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stars Selector
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final starVal = index + 1.0;
                          return IconButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedRating = starVal;
                              });
                            },
                            icon: Icon(
                              starVal <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: starVal <= selectedRating ? Colors.amber : Colors.grey.shade400,
                              size: 36,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name Input
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : _ink),
                      decoration: InputDecoration(
                        labelText: 'Your Name (Optional)',
                        labelStyle: const TextStyle(color: _accent, fontSize: 12),
                        hintText: 'Anonymous Student',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : _muted, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Comment Input
                    TextField(
                      controller: commentController,
                      style: TextStyle(color: isDark ? Colors.white : _ink),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comment',
                        labelStyle: const TextStyle(color: _accent, fontSize: 12),
                        hintText: 'Share your experience with this professor...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : _muted, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          debugPrint('--- Faculty Review Submit Pressed ---');
                          final comment = commentController.text.trim();
                          debugPrint('Comment content: "$comment"');
                          if (comment.isEmpty) {
                            debugPrint('Submit aborted: comment is empty.');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a comment')),
                            );
                            return;
                          }

                          final name = nameController.text.trim().isNotEmpty
                              ? nameController.text.trim()
                              : 'Anonymous Student';

                          final review = FacultyReview(
                            rating: selectedRating,
                            comment: comment,
                            userName: name,
                            timestamp: DateTime.now(),
                          );

                          final email = faculty.email.trim();
                          debugPrint('Submitting review for: $email');
                          debugPrint('Supabase Rest URL: ${Supabase.instance.client.rest.url}');

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            debugPrint('Calling FacultyReviewStorage.addReview...');
                            await FacultyReviewStorage.addReview(email, review);
                            debugPrint('FacultyReviewStorage.addReview complete.');

                            // Update parent and bottom sheet state immediately
                            debugPrint('Fetching updated reviews...');
                            final updatedReviews = await FacultyReviewStorage.getReviews(email);
                            debugPrint('Reviews fetched: ${updatedReviews.length}');

                            if (mounted) {
                              setState(() {
                                _reviewsMap[email] = updatedReviews;
                              });
                              setSheetState(() {
                                _reviewsMap[email] = updatedReviews;
                              });
                            }

                            if (context.mounted) {
                              debugPrint('Popping dialog and showing success SnackBar.');
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Review submitted successfully!')),
                              );
                            }
                          } catch (e, stack) {
                            debugPrint('Error during review submission: $e');
                            debugPrint('Stack trace: $stack');
                            if (mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to submit review: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _accent, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[400] : _muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : _ink,
              ),
            ),
          ],
        ),
        const Spacer(),
        ?trailing,
      ],
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
                                            _buildAvatar(faculty, size: 52),
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
