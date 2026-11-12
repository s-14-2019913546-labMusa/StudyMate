import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'language_manager.dart';
import 'cloud_sync_service.dart';
import 'google_drive_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  final CloudSyncService _syncService = CloudSyncService();
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isLoading = false;
  DateTime? _lastBackupTime;
  DateTime? _lastDriveBackupTime;

  @override
  void initState() {
    super.initState();
    _loadBackupStatus();
  }

  Future<void> _loadBackupStatus() async {
    setState(() => _isLoading = true);
    final time = await _syncService.getLastBackupTime();
    final driveTime = await _driveService.getLastDriveBackupTime();
    if (mounted) {
      setState(() {
        _lastBackupTime = time;
        _lastDriveBackupTime = driveTime;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBackup() async {
    setState(() => _isLoading = true);
    try {
      await _syncService.createBackup();
      await _loadBackupStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup successful!'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}'.tr())),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    // Show confirmation dialog before restoring
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore Backup'.tr()),
        content: Text('Are you sure you want to restore your data? This will merge your backed up data with your current data.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            child: Text('Restore'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _syncService.restoreBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore successful!'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: ${e.toString()}'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDriveBackup() async {
    setState(() => _isLoading = true);
    try {
      await _driveService.backupToDrive();
      await _loadBackupStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drive backup successful!'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drive backup failed: ${e.toString()}'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDriveRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore from Google Drive'.tr()),
        content: Text('Are you sure you want to restore your data from Google Drive? This will merge your backed up data with your current data.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            child: Text('Restore'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _driveService.restoreFromDrive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore from Drive successful!'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore from Drive failed: ${e.toString()}'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- ফোনে ফাইল হিসেবে ব্যাকআপ (বিনা খরচে, ইন্টারনেট ছাড়াই রিস্টোর) ----------

  String get _fileName => 'StudyMate-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';

  Future<void> _saveToPhone() async {
    setState(() => _isLoading = true);
    try {
      final json = await _syncService.generateBackupJsonString();
      final bytes = utf8.encode(json);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: trx('Save backup file', 'ব্যাকআপ ফাইল সেভ করুন'),
        fileName: _fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path == null
            ? trx('Not saved.', 'সেভ করা হয়নি।')
            : trx('Backup saved on your phone ✓', 'ব্যাকআপ ফোনে সেভ হয়েছে ✓')),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Backup failed: $e', 'ব্যাকআপ হয়নি: $e'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareBackup() async {
    setState(() => _isLoading = true);
    try {
      final json = await _syncService.generateBackupJsonString();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(json);
      if (!mounted) return;
      setState(() => _isLoading = false);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: trx('StudyMate backup', 'StudyMate ব্যাকআপ'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Backup failed: $e', 'ব্যাকআপ হয়নি: $e'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trx('Restore from file?', 'ফাইল থেকে রিস্টোর করবেন?')),
        content: Text(trx('The backup will be merged with your current data. Nothing is deleted.',
            'ব্যাকআপের ডেটা এখনকার ডেটার সাথে মিলিয়ে দেওয়া হবে। কিছু মুছবে না।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Restore'.tr())),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final f = picked.files.first;
      final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) throw Exception(trx('Could not read the file', 'ফাইল পড়া যায়নি'));
      await _syncService.restoreFromJsonString(utf8.decode(bytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Restored ✓', 'রিস্টোর হয়েছে ✓'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Restore failed: $e', 'রিস্টোর হয়নি: $e'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFileBackupCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(trx('Backup file on your phone', 'ফোনে ব্যাকআপ ফাইল'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(trx('Free', 'ফ্রি'), style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              trx('Saves all your notes, tasks, routines, flashcards, mistakes and more into one file. Keep it on your phone, or use Share to put it in Google Drive, email or WhatsApp. No paid plan needed.',
                  'আপনার নোট, টাস্ক, রুটিন, ফ্ল্যাশকার্ড, ভুলের খাতা সহ সব ডেটা একটা ফাইলে রাখে। ফোনে রাখুন, অথবা "শেয়ার" দিয়ে Google Drive, ইমেইল বা WhatsApp-এ রাখুন। কোনো টাকার প্ল্যান লাগে না।'),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _saveToPhone,
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: Text(trx('Save', 'সেভ')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _shareBackup,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(trx('Share', 'শেয়ার')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isLoading ? null : _restoreFromFile,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: Text(trx('Restore from a backup file', 'ব্যাকআপ ফাইল থেকে রিস্টোর')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard({
    required String title,
    required String description,
    required IconData icon,
    required DateTime? lastBackupTime,
    required VoidCallback onBackup,
    required VoidCallback onRestore,
    required bool isRecommended,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title.tr(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Recommended'.tr(),
                                style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastBackupTime != null 
                            ? '${'Last Backup'.tr()}: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastBackupTime)}'
                            : 'No backup found'.tr(),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading || lastBackupTime == null ? null : onRestore,
                    icon: const Icon(Icons.cloud_download_rounded, size: 18),
                    label: Text('Restore'.tr()),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : onBackup,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text('Backup'.tr()),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cloud Backup & Sync'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_done_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 16),
                Text(
                  'Secure Your Data'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep your diary, notes, and tasks safe. Choose where you want to store your backup.'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _buildFileBackupCard(),
                const SizedBox(height: 16),
                _buildBackupCard(
                  title: 'Google Drive',
                  description: 'Export a copy of your data directly to your personal Google Drive account. You have full control over your backup file.',
                  icon: Icons.add_to_drive_rounded,
                  lastBackupTime: _lastDriveBackupTime,
                  onBackup: _handleDriveBackup,
                  onRestore: _handleDriveRestore,
                  isRecommended: false,
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
