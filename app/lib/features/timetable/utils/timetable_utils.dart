import 'package:flutter/material.dart';

Color getDeptColor(String dept) {
  switch (dept.toUpperCase()) {
    case 'CS':
      return Colors.indigo;
    case 'SE':
      return Colors.teal;
    case 'AI':
      return Colors.deepPurple;
    case 'DS':
      return Colors.blue;
    case 'CY':
      return Colors.redAccent;
    case 'BA':
      return Colors.orange;
    case 'FT':
      return Colors.green;
    default:
      return Colors.blueGrey;
  }
}

String getDeptFullName(String dept) {
  switch (dept.toUpperCase()) {
    case 'CS':
      return 'Computer Science';
    case 'SE':
      return 'Software Engineering';
    case 'AI':
      return 'Artificial Intelligence';
    case 'DS':
      return 'Data Science';
    case 'CY':
      return 'Cyber Security';
    case 'BA':
      return 'Business Administration';
    case 'FT':
      return 'FinTech';
    default:
      return 'Department of $dept';
  }
}
