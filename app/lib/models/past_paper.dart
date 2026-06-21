import 'package:flutter/services.dart' show rootBundle;

class PastPaper {
  final String subject;
  final String category;
  final String fileName;
  final String link;

  PastPaper({
    required this.subject,
    required this.category,
    required this.fileName,
    required this.link,
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
        // Skip adding the quote character itself to the field output
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

  /// Load and parse past papers CSV from the assets folder.
  static Future<List<PastPaper>> loadFromAssets() async {
    try {
      final csvData = await rootBundle.loadString('assets/drive_structured_map.csv');
      final lines = csvData.split('\n');
      final papers = <PastPaper>[];

      // Skip header row 's,c,n,l'
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final fields = parseCsvRow(line);
        if (fields.length >= 4) {
          papers.add(PastPaper(
            subject: fields[0],
            category: fields[1],
            fileName: fields[2],
            link: fields[3],
          ));
        }
      }

      return papers;
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }
}
