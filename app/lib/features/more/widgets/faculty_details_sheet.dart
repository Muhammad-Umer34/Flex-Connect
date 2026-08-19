import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/faculty.dart';
import '../../../models/faculty_review.dart';
import '../../../services/faculty_review_storage.dart';
import 'faculty_avatar.dart';
import 'faculty_review_form.dart';

class FacultyDetailsSheet extends StatefulWidget {
  const FacultyDetailsSheet({
    super.key,
    required this.faculty,
    required this.reviews,
    required this.onReviewSubmitted,
  });

  final Faculty faculty;
  final List<FacultyReview> reviews;
  final ValueChanged<List<FacultyReview>> onReviewSubmitted;

  @override
  State<FacultyDetailsSheet> createState() => _FacultyDetailsSheetState();
}

class _FacultyDetailsSheetState extends State<FacultyDetailsSheet> {
  late List<FacultyReview> _localReviews;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _flatBg = Color(0xFFF8FAFC);
  static const Color _flatBorder = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _localReviews = List.from(widget.reviews);
  }

  @override
  void didUpdateWidget(covariant FacultyDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviews != widget.reviews) {
      _localReviews = List.from(widget.reviews);
    }
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
            SnackBar(content: Text('Could not send email to $email')),
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
        if (trailing != null) trailing,
      ],
    );
  }

  void _showAddReviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return FacultyReviewFormDialog(
          faculty: widget.faculty,
          onSubmitReview: (review) async {
            final email = widget.faculty.email.trim();
            await FacultyReviewStorage.addReview(email, review);
            final updatedReviews = await FacultyReviewStorage.getReviews(email);
            setState(() {
              _localReviews = updatedReviews;
            });
            widget.onReviewSubmitted(updatedReviews);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Review submitted successfully!')),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasReviews = _localReviews.isNotEmpty;
    final avgRating = hasReviews
        ? _localReviews.map((r) => r.rating).reduce((a, b) => a + b) / _localReviews.length
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
              onPressed: _showAddReviewDialog,
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
                    'Based on ${_localReviews.length} reviews',
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
            itemCount: _localReviews.length,
            separatorBuilder: (context, idx) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final review = _localReviews[idx];
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
  }

  @override
  Widget build(BuildContext context) {
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
                  FacultyAvatar(faculty: widget.faculty, size: 96),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    widget.faculty.name,
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
                    widget.faculty.designation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : _muted,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // HEC Status Badge
                  if (widget.faculty.hecApproved)
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
                          value: widget.faculty.campus,
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          context,
                          icon: Icons.school_outlined,
                          label: 'Department',
                          value: widget.faculty.department,
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          context,
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: widget.faculty.email,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.faculty.email));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        if (widget.faculty.extension.isNotEmpty && widget.faculty.extension != '-') ...[
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            icon: Icons.phone_in_talk_outlined,
                            label: 'Extension',
                            value: widget.faculty.extension,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Ratings & Reviews Section
                  _buildReviewsSection(context),
                  const SizedBox(height: 24),

                  // Social & Profile Actions
                  Row(
                    children: [
                      if (widget.faculty.profileUrl.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL(widget.faculty.profileUrl),
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
                      if (widget.faculty.profileUrl.isNotEmpty && widget.faculty.linkedin.isNotEmpty)
                        const SizedBox(width: 12),
                      if (widget.faculty.linkedin.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL(widget.faculty.linkedin),
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
                    onPressed: () => _launchEmail(widget.faculty.email),
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
  }
}
