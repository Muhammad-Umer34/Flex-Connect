void main() {
  final RegExp sectionRegex = RegExp(
    r'\b(BCS|BSE|BAI|BDS|BSD|BCY|BBA|BFT|MCS|MS|PHD|BS)\s*[-–—]?\s*([0-9])\s*([A-Za-z])\b',
    caseSensitive: false,
  );
  final val = 'SE (BCS-6J): Aqsa K';
  final matches = sectionRegex.allMatches(val);
  print('Matches length: ${matches.length}');
  for (final m in matches) {
    print('Match: ${m.group(0)}, Dept: ${m.group(1)}, Sem: ${m.group(2)}, Letter: ${m.group(3)}');
  }
}
