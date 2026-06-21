import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_models.dart';

class AttendanceStorage {
  static const String attendanceDataKey = 'flex_attendance_data';

  static Future<AttendanceSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedAttendance = preferences.getString(attendanceDataKey);

    if (storedAttendance == null || storedAttendance.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(storedAttendance);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AttendanceSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
