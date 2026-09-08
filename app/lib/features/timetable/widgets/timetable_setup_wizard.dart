import 'package:flutter/material.dart';
import '../utils/section_input_formatter.dart';

class TimetableSetupWizard extends StatelessWidget {
  const TimetableSetupWizard({
    super.key,
    required this.sectionInputController,
    required this.onPickFile,
    required this.selectedBytes,
    required this.selectedFileName,
    required this.errorMessage,
    required this.onGenerateTimetable,
  });

  final TextEditingController sectionInputController;
  final VoidCallback onPickFile;
  final dynamic selectedBytes;
  final String? selectedFileName;
  final String? errorMessage;
  final VoidCallback? onGenerateTimetable;

  static const Color _accent = Color(0xFF2563EB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final fieldFill = isDark ? const Color(0xFF0F172A) : Colors.white;
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textInk = isDark ? Colors.white : _ink;
    final textMuted = isDark ? const Color(0xFF94A3B8) : _muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.group_outlined, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Class Section Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textInk),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'ENTER YOUR SECTION (E.G. BCS-6B)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sectionInputController,
                style: TextStyle(color: textInk, fontWeight: FontWeight.w500),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  const SectionInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g. BCS-6B',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : _muted, fontWeight: FontWeight.normal),
                  prefixIcon: Icon(Icons.class_outlined, color: isDark ? const Color(0xFF64748B) : _muted),
                  fillColor: fieldFill,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'UPLOAD EXCEL SHEET',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: selectedBytes != null
                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                  : cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedBytes != null
                    ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE))
                    : fieldBorder,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedBytes != null
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE))
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selectedBytes != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: selectedBytes != null ? _accent : textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedBytes != null ? 'Excel Selected' : 'Choose Spreadsheet File',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedFileName ?? 'Supported formats: .xlsx, .xls',
                  style: TextStyle(color: textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            onPressed: selectedBytes != null ? onGenerateTimetable : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Generate Timetable',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
