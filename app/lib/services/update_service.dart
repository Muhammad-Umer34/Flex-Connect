import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  UpdateService._();

  static bool _hasCheckedForUpdates = false;

  static Future<void> checkForUpdates(BuildContext context) async {
    if (_hasCheckedForUpdates) return;
    _hasCheckedForUpdates = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version.trim();

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/Muhammad-Umer34/Flex-Connect-App/releases/latest'),
        headers: {'User-Agent': 'Flex-Connect-App-Update-Checker'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        String latestVersion = data['tag_name'] ?? '1.0.0';
        if (latestVersion.startsWith('v')) {
          latestVersion = latestVersion.substring(1);
        }

        final updateAvailable = _isVersionNewer(installedVersion, latestVersion);

        if (updateAvailable) {
          final releaseNotes = data['body'] ?? '';
          final isCritical = releaseNotes.toUpperCase().contains('[CRITICAL]');
          
          String downloadUrl = '';
          final assets = data['assets'] as List?;
          if (assets != null && assets.isNotEmpty) {
            for (var asset in assets) {
              final name = asset['name'] as String?;
              if (name != null && name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] ?? '';
                break;
              }
            }
            if (downloadUrl.isEmpty) {
              downloadUrl = assets.first['browser_download_url'] ?? '';
            }
          }
          if (downloadUrl.isEmpty) {
            downloadUrl = data['html_url'] ?? 'https://github.com/Muhammad-Umer34/Flex-Connect-App/releases';
          }

          if (context.mounted) {
            _showUpdateDialog(
              context,
              installedVersion: installedVersion,
              latestVersion: latestVersion,
              downloadUrl: downloadUrl,
              releaseNotes: releaseNotes,
              isCritical: isCritical,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('GitHub-based in-app upgrade check failed: $e');
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      final cParts = current.split('.').map((x) => int.parse(x)).toList();
      final lParts = latest.split('.').map((x) => int.parse(x)).toList();
      final length = cParts.length > lParts.length ? cParts.length : lParts.length;

      for (int i = 0; i < length; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (l > c) return true;
        if (c > l) return false;
      }
    } catch (_) {
      return current != latest;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String installedVersion,
    required String latestVersion,
    required String downloadUrl,
    required String releaseNotes,
    required bool isCritical,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: !isCritical,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isCritical,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Update Available!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A new version ($latestVersion) of Flex Connect is available. You are currently on v$installedVersion.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'WHAT\'S NEW',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        _cleanMarkdownFormatting(releaseNotes),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              if (!isCritical)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Later',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (downloadUrl.isNotEmpty) {
                    final uri = Uri.parse(downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                  if (!isCritical && context.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text(
                  'Update Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _cleanMarkdownFormatting(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'\1')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
        .trim();
  }
}
