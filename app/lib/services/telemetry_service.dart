import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'update_service.dart';

class TelemetryService {
  TelemetryService._();

  /// Logs or updates the telemetry record for the current logged-in user.
  /// If the user is not logged in yet, this method completes silently with no action.
  static Future<void> recordLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rollNumber = prefs.getString('student_roll_number');

      if (rollNumber == null || rollNumber.trim().isEmpty) {
        // User not logged in yet, skip telemetry update
        return;
      }

      final cleanRoll = rollNumber.trim().toUpperCase();
      final appVersion = UpdateService.currentVersion;

      // Upsert the record in user_telemetry table
      await Supabase.instance.client.from('user_telemetry').upsert({
        'roll_number': cleanRoll,
        'app_version': appVersion,
        'last_active': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Fail silently to prevent crashing app startup or login flow due to network/database issues
      print('Telemetry log failed: $e');
    }
  }
}
