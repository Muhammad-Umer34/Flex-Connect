class AttendanceSemester {
  const AttendanceSemester({required this.id, required this.name});

  final String id;
  final String name;

  factory AttendanceSemester.fromJson(Map<String, dynamic> json) {
    return AttendanceSemester(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }
}

class AttendanceRow {
  const AttendanceRow({
    required this.lectureNo,
    required this.date,
    required this.durationHours,
    required this.presence,
  });

  final String lectureNo;
  final String date;
  final String durationHours;
  final String presence;

  static const double dangerThresholdPercent = 80;

  bool get isPresent => _normalizedPresence == 'P';
  bool get isAbsent => _normalizedPresence == 'A';
  bool get isLate =>
      _normalizedPresence == 'L' ||
      _normalizedPresence == 'LT' ||
      presence.toLowerCase().contains('late');

  String get _normalizedPresence => presence.trim().toUpperCase();

  String get statusLabel {
    if (isPresent) {
      return 'Present';
    }
    if (isLate) {
      return 'Late';
    }
    if (isAbsent) {
      return 'Absent';
    }
    return presence;
  }

  factory AttendanceRow.fromJson(Map<String, dynamic> json) {
    return AttendanceRow(
      lectureNo: (json['lectureNo'] as String?) ?? '',
      date: (json['date'] as String?) ?? '',
      durationHours: (json['durationHours'] as String?) ?? '',
      presence: (json['presence'] as String?) ?? '',
    );
  }
}

class AttendanceCourse {
  const AttendanceCourse({
    required this.paneId,
    required this.courseCode,
    required this.courseTitle,
    required this.heading,
    required this.rows,
  });

  final String paneId;
  final String courseCode;
  final String courseTitle;
  final String heading;
  final List<AttendanceRow> rows;

  int get presentCount => rows.where((row) => row.isPresent).length;
  int get lateCount => rows.where((row) => row.isLate).length;
  int get absentCount => rows.where((row) => row.isAbsent).length;
  int get totalLectures => rows.length;

  int get attendedCount => presentCount + lateCount;

  double get attendancePercentage {
    if (totalLectures == 0) {
      return 0;
    }
    return (attendedCount / totalLectures) * 100;
  }

  bool get isInDanger =>
      totalLectures > 0 &&
      attendancePercentage < AttendanceRow.dangerThresholdPercent;

  String get displayTitle {
    if (courseCode.isEmpty && courseTitle.isEmpty) {
      return paneId;
    }
    if (courseTitle.isEmpty) {
      return courseCode;
    }
    if (courseCode.isEmpty) {
      return courseTitle;
    }
    return courseCode;
  }

  String? get subtitle {
    if (heading.isNotEmpty) {
      return heading;
    }
    if (courseTitle.isNotEmpty && courseTitle != courseCode) {
      return courseTitle;
    }
    return null;
  }

  factory AttendanceCourse.fromJson(Map<String, dynamic> json) {
    final rows = json['attendanceRows'];
    return AttendanceCourse(
      paneId: (json['paneId'] as String?) ?? '',
      courseCode: (json['courseCode'] as String?) ?? '',
      courseTitle: (json['courseTitle'] as String?) ?? '',
      heading: (json['heading'] as String?) ?? '',
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => AttendanceRow.fromJson(row.cast<String, dynamic>()),
                )
                .where((row) => row.lectureNo.isNotEmpty || row.date.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class AttendanceSnapshot {
  const AttendanceSnapshot({
    required this.semester,
    required this.courses,
    required this.capturedAt,
  });

  final AttendanceSemester? semester;
  final List<AttendanceCourse> courses;
  final DateTime? capturedAt;

  int get totalLectures =>
      courses.fold(0, (total, course) => total + course.totalLectures);

  List<AttendanceCourse> get coursesInDanger =>
      courses.where((course) => course.isInDanger).toList(growable: false);

  factory AttendanceSnapshot.fromJson(Map<String, dynamic> json) {
    AttendanceSemester? semester;
    final semesterJson = json['selectedSemester'];
    if (semesterJson is Map<String, dynamic>) {
      final parsed = AttendanceSemester.fromJson(semesterJson);
      if (parsed.id.isNotEmpty && parsed.name.isNotEmpty) {
        semester = parsed;
      }
    }

    final coursesJson = json['courses'];
    final courses = coursesJson is List
        ? coursesJson
              .whereType<Map>()
              .map(
                (course) =>
                    AttendanceCourse.fromJson(course.cast<String, dynamic>()),
              )
              .where(
                (course) =>
                    course.courseCode.isNotEmpty ||
                    course.heading.isNotEmpty ||
                    course.rows.isNotEmpty,
              )
              .toList(growable: false)
        : const <AttendanceCourse>[];

    DateTime? capturedAt;
    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is String) {
      capturedAt = DateTime.tryParse(capturedAtRaw);
    }

    return AttendanceSnapshot(
      semester: semester,
      courses: courses,
      capturedAt: capturedAt,
    );
  }
}
