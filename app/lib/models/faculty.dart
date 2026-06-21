import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Faculty {
  final String id;
  final String name;
  final String designation;
  final bool hecApproved;
  final String email;
  final String extension;
  final String department;
  final String deptCode;
  final String profileUrl;
  final String imgUrl;
  final String campus;
  final String linkedin;

  Faculty({
    required this.id,
    required this.name,
    required this.designation,
    required this.hecApproved,
    required this.email,
    required this.extension,
    required this.department,
    required this.deptCode,
    required this.profileUrl,
    required this.imgUrl,
    required this.campus,
    required this.linkedin,
  });

  /// Custom CSV row parser that handles fields with double quotes containing commas.
  static List<String> parseCsvRow(String row) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  /// Load and parse faculty CSV from the assets folder.
  static Future<List<Faculty>> loadFromAssets() async {
    try {
      final csvData = await rootBundle.loadString('assets/cleaned_output.csv');
      // Split by newline, supporting carriage returns as well
      final lines = csvData.split('\n');
      final facultyList = <Faculty>[];

      // Skip header row: ID,Name,Designation,HEC Approved Supervisor,Email,Extension,Department,Dept Code,Profile URL,Img URL,Campus,LinkedIn
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final fields = parseCsvRow(line);
        if (fields.length >= 11) {
          final id = fields[0];
          final name = fields[1];
          final designation = fields[2];
          final hecApproved = fields[3].trim().toLowerCase() == 'yes';
          final email = fields[4];
          final extension = fields[5];
          final department = fields[6];
          final deptCode = fields[7];
          final profileUrl = fields[8];
          final imgUrl = fields[9];
          final campus = fields[10];
          final linkedin = fields.length > 11 ? fields[11] : '';

          facultyList.add(Faculty(
            id: id,
            name: name,
            designation: designation,
            hecApproved: hecApproved,
            email: email,
            extension: extension,
            department: department,
            deptCode: deptCode,
            profileUrl: profileUrl,
            imgUrl: imgUrl,
            campus: campus,
            linkedin: linkedin,
          ));
        }
      }

      return facultyList;
    } catch (e) {
      return [];
    }
  }

  /// Load campus to department mappings from JSON assets
  static Future<Map<String, List<String>>> loadCampusesAndDepartments() async {
    try {
      final jsonString = await rootBundle.loadString('assets/campus_departments.json');
      final Map<String, dynamic> decoded = json.decode(jsonString);
      return decoded.map((key, value) {
        final List<String> depts = (value as List).map((e) => e.toString()).toList();
        return MapEntry(key, depts);
      });
    } catch (e) {
      return {};
    }
  }
}
