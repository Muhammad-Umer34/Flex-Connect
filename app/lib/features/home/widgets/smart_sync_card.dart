import 'package:flutter/material.dart';

class SmartSyncCard extends StatelessWidget {
  const SmartSyncCard({
    super.key,
    required this.isLoading,
    required this.onSyncPressed,
    required this.selectedSemesterCode,
    required this.cachedSemesterOptions,
    required this.onSemesterChanged,
    required this.hasAnyData,
    required this.latestSyncTime,
  });

  final bool isLoading;
  final VoidCallback onSyncPressed;
  final String? selectedSemesterCode;
  final List<Map<String, String>> cachedSemesterOptions;
  final ValueChanged<String> onSemesterChanged;
  final bool hasAnyData;
  final DateTime? latestSyncTime;

  static const Color _accent = Color(0xFF2563EB);

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'Not Sync\'d';
    final localTime = dateTime.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[localTime.month - 1];
    final day = localTime.day;
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$month $day, $hour:$minute';
  }

  Widget _buildSyncStatusRow(String label, bool isCaptured, DateTime? timestamp, Color ink, Color muted) {
    final statusColor = isCaptured ? const Color(0xFF10B981) : muted;
    final icon = isCaptured ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: ink,
            ),
          ),
          const Spacer(),
          Text(
            isCaptured ? _formatTimestamp(timestamp) : 'Not Sync\'d',
            style: TextStyle(
              fontSize: 12,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final Color containerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color containerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: containerBorder, width: 1),
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
                  color: isDark ? _accent.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.sync,
                  color: _accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SMART SYNC',
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: isLoading ? null : onSyncPressed,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: const [
                      Icon(Icons.sync, size: 14, color: _accent),
                      SizedBox(width: 4),
                      Text(
                        'Sync Now',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: muted),
              const SizedBox(width: 8),
              Text(
                'Active Semester:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: containerBorder, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSemesterCode,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: muted),
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: cachedSemesterOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['code'],
                          child: Text(opt['name']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          onSemesterChanged(val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: containerBorder, height: 1),
          const SizedBox(height: 12),
          _buildSyncStatusRow('Last Synced', hasAnyData, latestSyncTime, ink, muted),
        ],
      ),
    );
  }
}
