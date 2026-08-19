import 'package:flutter/material.dart';
import '../../../models/transcript_models.dart';

class GpaSnapshotCard extends StatelessWidget {
  const GpaSnapshotCard({
    super.key,
    required this.transcriptSnapshot,
  });

  final TranscriptSnapshot? transcriptSnapshot;

  static const Color _accent = Color(0xFF2563EB);

  bool get _hasTranscriptData =>
      transcriptSnapshot != null && transcriptSnapshot!.semesters.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final Color containerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (!_hasTranscriptData) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: containerBorder, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.leaderboard_outlined, color: muted, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sync transcript to unlock GPA snapshot.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final latestSem = transcriptSnapshot!.semesters.last;
    final totalSemesters = transcriptSnapshot!.semesters.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: containerBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPA SNAPSHOT',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestSem.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Semesters: $totalSemesters',
                  style: TextStyle(
                    fontSize: 11,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 42,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CGPA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestSem.cgpa ?? '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 42,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SGPA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latestSem.sgpa ?? '—',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
