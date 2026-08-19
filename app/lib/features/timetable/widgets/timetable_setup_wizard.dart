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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                    ),
                    child: const Icon(Icons.group_outlined, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Class Section Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'ENTER YOUR SECTION (E.G. BCS-6B)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sectionInputController,
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w500),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  const SectionInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g. BCS-6B',
                  hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(Icons.class_outlined, color: _muted),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
        const Text(
          'UPLOAD EXCEL SHEET',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _muted,
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
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedBytes != null
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFFE2E8F0),
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
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selectedBytes != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: selectedBytes != null ? _accent : _muted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedBytes != null ? 'Excel Selected' : 'Choose Spreadsheet File',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedFileName ?? 'Supported formats: .xlsx, .xls',
                  style: const TextStyle(color: _muted, fontSize: 12),
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
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
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
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: const Color(0xFF94A3B8),
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
