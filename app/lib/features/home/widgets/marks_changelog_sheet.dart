import 'package:flutter/material.dart';
import '../../../../models/marks_changelog.dart';
import '../../../../services/marks_changelog_storage.dart';
import '../../../../services/marks_storage.dart';

class MarksChangelogSheet extends StatefulWidget {
  final List<MarksChangelogEntry> entries;
  final VoidCallback onDismissed;

  const MarksChangelogSheet({
    super.key,
    required this.entries,
    required this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MarksChangelogEntry> entries,
    required VoidCallback onDismissed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MarksChangelogSheet(
        entries: entries,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<MarksChangelogSheet> createState() => _MarksChangelogSheetState();
}

class _MarksChangelogSheetState extends State<MarksChangelogSheet> {
  static const Color _accent = Color(0xFF2563EB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF6B7280);

  Future<void> _clearChangelog() async {
    await MarksChangelogStorage.clear();
    MarksStorage.highlightedCoursesNotifier.value = [];
    if (mounted) {
      Navigator.pop(context);
      widget.onDismissed();
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inkColor = isDark ? Colors.white : _ink;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: _accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Marks Updates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                        Text(
                          '${widget.entries.length} recent changes detected',
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _clearChangelog,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List of changes
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final isUpdated = entry.changeType == 'updated';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isUpdated
                              ? Colors.amber.withOpacity(0.12)
                              : const Color(0xFF10B981).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUpdated ? Icons.edit_note_rounded : Icons.add_chart_rounded,
                          color: isUpdated ? Colors.amber.shade700 : const Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.courseTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: inkColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _formatTime(entry.timestamp),
                                  style: const TextStyle(fontSize: 10, color: _muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.itemNo,
                              style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isUpdated
                                        ? Colors.amber.withOpacity(0.1)
                                        : const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isUpdated
                                        ? '${entry.oldObtained ?? "?"} ➔ ${entry.newObtained} / ${entry.total}'
                                        : '${entry.newObtained} / ${entry.total}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isUpdated ? Colors.amber.shade800 : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDismissed();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Acknowledge & Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
