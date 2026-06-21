import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final file = File('../uploaded_timetable.xlsx');
  final bytes = file.readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  
  print('Sheets: ${excel.tables.keys.toList()}');
  
  final sheet = excel.tables.values.first;
  print('Rows count: ${sheet.rows.length}');
  
  final uniqueCells = <String>{};
  
  for (final row in sheet.rows) {
    for (final cell in row) {
      if (cell != null && cell.value != null) {
        final val = cell.value.toString().trim();
        if (val.contains('BCS-6J') || val.contains('BCS-6') || val.contains('BCS 6') || val.contains('6J') || val.contains('Aqsa')) {
          uniqueCells.add(val);
        }
      }
    }
  }
  
  print('Matching cells found:');
  for (final c in uniqueCells) {
    print('  - "$c"');
  }
}
