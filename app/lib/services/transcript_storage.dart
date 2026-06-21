import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transcript_models.dart';

class TranscriptStorage {
  static const String transcriptDataKey = 'flex_transcript_data';

  static Future<TranscriptSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedTranscript = preferences.getString(transcriptDataKey);

    if (storedTranscript == null || storedTranscript.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(storedTranscript);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return TranscriptSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
