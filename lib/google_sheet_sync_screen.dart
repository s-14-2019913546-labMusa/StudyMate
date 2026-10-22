import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'google_sheet_routine_service.dart';

class GoogleSheetSyncScreen extends StatefulWidget {
  const GoogleSheetSyncScreen({super.key});

  @override
  State<GoogleSheetSyncScreen> createState() => _GoogleSheetSyncScreenState();
}

class _GoogleSheetSyncScreenState extends State<GoogleSheetSyncScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  bool _replaceExisting = false;
  List<Map<String, String>> _previewRows = [];
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final savedUrl = await GoogleSheetRoutineService.getSavedSheetUrl();
    debugPrint('DEBUG_SAVED_SHEET_URL: $savedUrl');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _urlController.text = savedUrl;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
    }
  }

  void _loadSampleData() {
    final sampleCsv = GoogleSheetRoutineService.generateSampleCsv();
    final rows = GoogleSheetRoutineService.parseCsvToRows(sampleCsv);
    setState(() {
      _previewRows = rows;
      _statusMessage = 'Sample routine loaded! Tap "Import to Routine" to add to your app.';
      _isSuccess = true;
    });
  }

  Future<void> _fetchAndPreview() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a Google Sheet link or click "Load Sample"')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _previewRows = [];
    });

    try {
      final csv = await GoogleSheetRoutineService.fetchCsvContent(url);
      final rows = GoogleSheetRoutineService.parseCsvToRows(csv);

      if (rows.isEmpty) {
        throw Exception('No valid data rows found in this sheet.');
      }

      await GoogleSheetRoutineService.saveSheetUrl(url);

      setState(() {
        _previewRows = rows;
        _statusMessage = 'Found ${rows.length} routine tasks in sheet! Review below and click "Import".';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceAll('Exception: ', '');
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndSync() async {
    if (_previewRows.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final count = await GoogleSheetRoutineService.syncRowsToFirestore(
        rows: _previewRows,
        replaceExisting: _replaceExisting,
      );

      setState(() {
        _statusMessage = '🎉 Successfully imported $count tasks into your Daily Routine!';
        _isSuccess = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('Successfully imported $count study tasks!'),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceAll('Exception: ', '');
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTemplateInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.table_chart, color: Colors.green),
            SizedBox(width: 8),
            Text('Sheet Column Format'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Create a Google Sheet with these column headers (English or Bangla):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 12),
              _ColumnDescItem(name: 'Date / তারিখ', desc: 'e.g. Today, Tomorrow, or 2026-10-21'),
              _ColumnDescItem(name: 'Subject / বিষয়', desc: 'e.g. Physics, Math, English'),
              _ColumnDescItem(name: 'Topic / অধ্যায়', desc: 'e.g. Vector Chapter 2, Integration'),
              _ColumnDescItem(name: 'Start Time / শুরু', desc: 'e.g. 08:00 AM or 20:00'),
              _ColumnDescItem(name: 'End Time / শেষ', desc: 'e.g. 09:30 AM or 21:30'),
              _ColumnDescItem(name: 'Category / ক্যাটাগরি', desc: 'e.g. Study, Revision, Exam'),
              _ColumnDescItem(name: 'Notes / নোট', desc: 'e.g. Exercise 9.1 to 9.5'),
              SizedBox(height: 12),
              Text(
                'Important: In Google Sheets, click "Share" and select "Anyone with the link can view" so StudyMate can read it.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheets Routine Sync'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Format Guide',
            onPressed: _showTemplateInfoDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Feature Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F5132), const Color(0xFF1E3A8A)]
                      : [const Color(0xFF10B981), const Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Auto-Sync from Google Drive',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Write your routine on Google Sheets from PC or phone, and sync to StudyMate with 1 click!',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sheet URL Input Section
            Text(
              'Google Sheet Link',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                prefixIcon: const Icon(Icons.table_chart_rounded, color: Colors.green),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded),
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: theme.cardColor,
              ),
            ),

            const SizedBox(height: 12),

            // Quick actions (Sample Data & Format Guide)
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('Try Sample Routine'),
                  onPressed: _loadSampleData,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Column Format'),
                  onPressed: _showTemplateInfoDialog,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Options: Replace vs Merge
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                value: _replaceExisting,
                onChanged: (val) => setState(() => _replaceExisting = val),
                title: const Text('Replace existing tasks for the day'),
                subtitle: Text(
                  _replaceExisting
                      ? 'Replaces current tasks for matching dates'
                      : 'Merges with current tasks without deleting them',
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: Icon(
                  _replaceExisting ? Icons.restart_alt_rounded : Icons.call_merge_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Fetch Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_rounded),
                label: Text(
                  _isLoading ? 'Fetching Sheet...' : 'Fetch & Preview Routine',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _fetchAndPreview,
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: _isSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview Tasks Section
            if (_previewRows.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preview (${_previewRows.length} Tasks)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Import to Routine'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isLoading ? null : _confirmAndSync,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _previewRows.length,
                itemBuilder: (context, index) {
                  final row = _previewRows[index];
                  final subject = row['subject'] ?? 'Subject';
                  final topic = row['topic'] ?? row['title'] ?? 'Topic';
                  final start = row['start_time'] ?? '';
                  final end = row['end_time'] ?? '';
                  final date = row['date'] ?? 'Today';
                  final duration = row['duration'] ?? '60';

                  final displayTitle = subject.isNotEmpty && subject != 'General' && subject != 'Study'
                      ? subject
                      : (topic.isNotEmpty ? topic.split('\n').first : 'Study Session');
                  final bool isDone = row['status']?.toLowerCase().contains('সম্পন্ন') == true ||
                      row['status'] == 'completed';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDone
                              ? Colors.green.withValues(alpha: 0.2)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.green, size: 20)
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (topic.isNotEmpty && topic != displayTitle) ...[
                              const SizedBox(height: 4),
                              Text(
                                topic.split('\n').first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    start.isNotEmpty ? "$start - $end" : "$duration mins",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                if (row['category'] != null && row['category']!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      row['category']!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDone)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'সম্পন্ন',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (row['notes'] != null && row['notes']!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.notes_rounded, size: 18, color: Colors.grey),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Bottom Import Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_task_rounded),
                  label: Text('Import All ${_previewRows.length} Tasks to Routine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _confirmAndSync,
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ColumnDescItem extends StatelessWidget {
  final String name;
  final String desc;
  const _ColumnDescItem({required this.name, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
