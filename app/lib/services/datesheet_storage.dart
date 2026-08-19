import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'datesheet_parser.dart';

class DatesheetStorage {
  DatesheetStorage._();

  static const String datesheetDataKey = 'flex_datesheet_data';

  static Future<void> save(List<DatesheetEvent> events) async {
    final preferences = await SharedPreferences.getInstance();
    final jsonList = events.map((e) => e.toJson()).toList();
    await preferences.setString(datesheetDataKey, jsonEncode(jsonList));
  }

  static Future<List<DatesheetEvent>?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedData = preferences.getString(datesheetDataKey);

    if (storedData == null || storedData.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(storedData);
      if (decoded is List) {
        return decoded
            .map((e) => DatesheetEvent.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(datesheetDataKey);
  }
}
