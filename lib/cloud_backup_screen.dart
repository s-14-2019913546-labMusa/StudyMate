import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'language_manager.dart';
import 'cloud_sync_service.dart';
import 'google_drive_service.dart';

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
