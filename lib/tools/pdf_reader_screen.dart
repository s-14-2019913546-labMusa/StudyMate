import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../daily_routine.dart';
import '../dashboard_screen.dart';
import '../calendar_screen.dart';
import '../focus_music_screen.dart';
import '../flashcards_screen.dart';
import '../dictionary_screen.dart';
import '../ai_service.dart';
import '../revision_147_screen.dart';
import '../islamic_life_screen.dart';
import '../theme_manager.dart';
import '../local_notification_service.dart';
import '../study_analytics_screen.dart';
import '../weekly_overview_screen.dart';
import '../task_history_screen.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import '../study_folder_manager_screen.dart';
import '../special_day_countdown_screen.dart';
import '../daily_diary_screen.dart';
import '../bookmarks_screen.dart';
import '../news_reader_screen.dart';
import '../social_hub_screen.dart';
import '../google_sheet_sync_screen.dart';
import '../multi_sheet_manager_screen.dart';
import '../notifications_hub_screen.dart';
import '../widgets/sound_picker_widget.dart';
import '../tools_screen.dart';

// ==========================================
// PDF Reader Screen (ইন-অ্যাপ পিডিএফ ভিউয়ার)
// ==========================================
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  List<Map<String, dynamic>> _pdfFiles = []; // {path, name}
  bool _isLoading = false;
  final _prefs = SharedPreferences.getInstance();
  final _user = FirebaseAuth.instance.currentUser;

  static const _prefsKey = 'saved_pdf_files';

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  Future<void> _loadSavedFiles() async {
    final prefs = await _prefs;
    final savedPaths = prefs.getStringList(_prefsKey) ?? [];
    final validFiles = savedPaths
        .where((p) => File(p).existsSync())
        .map((p) => {'path': p, 'name': p.split('/').last.split('\\').last})
        .toList();
    setState(() => _pdfFiles = List.from(validFiles));
  }

  Future<void> _saveFileList() async {
    final prefs = await _prefs;
    await prefs.setStringList(_prefsKey, _pdfFiles.map((f) => f['path'] as String).toList());
  }

  Future<void> _pickPdf() async {
    try {
      setState(() => _isLoading = true);
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newEntries = result.files
            .where((f) => f.path != null)
            .map((f) => {
                  'path': f.path!,
                  'name': f.name,
                })
            .toList();

        setState(() => _pdfFiles.addAll(newEntries));
        await _saveFileList();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newEntries.length} ${'PDFs imported successfully!'.tr()}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Error importing PDF:'.tr()} $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openPdf(Map<String, dynamic> fileEntry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppPdfViewerScreen(
          filePath: fileEntry['path'] as String,
          fileName: fileEntry['name'] as String,
          userId: _user?.uid ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardDeco = ThemeManager.getCardDecoration(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('PDF Reader'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos_rounded),
            tooltip: 'Import Document',
            onPressed: _pickPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _pdfFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: cardDeco,
                            child: Column(
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.redAccent),
                                const SizedBox(height: 16),
                                Text(
                                  'PDF Reader'.tr(),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Import Handnotes, Books or Lecture PDFs to study inside StudyMate.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _pickPdf,
                                  icon: const Icon(Icons.add_to_photos_rounded),
                                  label: const Text('Import Document'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Documents (${_pdfFiles.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _pdfFiles.length,
                            itemBuilder: (context, index) {
                              final fileEntry = _pdfFiles[index];
                              final file = File(fileEntry['path'] as String);
                              final String fileName = fileEntry['name'] as String;
                              final fileSize = file.existsSync()
                                  ? '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB'
                                  : 'File missing';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                                  ),
                                  title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(fileSize),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() => _pdfFiles.removeAt(index));
                                      _saveFileList();
                                    },
                                  ),
                                  onTap: () => _openPdf(fileEntry),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

/// In-App PDF Viewer with dark mode filter and bookmark system
class InAppPdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String userId;

  const InAppPdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.userId,
  });

  @override
  State<InAppPdfViewerScreen> createState() => _InAppPdfViewerScreenState();
}

class _InAppPdfViewerScreenState extends State<InAppPdfViewerScreen> {
  PDFViewController? _pdfController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isDarkMode = false;
  bool _showBookmarks = false;

  Set<int> _bookmarkedPages = {};
  final _firestore = FirebaseFirestore.instance;

  String get _bookmarkDocId =>
      '${widget.userId}_${widget.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (widget.userId.isEmpty) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('pdfBookmarks')
          .doc(_bookmarkDocId)
          .get();
      if (doc.exists) {
        final pages = List<int>.from(doc.data()?['pages'] ?? []);
        setState(() => _bookmarkedPages = pages.toSet());
      }
    } catch (_) {}
  }

  Future<void> _saveBookmarks() async {
    if (widget.userId.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('pdfBookmarks')
          .doc(_bookmarkDocId)
          .set({
        'fileName': widget.fileName,
        'pages': _bookmarkedPages.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarkedPages.contains(_currentPage)) {
        _bookmarkedPages.remove(_currentPage);
      } else {
        _bookmarkedPages.add(_currentPage);
      }
    });
    _saveBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBookmarked = _bookmarkedPages.contains(_currentPage);

    Widget pdfWidget = PDFView(
      filePath: widget.filePath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: _currentPage,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) => setState(() => _totalPages = pages ?? 0),
      onPageChanged: (page, total) => setState(() {
        _currentPage = page ?? 0;
        _totalPages = total ?? 0;
      }),
      onViewCreated: (controller) => _pdfController = controller,
    );

    if (_isDarkMode) {
      pdfWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: pdfWidget,
      );
    }

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.grey.shade900 : null,
        elevation: 0,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Dark mode toggle
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          // Bookmark toggle
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isBookmarked ? Colors.amber : null,
            ),
            tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Page ${_currentPage + 1}',
            onPressed: _toggleBookmark,
          ),
          // Show bookmark list
          if (_bookmarkedPages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_rounded),
              tooltip: 'My Bookmarks',
              onPressed: () => _showBookmarkPanel(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: pdfWidget),
          // Page navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _currentPage > 0
                      ? () => _pdfController?.setPage(_currentPage - 1)
                      : null,
                ),
                Expanded(
                  child: Text(
                    'পেজ ${_currentPage + 1} / $_totalPages${isBookmarked ? ' 🔖' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _currentPage < _totalPages - 1
                      ? () => _pdfController?.setPage(_currentPage + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookmarkPanel(BuildContext context) {
    final sortedBookmarks = _bookmarkedPages.toList()..sort();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔖 বুকমার্ক করা পেজ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedBookmarks.length,
                itemBuilder: (context, i) {
                  final page = sortedBookmarks[i];
                  return ListTile(
                    leading: const Icon(Icons.bookmark_rounded, color: Colors.amber),
                    title: Text('পেজ ${page + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => _bookmarkedPages.remove(page));
                        _saveBookmarks();
                        Navigator.pop(ctx);
                      },
                    ),
                    onTap: () {
                      _pdfController?.setPage(page);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


