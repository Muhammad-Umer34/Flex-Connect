class MarksChangelogEntry {
  MarksChangelogEntry({
    required this.id,
    required this.timestamp,
    required this.courseTitle,
    required this.itemNo,
    required this.changeType, // 'added' | 'updated'
    this.oldObtained,
    required this.newObtained,
    required this.total,
  });

  final String id;
  final DateTime timestamp;
  final String courseTitle;
  final String itemNo;
  final String changeType; // 'added' | 'updated'
  final String? oldObtained;
  final String newObtained;
  final String total;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'courseTitle': courseTitle,
      'itemNo': itemNo,
      'changeType': changeType,
      'oldObtained': oldObtained,
      'newObtained': newObtained,
      'total': total,
    };
  }

  factory MarksChangelogEntry.fromJson(Map<String, dynamic> json) {
    return MarksChangelogEntry(
      id: (json['id'] as String?) ?? '',
      timestamp: DateTime.parse((json['timestamp'] as String?) ?? DateTime.now().toIso8601String()),
      courseTitle: (json['courseTitle'] as String?) ?? '',
      itemNo: (json['itemNo'] as String?) ?? '',
      changeType: (json['changeType'] as String?) ?? 'added',
      oldObtained: json['oldObtained'] as String?,
      newObtained: (json['newObtained'] as String?) ?? '',
      total: (json['total'] as String?) ?? '',
    );
  }
}
