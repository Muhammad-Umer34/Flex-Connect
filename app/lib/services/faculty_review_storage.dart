import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/faculty_review.dart';

class FacultyReviewStorage {
  static final _supabase = Supabase.instance.client;

  /// Load all saved reviews from Supabase to pre-populate list average scores in one query
  static Future<Map<String, List<FacultyReview>>> loadAllReviews() async {
    try {
      print('--- loadAllReviews started ---');
      final List<dynamic> response = await _supabase
          .from('faculty_reviews')
          .select();
      print('--- loadAllReviews response: ${response.length} rows ---');
      
      final reviewsMap = <String, List<FacultyReview>>{};
      for (final row in response) {
        final email = row['professor_email'] as String;
        final review = FacultyReview(
          rating: (row['rating'] as num).toDouble(),
          comment: row['comment'] as String,
          userName: row['user_name'] as String,
          timestamp: DateTime.parse(row['created_at'] as String),
        );
        (reviewsMap[email] ??= []).add(review);
      }
      return reviewsMap;
    } catch (e, stack) {
      print('Error in loadAllReviews: $e');
      print('Stack trace: $stack');
      return {};
    }
  }

  /// Get reviews for a specific professor email from Supabase
  static Future<List<FacultyReview>> getReviews(String email) async {
    try {
      print('--- getReviews started for $email ---');
      final List<dynamic> response = await _supabase
          .from('faculty_reviews')
          .select()
          .eq('professor_email', email)
          .order('created_at', ascending: false);
      print('--- getReviews response: ${response.length} rows ---');
      
      return response.map((row) => FacultyReview(
        rating: (row['rating'] as num).toDouble(),
        comment: row['comment'] as String,
        userName: row['user_name'] as String,
        timestamp: DateTime.parse(row['created_at'] as String),
      )).toList();
    } catch (e, stack) {
      print('Error in getReviews for $email: $e');
      print('Stack trace: $stack');
      return [];
    }
  }

  /// Submit a review for a specific professor email to Supabase
  static Future<void> addReview(String email, FacultyReview review) async {
    await _supabase.from('faculty_reviews').insert({
      'professor_email': email,
      'rating': review.rating,
      'comment': review.comment,
      'user_name': review.userName,
    });
  }
}
