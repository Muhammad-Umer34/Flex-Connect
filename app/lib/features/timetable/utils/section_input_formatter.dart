import 'package:flutter/services.dart';

class SectionInputFormatter extends TextInputFormatter {
  const SectionInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Force uppercase
    String text = newValue.text.toUpperCase();
    int selectionIndex = newValue.selection.end;

    // If deleting text, retain deletion normally
    if (newValue.text.length < oldValue.text.length) {
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: selectionIndex),
      );
    }

    // Auto-format rule 1: If user types 3 letter degree prefix (e.g. "BCS", "BSE", "BAI"), auto insert "-"
    if (text.length == 3 && !text.contains('-')) {
      if (RegExp(r'^[A-Z]{3}$').hasMatch(text)) {
        text = '$text-';
        selectionIndex = text.length;
      }
    }
    // Auto-format rule 2: If typed/pasted without hyphen (e.g., "BCS7C" or "BSE6B")
    else if (text.length > 3 && !text.contains('-')) {
      final reg = RegExp(r'^([A-Z]{2,4})([0-9].*)$');
      final match = reg.firstMatch(text);
      if (match != null) {
        text = '${match.group(1)}-${match.group(2)}';
        selectionIndex = text.length;
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
