class FacultyReview {
  final double rating;
  final String comment;
  final String userName;
  final DateTime timestamp;

  FacultyReview({
    required this.rating,
    required this.comment,
    required this.userName,
    required this.timestamp,
  });

  factory FacultyReview.fromJson(Map<String, dynamic> json) {
    return FacultyReview(
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Anonymous',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'comment': comment,
      'userName': userName,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
