
class GradingUtils {
  // The NUCES Official Relative Grading Scheme Table (effective Spring 2020)
  // Maps Rounded MCA (30 to 91) to thresholds for:
  // [F_max, D_min, D+_min, C-_min, C_min, C+_min, B-_min, B_min, B+_min, A-_min, A_min, A+_min]
  static const Map<int, List<int?>> relativeGradingTable = {
    30: [29, null, null, null, null, 30, 33, 38, 43, 48, 65, 70],
    31: [29, null, null, null, null, 30, 34, 39, 44, 49, 65, 70],
    32: [29, null, null, null, null, 30, 35, 40, 45, 50, 65, 70],
    33: [29, null, null, null, 30, 31, 36, 41, 46, 51, 65, 70],
    34: [29, null, null, null, 30, 32, 37, 42, 47, 52, 65, 70],
    35: [29, null, null, null, 30, 33, 38, 43, 48, 53, 65, 70],
    36: [29, null, null, null, 30, 34, 39, 44, 49, 54, 65, 70],
    37: [29, null, null, null, 30, 35, 40, 45, 50, 55, 65, 70],
    38: [29, null, null, 30, 31, 36, 41, 46, 51, 56, 65, 70],
    39: [29, null, null, 30, 32, 37, 42, 47, 52, 57, 65, 70],
    40: [29, null, null, 30, 33, 38, 43, 48, 53, 58, 65, 70],
    41: [29, null, null, 30, 34, 39, 44, 49, 54, 59, 65, 70],
    42: [29, null, null, 30, 35, 40, 45, 50, 55, 60, 65, 70],
    43: [29, null, 30, 31, 36, 41, 46, 51, 56, 61, 66, 71],
    44: [29, null, 30, 32, 37, 42, 47, 52, 57, 62, 67, 72],
    45: [29, null, 30, 33, 38, 43, 48, 53, 58, 63, 68, 73],
    46: [29, null, 30, 34, 39, 44, 49, 54, 59, 64, 69, 74],
    47: [29, null, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
    48: [29, 30, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76],
    49: [29, 30, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77],
    50: [29, null, 30, 33, 38, 43, 48, 53, 58, 63, 68, 73],
    51: [29, null, 30, 34, 39, 44, 49, 54, 59, 64, 69, 74],
    52: [29, null, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
    53: [29, 30, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76],
    54: [29, 30, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77],
    55: [29, 30, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78],
    56: [29, 30, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79],
    57: [29, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80],
    58: [30, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81],
    59: [31, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82],
    60: [32, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83],
    61: [33, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84],
    62: [34, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85],
    63: [35, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86],
    64: [36, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87],
    65: [32, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83],
    66: [33, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84],
    67: [34, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85],
    68: [35, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86],
    69: [36, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87],
    70: [37, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83, 88],
    71: [38, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84, 89],
    72: [39, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90],
    73: [40, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86, 91],
    74: [41, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87, 92],
    75: [42, 43, 48, 53, 58, 63, 68, 73, 78, 83, 88, 93],
    76: [43, 44, 49, 54, 59, 64, 69, 74, 79, 84, 89, 94],
    77: [44, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95],
    78: [45, 46, 51, 56, 61, 66, 71, 76, 81, 86, 90, 95],
    79: [46, 47, 52, 57, 62, 67, 72, 77, 82, 87, 90, 95],
    80: [47, 48, 53, 58, 63, 68, 73, 78, 83, 88, 90, 95],
    81: [48, 49, 54, 59, 64, 69, 74, 79, 84, 89, 90, 95],
    82: [49, 50, 55, 60, 65, 70, 75, 80, 85, null, 90, 95],
    83: [49, 50, 56, 61, 66, 71, 76, 81, 86, null, 90, 95],
    84: [49, 50, 57, 62, 67, 72, 77, 82, 87, null, 90, 95],
    85: [49, 50, 58, 63, 68, 73, 78, 83, 88, null, 90, 95],
    86: [49, 50, 59, 64, 69, 74, 79, 84, 89, null, 90, 95],
    87: [49, 50, 60, 65, 70, 75, 80, 85, null, null, 90, 95],
    88: [49, 50, 61, 66, 71, 76, 81, 86, null, null, 90, 95],
    89: [49, 50, 62, 67, 72, 77, 82, 87, null, null, 90, 95],
    90: [49, 50, 63, 68, 73, 78, 83, 88, null, null, 90, 95],
    91: [49, 50, 64, 69, 74, 79, 84, 89, null, null, 90, 95],
  };

  static String calculateAbsoluteGrade(double score) {
    final rounded = score.round();
    if (rounded >= 90) return 'A+';
    if (rounded >= 86) return 'A';
    if (rounded >= 82) return 'A-';
    if (rounded >= 78) return 'B+';
    if (rounded >= 74) return 'B';
    if (rounded >= 70) return 'B-';
    if (rounded >= 66) return 'C+';
    if (rounded >= 62) return 'C';
    if (rounded >= 58) return 'C-';
    if (rounded >= 54) return 'D+';
    if (rounded >= 50) return 'D';
    return 'F';
  }

  static String calculateRelativeGrade(double score, int mca) {
    final mcaClamped = mca.clamp(30, 91);
    final row = relativeGradingTable[mcaClamped];
    if (row == null) return 'F';

    final scoreRounded = score.round();
    final List<String> gradesList = ['F', 'D', 'D+', 'C-', 'C', 'C+', 'B-', 'B', 'B+', 'A-', 'A', 'A+'];
    
    // Check starting from A+ down to D
    for (int i = 11; i >= 1; i--) {
      final val = row[i];
      if (val != null && scoreRounded >= val) {
        return gradesList[i];
      }
    }
    return 'F';
  }

  static double getMinThreshold(String grade, bool isAbsolute, int mca) {
    if (isAbsolute) {
      switch (grade) {
        case 'A+': return 90.0;
        case 'A': return 86.0;
        case 'A-': return 82.0;
        case 'B+': return 78.0;
        case 'B': return 74.0;
        case 'B-': return 70.0;
        case 'C+': return 66.0;
        case 'C': return 62.0;
        case 'C-': return 58.0;
        case 'D+': return 54.0;
        case 'D': return 50.0;
        default: return 0.0;
      }
    } else {
      final mcaClamped = mca.clamp(30, 91);
      final row = relativeGradingTable[mcaClamped];
      if (row == null) return 0.0;

      final List<String> gradesList = ['F', 'D', 'D+', 'C-', 'C', 'C+', 'B-', 'B', 'B+', 'A-', 'A', 'A+'];
      final idx = gradesList.indexOf(grade);
      if (idx == -1) return 0.0;

      final val = row[idx];
      if (val == null) {
        // If grade is null, it means it's not possible for this MCA.
        // We find the nearest higher valid grade.
        for (int i = idx + 1; i < gradesList.length; i++) {
          final nextVal = row[i];
          if (nextVal != null) {
            return nextVal.toDouble();
          }
        }
        return 100.0; // default unattainable
      }
      return val.toDouble();
    }
  }
}
