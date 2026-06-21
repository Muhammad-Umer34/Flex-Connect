import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  // Use http://10.0.2.2:5000 for Android emulator, http://localhost:5000 for others
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    // For Android platform, 10.0.2.2 refers to host localhost
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  static Future<Map<String, dynamic>> submitFeedback({
    required String name,
    required String rollNumber,
    required String email,
    required String category,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'rollNumber': rollNumber,
          'email': email,
          'category': category,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'emailSent': data['emailSent'] ?? true,
          'message': data['message'] ?? 'Feedback submitted successfully!',
        };
      } else {
        Map<String, dynamic>? data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {}
        
        final errorMsg = data != null ? data['message'] : 'Failed with status ${response.statusCode}';
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not connect to feedback server: $e',
      };
    }
  }
}
