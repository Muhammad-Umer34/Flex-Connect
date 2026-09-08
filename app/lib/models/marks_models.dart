class MarksSemester {
  const MarksSemester({required this.id, required this.name});

  final String id;
  final String name;

  factory MarksSemester.fromJson(Map<String, dynamic> json) {
    return MarksSemester(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }
}

class MarksRow {
  const MarksRow({
    required this.itemNo,
    required this.weightage,
    required this.obtained,
    required this.total,
    required this.average,
    required this.stdDev,
    required this.minimum,
    required this.maximum,
  });

  final String itemNo;
  final String weightage;
  final String obtained;
  final String total;
  final String average;
  final String stdDev;
  final String minimum;
  final String maximum;

  factory MarksRow.fromJson(Map<String, dynamic> json) {
    return MarksRow(
      itemNo: (json['itemNo'] as String?) ?? '',
      weightage: (json['weightage'] as String?) ?? '',
      obtained: (json['obtained'] as String?) ?? '',
      total: (json['total'] as String?) ?? '',
      average: (json['average'] as String?) ?? '',
      stdDev: (json['stdDev'] as String?) ?? '',
      minimum: (json['minimum'] as String?) ?? '',
      maximum: (json['maximum'] as String?) ?? '',
    );
  }
}

class MarksSection {
  const MarksSection({
    required this.sectionName,
    required this.itemLabel,
    required this.rows,
  });

  final String sectionName;
  final String itemLabel;
  final List<MarksRow> rows;

  List<MarksRow> get activeItemRows {
    final List<MarksRow> items = [];
    MarksRow? grandTotalRow;
    for (final row in rows) {
      final isTotalRow = row.itemNo.trim().isEmpty || row.itemNo.toLowerCase().contains('total');
      if (isTotalRow) {
        grandTotalRow = row;
      } else {
        items.add(row);
      }
    }

    if (items.isEmpty) return const [];

    double totalItemWeight = 0.0;
    double? positiveItemWeight;
    int positiveWeightItemCount = 0;
    for (final item in items) {
      final w = double.tryParse(item.weightage.trim());
      if (w != null && w > 0) {
        totalItemWeight += w;
        positiveItemWeight ??= w;
        positiveWeightItemCount++;
      }
    }

    double? categoryWeight;
    if (grandTotalRow != null) {
      final w = double.tryParse(grandTotalRow.weightage.replaceAll('%', '').trim());
      final t = double.tryParse(grandTotalRow.total.replaceAll('%', '').trim());
      categoryWeight = (w != null && w > 0) ? w : ((t != null && t > 0) ? t : null);
    }

    if (categoryWeight != null &&
        categoryWeight > 0 &&
        totalItemWeight > categoryWeight &&
        positiveItemWeight != null &&
        positiveItemWeight > 0 &&
        positiveWeightItemCount > 0) {
      final double excessWeight = totalItemWeight - categoryWeight;
      final int dropCount = (excessWeight / positiveItemWeight).round();
      final int bestOfCount = positiveWeightItemCount - dropCount;

      if (bestOfCount > 0 && bestOfCount < positiveWeightItemCount) {
        final positiveItems = items.where((item) {
          final w = double.tryParse(item.weightage.trim());
          return w != null && w > 0;
        }).toList();

        final otherItems = items.where((item) {
          final w = double.tryParse(item.weightage.trim());
          return w == null || w <= 0;
        }).toList();

        positiveItems.sort((a, b) {
          final aObt = double.tryParse(a.obtained.trim()) ?? 0.0;
          final aTot = double.tryParse(a.total.trim()) ?? 1.0;
          final aPct = aTot > 0 ? aObt / aTot : 0.0;

          final bObt = double.tryParse(b.obtained.trim()) ?? 0.0;
          final bTot = double.tryParse(b.total.trim()) ?? 1.0;
          final bPct = bTot > 0 ? bObt / bTot : 0.0;

          return bPct.compareTo(aPct); // Descending order
        });

        return [...positiveItems.take(bestOfCount), ...otherItems];
      }
    }

    return items;
  }

  bool isRowDropped(MarksRow row) {
    final isTotalRow = row.itemNo.trim().isEmpty || row.itemNo.toLowerCase().contains('total');
    if (isTotalRow) return false;

    final allItems = rows.where((r) {
      final isTot = r.itemNo.trim().isEmpty || r.itemNo.toLowerCase().contains('total');
      return !isTot;
    }).toList();

    final active = activeItemRows;
    if (active.length < allItems.length) {
      return !active.any((r) => r.itemNo == row.itemNo);
    }

    return false;
  }

  factory MarksSection.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return MarksSection(
      sectionName: (json['sectionName'] as String?) ?? '',
      itemLabel: (json['itemLabel'] as String?) ?? 'Item',
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map((row) => MarksRow.fromJson(row.cast<String, dynamic>()))
                .where(
                  (row) => row.itemNo.isNotEmpty || row.obtained.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class MarksCourse {
  const MarksCourse({
    required this.paneId,
    required this.courseCode,
    required this.courseTitle,
    required this.heading,
    required this.sections,
  });

  final String paneId;
  final String courseCode;
  final String courseTitle;
  final String heading;
  final List<MarksSection> sections;

  int get totalItems =>
      sections.fold(0, (total, section) => total + section.rows.length);

  Map<String, double> get weightedScore {
    double obtainedSum = 0.0;
    double averageSum = 0.0;
    double totalWeight = 0.0;

    for (final section in sections) {
      final activeRows = section.activeItemRows;
      for (final row in activeRows) {
        final double? total = double.tryParse(row.total.trim());
        final double? weight = double.tryParse(row.weightage.trim());
        if (total != null && total > 0 && weight != null && weight > 0) {
          final double? obtained = double.tryParse(row.obtained.trim());
          final double? average = double.tryParse(row.average.trim());

          if (obtained != null) {
            obtainedSum += (obtained / total) * weight;
          }
          if (average != null) {
            averageSum += (average / total) * weight;
          }
          if (obtained != null || average != null) {
            totalWeight += weight;
          }
        }
      }
    }
    return {
      'obtained': obtainedSum,
      'average': averageSum,
      'totalWeight': totalWeight,
    };
  }

  String get displayTitle {
    if (courseCode.isNotEmpty) {
      return courseCode;
    }
    if (heading.isNotEmpty) {
      return heading;
    }
    return paneId;
  }

  String? get subtitle {
    if (heading.isNotEmpty && !heading.startsWith(courseCode)) {
      return heading;
    }
    if (courseTitle.isNotEmpty && courseTitle != courseCode) {
      return courseTitle;
    }
    return null;
  }

  factory MarksCourse.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'];
    return MarksCourse(
      paneId: (json['paneId'] as String?) ?? '',
      courseCode: (json['courseCode'] as String?) ?? '',
      courseTitle: (json['courseTitle'] as String?) ?? '',
      heading: (json['heading'] as String?) ?? '',
      sections: sections is List
          ? sections
                .whereType<Map>()
                .map(
                  (section) =>
                      MarksSection.fromJson(section.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class MarksSnapshot {
  const MarksSnapshot({
    required this.semester,
    required this.courses,
    required this.capturedAt,
  });

  final MarksSemester? semester;
  final List<MarksCourse> courses;
  final DateTime? capturedAt;

  factory MarksSnapshot.fromJson(Map<String, dynamic> json) {
    MarksSemester? semester;
    final semesterJson = json['selectedSemester'];
    if (semesterJson is Map<String, dynamic>) {
      final parsed = MarksSemester.fromJson(semesterJson);
      if (parsed.id.isNotEmpty && parsed.name.isNotEmpty) {
        semester = parsed;
      }
    }

    final coursesJson = json['courses'];
    final courses = coursesJson is List
        ? coursesJson
              .whereType<Map>()
              .map(
                (course) =>
                    MarksCourse.fromJson(course.cast<String, dynamic>()),
              )
              .where(
                (course) =>
                    course.courseCode.isNotEmpty ||
                    course.heading.isNotEmpty ||
                    course.sections.isNotEmpty,
              )
              .toList(growable: false)
        : const <MarksCourse>[];

    DateTime? capturedAt;
    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is String) {
      capturedAt = DateTime.tryParse(capturedAtRaw);
    }

    return MarksSnapshot(
      semester: semester,
      courses: courses,
      capturedAt: capturedAt,
    );
  }
}
