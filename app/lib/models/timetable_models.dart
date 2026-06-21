class TimetableDayEvent {
  final String day;
  final String time;
  final String room;
  final String section;
  final String originalSection;
  final String course;
  final String teacher;
  final String degree;

  const TimetableDayEvent({
    required this.day,
    required this.time,
    required this.room,
    required this.section,
    required this.originalSection,
    required this.course,
    required this.teacher,
    required this.degree,
  });

  factory TimetableDayEvent.fromJson(Map<String, dynamic> json) {
    return TimetableDayEvent(
      day: (json['day'] as String?) ?? '',
      time: (json['time'] as String?) ?? '',
      room: (json['room'] as String?) ?? '',
      section: (json['section'] as String?) ?? '',
      originalSection: (json['originalSection'] as String?) ?? '',
      course: (json['course'] as String?) ?? '',
      teacher: (json['teacher'] as String?) ?? '',
      degree: (json['degree'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'time': time,
      'room': room,
      'section': section,
      'originalSection': originalSection,
      'course': course,
      'teacher': teacher,
      'degree': degree,
    };
  }
}

class TimetableSnapshot {
  final String campus;
  final String degree;
  final List<String> departments;
  final Map<String, List<String>> sections;
  final List<TimetableDayEvent> schedule;
  final DateTime capturedAt;

  const TimetableSnapshot({
    required this.campus,
    required this.degree,
    required this.departments,
    required this.sections,
    required this.schedule,
    required this.capturedAt,
  });

  factory TimetableSnapshot.fromJson(Map<String, dynamic> json) {
    final deptsRaw = json['departments'] as List?;
    final departments = deptsRaw?.map((e) => e.toString()).toList() ?? const [];

    final sectionsRaw = json['sections'] as Map?;
    final Map<String, List<String>> sections = {};
    if (sectionsRaw != null) {
      sectionsRaw.forEach((key, value) {
        if (value is List) {
          sections[key.toString()] = value.map((e) => e.toString()).toList();
        }
      });
    }

    final scheduleRaw = json['schedule'] as List?;
    final schedule = scheduleRaw
        ?.whereType<Map>()
        .map((e) => TimetableDayEvent.fromJson(e.cast<String, dynamic>()))
        .toList() ?? const [];

    DateTime capturedAt = DateTime.now();
    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is String) {
      capturedAt = DateTime.tryParse(capturedAtRaw) ?? DateTime.now();
    }

    return TimetableSnapshot(
      campus: (json['campus'] as String?) ?? 'Islamabad',
      degree: (json['degree'] as String?) ?? 'bachelors',
      departments: departments,
      sections: sections,
      schedule: schedule,
      capturedAt: capturedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campus': campus,
      'degree': degree,
      'departments': departments,
      'sections': sections,
      'schedule': schedule.map((e) => e.toJson()).toList(),
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}
