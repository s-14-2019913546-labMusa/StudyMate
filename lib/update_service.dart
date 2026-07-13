import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'language_manager.dart';

class UpdateService {
  static const String currentAppVersion = "1.0.0";

  static Future<void> checkUpdate(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('update')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final String latestVersion = data['latestVersion'] as String? ?? currentAppVersion;
      final String apkUrl = data['apkUrl'] as String? ?? '';
      final bool isMandatory = data['isMandatory'] as bool? ?? false;
      final String changelogBn = data['changelog_bn'] as String? ?? '';
      final String changelogEn = data['changelog_en'] as String? ?? '';

      if (_isNewerVersion(currentAppVersion, latestVersion) && apkUrl.isNotEmpty) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, apkUrl, isMandatory, changelogBn, changelogEn);
        }
      }
    } catch (e) {
      debugPrint("Error checking updates: $e");
    }
  }

  // Simple semver comparison helper
  static bool _isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String apkUrl,
    bool isMandatory,
    String changelogBn,
    String changelogEn,
  ) {
    final bool isBn = LanguageManager().currentLanguage == 'bn';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final changelog = isBn ? changelogBn : changelogEn;

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) {
        return PopScope(
          canPop: !isMandatory,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isBn ? 'নতুন আপডেট উপলব্ধ!' : 'Update Available!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn 
                      ? 'স্টাডিমেট অ্যাপের একটি নতুন সংস্করণ ($latestVersion) উপলব্ধ রয়েছে।' 
                      : 'A new version ($latestVersion) of StudyMate is available.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (changelog.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    isBn ? 'নতুন কী থাকছে:' : "What's New:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Text(
                        changelog,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isBn ? 'পরে করুন' : 'Later',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(apkUrl);
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isBn ? 'আপডেট করুন' : 'Update Now',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
