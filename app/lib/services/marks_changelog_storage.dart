import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/marks_changelog.dart';

class MarksChangelogStorage {
  static const String changelogKey = 'flex_marks_changelog';

  static Future<List<MarksChangelogEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(changelogKey);
    if (data == null) return [];
    try {
      final List<MarksChangelogEntry> list = [];
      for (final item in data) {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          list.add(MarksChangelogEntry.fromJson(decoded));
        }
      }
      // Sort descending by timestamp (latest first)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> appendEntries(List<MarksChangelogEntry> entries) async {
    if (entries.isEmpty) return;
    
    final current = await load();
    // Avoid double inserts by verifying IDs if needed, but appendEntries is caller's new list
    final merged = [...entries, ...current];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      changelogKey,
      merged.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(changelogKey);
  }
}
