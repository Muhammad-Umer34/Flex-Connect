import 'attendance_models.dart';

class CourseBunkStatus {
  final AttendanceCourse course;
  final int attended;
  final int total;
  final double percentage;
  final bool isBelow80;
  final int maxMissable;
  final int minConsecutiveToAttend;

  CourseBunkStatus({
    required this.course,
    required this.attended,
    required this.total,
    required this.percentage,
    required this.isBelow80,
    required this.maxMissable,
    required this.minConsecutiveToAttend,
  });

  factory CourseBunkStatus.calculate(AttendanceCourse course) {
    final attended = course.attendedCount;
    final total = course.totalLectures;
    final double pct = total > 0 ? (attended / total) * 100 : 0.0;
    final isBelow = pct < 80.0;

    int maxMiss = 0;
    int minAttend = 0;

    if (total > 0) {
      if (!isBelow) {
        maxMiss = ((attended / 0.80) - total).floor();
        if (maxMiss < 0) maxMiss = 0;
      } else {
        minAttend = 4 * total - 5 * attended;
        if (minAttend < 0) minAttend = 0;
      }
    }

    return CourseBunkStatus(
      course: course,
      attended: attended,
      total: total,
      percentage: pct,
      isBelow80: isBelow,
      maxMissable: maxMiss,
      minConsecutiveToAttend: minAttend,
    );
  }
}
