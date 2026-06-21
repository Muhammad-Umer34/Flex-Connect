class TranscriptStat {
  const TranscriptStat({required this.label, required this.value});

  final String label;
  final String value;

  factory TranscriptStat.fromJson(Map<String, dynamic> json) {
    return TranscriptStat(
      label: (json['label'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
    );
  }
}

class TranscriptCourse {
  const TranscriptCourse({
    required this.code,
    required this.courseName,
    required this.section,
    required this.creditHours,
    required this.grade,
    required this.points,
    required this.type,
    required this.remarks,
  });

  final String code;
  final String courseName;
  final String section;
  final String creditHours;
  final String grade;
  final String points;
  final String type;
  final String remarks;

  factory TranscriptCourse.fromJson(Map<String, dynamic> json) {
    return TranscriptCourse(
      code: (json['code'] as String?) ?? '',
      courseName: (json['courseName'] as String?) ?? '',
      section: (json['section'] as String?) ?? '',
      creditHours: (json['creditHours'] as String?) ?? '',
      grade: (json['grade'] as String?) ?? '',
      points: (json['points'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      remarks: (json['remarks'] as String?) ?? '',
    );
  }
}

class TranscriptSemester {
  const TranscriptSemester({
    required this.name,
    required this.stats,
    required this.courses,
  });

  final String name;
  final List<TranscriptStat> stats;
  final List<TranscriptCourse> courses;

  String? get cgpa => _statValue('CGPA');
  String? get sgpa => _statValue('SGPA');
  String? get creditsAttempted => _statValue('Cr. Att');
  String? get creditsEarned => _statValue('Cr. Ernd');

  String? _statValue(String label) {
    for (final stat in stats) {
      if (stat.label.trim().toLowerCase() == label.trim().toLowerCase()) {
        return stat.value;
      }
    }
    return null;
  }

  factory TranscriptSemester.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'];
    final coursesJson = json['courses'];

    return TranscriptSemester(
      name: (json['name'] as String?) ?? '',
      stats: statsJson is List
          ? statsJson
                .whereType<Map>()
                .map(
                  (stat) =>
                      TranscriptStat.fromJson(stat.cast<String, dynamic>()),
                )
                .where((stat) => stat.label.isNotEmpty || stat.value.isNotEmpty)
                .toList(growable: false)
          : const [],
      courses: coursesJson is List
          ? coursesJson
                .whereType<Map>()
                .map(
                  (course) =>
                      TranscriptCourse.fromJson(course.cast<String, dynamic>()),
                )
                .where(
                  (course) =>
                      course.code.isNotEmpty || course.courseName.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class TranscriptSnapshot {
  const TranscriptSnapshot({
    required this.semesters,
    required this.capturedAt,
    required this.sourceUrl,
  });

  final List<TranscriptSemester> semesters;
  final DateTime? capturedAt;
  final String? sourceUrl;

  factory TranscriptSnapshot.fromJson(Map<String, dynamic> json) {
    final semestersJson = json['semesters'];

    DateTime? capturedAt;
    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is String) {
      capturedAt = DateTime.tryParse(capturedAtRaw);
    }

    return TranscriptSnapshot(
      semesters: semestersJson is List
          ? semestersJson
                .whereType<Map>()
                .map(
                  (semester) => TranscriptSemester.fromJson(
                    semester.cast<String, dynamic>(),
                  ),
                )
                .where(
                  (semester) =>
                      semester.name.isNotEmpty || semester.courses.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
      capturedAt: capturedAt,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }
}
