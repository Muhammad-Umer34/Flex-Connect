import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timetable_models.dart';

class TimetableStorage {
  static const String timetableDataKey = 'flex_timetable_data';
  static const String selectedSectionKey = 'flex_timetable_selected_section';
  static const String selectedDeptKey = 'flex_timetable_selected_dept';
  static const String customEventsKey = 'flex_timetable_custom_events';

  static Future<void> save(TimetableSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(timetableDataKey, jsonEncode(snapshot.toJson()));
  }

  static Future<TimetableSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedData = preferences.getString(timetableDataKey);

    if (storedData == null || storedData.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(storedData);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return TimetableSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSelectedSection(String section) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(selectedSectionKey, section);
  }

  static Future<String?> loadSelectedSection() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(selectedSectionKey);
  }

  static Future<void> saveSelectedDept(String dept) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(selectedDeptKey, dept);
  }

  static Future<String?> loadSelectedDept() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(selectedDeptKey);
  }

  static Future<void> saveCustomEvents(List<TimetableDayEvent> events) async {
    final preferences = await SharedPreferences.getInstance();
    final jsonList = events.map((e) => e.toJson()).toList();
    await preferences.setString(customEventsKey, jsonEncode(jsonList));
  }

  static Future<List<TimetableDayEvent>> loadCustomEvents() async {
    final preferences = await SharedPreferences.getInstance();
    final storedData = preferences.getString(customEventsKey);
    if (storedData == null || storedData.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(storedData);
      if (decoded is List) {
        return decoded
            .map((e) => TimetableDayEvent.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(timetableDataKey);
    await preferences.remove(selectedSectionKey);
    await preferences.remove(selectedDeptKey);
    await preferences.remove(customEventsKey);
  }
}
