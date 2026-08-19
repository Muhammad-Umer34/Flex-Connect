import 'package:flutter/material.dart';
import '../../../models/faculty.dart';
import '../../../models/faculty_review.dart';

class FacultyReviewFormDialog extends StatefulWidget {
  const FacultyReviewFormDialog({
    super.key,
    required this.faculty,
    required this.onSubmitReview,
  });

  final Faculty faculty;
  final Future<void> Function(FacultyReview review) onSubmitReview;

  @override
  State<FacultyReviewFormDialog> createState() => _FacultyReviewFormDialogState();
}

class _FacultyReviewFormDialogState extends State<FacultyReviewFormDialog> {
  double selectedRating = 5.0;
  final nameController = TextEditingController();
  final commentController = TextEditingController();
  bool isSubmitting = false;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFF2563EB);

  @override
  void dispose() {
    nameController.dispose();
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Text(
        'Rate ${widget.faculty.name}',
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
                      setState(() {
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
                  final comment = commentController.text.trim();
                  if (comment.isEmpty) {
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

                  setState(() {
                    isSubmitting = true;
                  });

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  try {
                    await widget.onSubmitReview(review);
                    if (mounted) {
                      navigator.pop();
                    }
                  } catch (e) {
                    setState(() {
                      isSubmitting = false;
                    });
                    if (mounted) {
                      messenger.showSnackBar(
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
              : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
