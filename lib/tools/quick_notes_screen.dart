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
import '../deck_dashboard_screen.dart';
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
import '../widgets/undo_snackbar.dart';
import '../widgets/skeleton.dart';

// ==========================================
// 9. Quick Notes Screen (ইন্টারন্যাশনাল মানের নোটস)
// ==========================================
class QuickNotesScreen extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;

  const QuickNotesScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  late final RichTextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isSaving = false;
  bool _isProcessingAI = false;
  String? _geminiApiKey;
  Stream<QuerySnapshot>? _notesLimitStream;
  Stream<QuerySnapshot>? _notesAllStream;

  // Custom Undo variables
  final List<String> _undoHistory = [];
  bool _isUndoing = false;
  Timer? _historyTimer;

  void _initUndoListener() {
    _undoHistory.add(_contentController.text);
    int prevWordCount = _getWordCount(_contentController.text);

    _contentController.addListener(() {
      if (_contentController.selection.isValid) {
        _lastSelection = _contentController.selection;
        _checkIfImageSelected();
      }
      if (_isUndoing) return;

      final currentText = _contentController.text;
      final currentWordCount = _getWordCount(currentText);

      // Check if a word boundary was just typed
      final bool isWordBoundary = currentText.isNotEmpty &&
          (currentText.endsWith(' ') ||
           currentText.endsWith('\n') ||
           currentText.endsWith('.') ||
           currentText.endsWith(',') ||
           currentText.endsWith('?') ||
           currentText.endsWith('!'));

      // If word count changed or a word boundary is typed, save state immediately
      if (currentWordCount != prevWordCount || isWordBoundary) {
        prevWordCount = currentWordCount;
        _historyTimer?.cancel();
        if (_undoHistory.isEmpty || _undoHistory.last != currentText) {
          if (_undoHistory.length >= 6) {
            _undoHistory.removeAt(0);
          }
          _undoHistory.add(currentText);
        }
      } else {
        // Fallback debounce: if typing is paused for 1.2s, record the state
        _historyTimer?.cancel();
        _historyTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          final pauseText = _contentController.text;
          if (_undoHistory.isEmpty || _undoHistory.last != pauseText) {
            if (_undoHistory.length >= 6) {
              _undoHistory.removeAt(0);
            }
            _undoHistory.add(pauseText);
          }
        });
      }
    });
  }

  int _getWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  void _performUndo() {
    if (_undoHistory.length > 1) {
      setState(() {
        _isUndoing = true;
        _undoHistory.removeLast();
        final prevText = _undoHistory.last;
        _contentController.text = prevText;
        _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
        _isUndoing = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('No more undo steps available (Max 5 steps)'.tr())),
      );
    }
  }

  @override
  void initState() {
    _contentController = RichTextEditingController(
      context: context,
      isDarkMode: () => _isNoteDarkMode,
    );
    super.initState();
    _initUndoListener();
    _loadApiKey();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialContent != null) {
      _contentController.setMarkdownText(widget.initialContent!);
    }
    if (currentUser != null) {
      _notesLimitStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots();
      _notesAllStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<void> _loadApiKey() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _geminiApiKey = doc.data()?['geminiApiKey'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading API key in notes: $e');
    }
  }

  // Advanced Note States
  bool _isNoteDarkMode = false;
  double _fontSize = 16.0;
  bool _isRecording = false;

  // Audio Recording States
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioFilePath;

  // Image Attachment States
  final ImagePicker _imagePicker = ImagePicker();
  String? _imageFilePath;

  void _insertFormatting(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _lastSelection;
    _contentFocusNode.requestFocus();
    if (selection.isValid && selection.start >= 0 && selection.end <= text.length) {
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      final int newOffset = selection.start + prefix.length + selectedText.length + suffix.length;
      final newSelection = TextSelection.collapsed(offset: newOffset);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      _lastSelection = newSelection;
    } else {
      final newText = text + prefix + suffix;
      final int newOffset = newText.length - suffix.length;
      final newSelection = TextSelection.collapsed(offset: newOffset);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      _lastSelection = newSelection;
    }
  }

  void _insertBullet() {
    final text = _contentController.text;
    final selection = _lastSelection;
    final prefix = '\n• ';
    _contentFocusNode.requestFocus();
    if (selection.isValid && selection.start >= 0 && selection.end <= text.length) {
      final newText = text.replaceRange(selection.start, selection.end, prefix);
      final newSelection = TextSelection.collapsed(offset: selection.start + prefix.length);
       _contentController.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
      _lastSelection = newSelection;
    } else {
      _insertFormatting(prefix, '');
    }
  }

  void _pickTextColor() {
    // Save the current selection before opening dialog (dialog causes focus loss)
    final savedSelection = _lastSelection;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor,
        title: Text(trx('Select Text Color', 'লেখার রঙ বাছুন'), style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildColorItem('Red', Colors.red, 'red', savedSelection),
              _buildColorItem('Blue', Colors.blue, 'blue', savedSelection),
              _buildColorItem('Green', Colors.green, 'green', savedSelection),
              _buildColorItem('Yellow', Colors.yellow, 'yellow', savedSelection),
              _buildColorItem('Orange', Colors.orange, 'orange', savedSelection),
              _buildColorItem('Purple', Colors.purple, 'purple', savedSelection),
              _buildColorItem('Pink', Colors.pink, 'pink', savedSelection),
              _buildColorItem('Teal', Colors.teal, 'teal', savedSelection),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(trx('Cancel', 'বাতিল'))),
        ],
      ),
    );
  }

  Widget _buildColorItem(String name, Color color, String colorKey, TextSelection savedSelection) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (savedSelection.isValid && !savedSelection.isCollapsed &&
            savedSelection.start >= 0 && savedSelection.end <= _contentController.text.length) {
          // Text is selected, apply color style to selected text
          _contentController.toggleStyle(TextStyle(color: color), savedSelection);
        } else {
          // No text selected, insert color formatting tags so user can type colored text
          _contentController.toggleStyle(TextStyle(color: color), savedSelection);
        }
        // Restore focus to the text field
        _contentFocusNode.requestFocus();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: TextStyle(fontSize: 12, color: _isNoteDarkMode ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _summarizeNoteWithAI() async {
    final noteContent = _contentController.text.trim();
    if (noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Cannot summarize an empty note.'.tr())),
      );
      return;
    }

    setState(() => _isProcessingAI = true);
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('AI is summarizing your note...'.tr())),
    );

    try {
      final summary = await AIService.summarizeNote(noteContent, _geminiApiKey);
      if (!mounted) return;
      if (summary.isNotEmpty) {
        setState(() {
          _contentController.setMarkdownText('${_contentController.toMarkdown()}\n\n$summary');
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Summary added to note!'.tr()), backgroundColor: Colors.purple),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trx('Failed to summarize: $e', 'সারাংশ করা যায়নি: $e')), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAI = false);
      }
    }
  }

  void _writeWithAI() {
    final TextEditingController promptController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text(trx('Write with AI', 'AI দিয়ে লিখুন')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trx('Enter a topic or question (e.g. "Write about Kazi Nazrul" or "Explain photosynthesis"). AI will write a full study note.', 'বিষয় বা প্রশ্ন লিখুন (যেমন "কাজী নজরুল সম্পর্কে লেখো")। AI পুরো একটি নোট লিখে দেবে।'),
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              decoration: const InputDecoration(
                hintText: 'Enter topic prompt...',
                prefixIcon: Icon(Icons.psychology_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trx('Cancel', 'বাতিল')),
          ),
          ElevatedButton(
            onPressed: () async {
              final prompt = promptController.text.trim();
              if (prompt.isEmpty) return;
              Navigator.pop(ctx);
              
              setState(() => _isProcessingAI = true);
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('AI is researching and writing...'.tr())),
              );

              try {
                final generatedContent = await AIService.generateNoteContent(prompt, _geminiApiKey);
                if (!mounted) return;
                if (generatedContent.isNotEmpty) {
                  setState(() {
                    _contentController.setMarkdownText(generatedContent);
                    if (_titleController.text.trim().isEmpty) {
                      _titleController.text = prompt.length > 20 ? '${prompt.substring(0, 20)}...' : prompt;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('AI study note generated successfully!'.tr()), backgroundColor: Colors.indigo),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(trx('Generation failed: $e', 'তৈরি করা যায়নি: $e')), backgroundColor: Colors.redAccent),
                );
              } finally {
                if (mounted) {
                  setState(() => _isProcessingAI = false);
                }
              }
            },
            child: Text(trx('Write Note', 'নোট লিখুন')),
          ),
        ],
      ),
    );
  }

  // অডিও রেকর্ডিং টগল করার মূল লজিক
  Future<void> _toggleAudioRecording() async {
    if (_isRecording) {
      // রেকর্ডিং বন্ধ করা
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioFilePath = path;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Audio recorded! Will be saved with the note.'.tr())));
    } else {
      // পারমিশন চেক করে রেকর্ডিং শুরু করা
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/note_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _audioFilePath = null;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Recording audio...'.tr())));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Microphone permission required.'.tr())));
      }
    }
  }

  // গ্যালারি থেকে ছবি সিলেক্ট করার লজিক
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        _contentController.insertImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Failed to pick image: $e', 'ছবি বাছাই করা যায়নি: $e'))));
    }
  }

  bool _isEditingImageDialogOpened = false;

  void _checkIfImageSelected() {
    if (_isEditingImageDialogOpened) return;
    
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    for (final match in imageRegex.allMatches(text)) {
      if (selection.start >= match.start && selection.start <= match.end) {
        _isEditingImageDialogOpened = true;
        final altText = match.group(1) ?? 'Image';
        final pathWithParams = match.group(2) ?? '';
        
        // Use a post frame callback to avoid showing sheet while building text span
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showImageEditDialog(match.start, match.end, altText, pathWithParams);
        });
        break;
      }
    }
  }

  void _showImageEditDialog(int start, int end, String altText, String pathWithParams) {
    String basePath = pathWithParams;
    double rotation = 0;
    double shadow = 0;
    double cropFactor = 1.0;
    
    try {
      final uri = Uri.parse(pathWithParams);
      basePath = uri.path;
      rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
      shadow = double.tryParse(uri.queryParameters['shadow'] ?? '0') ?? 0;
      cropFactor = double.tryParse(uri.queryParameters['crop'] ?? '1.0') ?? 1.0;
    } catch (_) {
      basePath = pathWithParams;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isNetwork = basePath.startsWith('http') || basePath.startsWith('https') || basePath.startsWith('blob:');
            Widget imageWidget;
            if (isNetwork) {
              imageWidget = Image.network(
                basePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, size: 40),
              );
            } else {
              if (kIsWeb) {
                imageWidget = const Icon(Icons.broken_image_rounded, size: 40);
              } else {
                imageWidget = Image.file(
                  File(basePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, size: 40),
                );
              }
            }

            if (cropFactor < 1.0) {
              imageWidget = ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: cropFactor,
                  heightFactor: cropFactor,
                  child: imageWidget,
                ),
              );
            }

            // Apply dark vignette overlay ON the image (not around it)
            if (shadow > 0) {
              final double opacity = (shadow / 20.0).clamp(0.0, 0.75);
              imageWidget = Stack(
                children: [
                  imageWidget,
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: opacity),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final int quarters = (rotation ~/ 90) % 4;
            if (quarters > 0) {
              imageWidget = RotatedBox(quarterTurns: quarters, child: imageWidget);
            }

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(trx('Image Settings', 'ছবির সেটিংস'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isNoteDarkMode ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  
                  // Preview box — clean, no box shadow
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(height: 120, child: imageWidget),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Rotate option
                  ListTile(
                    leading: const Icon(Icons.rotate_right_rounded, color: Colors.blueAccent),
                    title: Text(trx('Rotate 90°', '৯০° ঘোরান'), style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
                    trailing: Text('${rotation.toInt()}°', style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black54)),
                    onTap: () {
                      rotation = (rotation + 90) % 360;
                      setModalState(() {});
                      _updateImageParamsInText(start, end, altText, basePath, rotation, shadow, cropFactor);
                    },
                  ),
                  
                  // Shadow option — vignette on the image
                  ListTile(
                    leading: const Icon(Icons.brightness_3_rounded, color: Colors.blueGrey),
                    title: Text(trx('Vignette Shadow', 'কোণায় ছায়া'), style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
                    subtitle: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.2),
                        thumbColor: Colors.blueAccent,
                        overlayColor: Colors.blueAccent.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: shadow,
                        min: 0,
                        max: 20,
                        divisions: 10,
                        onChanged: (v) {
                          shadow = v;
                          setModalState(() {});
                          _updateImageParamsInText(start, end, altText, basePath, rotation, shadow, cropFactor);
                        },
                      ),
                    ),
                    trailing: Text('${shadow.toInt()}', style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black54)),
                  ),
                  
                  // Crop option
                  ListTile(
                    leading: const Icon(Icons.crop_rounded, color: Colors.green),
                    title: Text(trx('Crop / Zoom Factor', 'কাটা / জুম'), style: TextStyle(color: _isNoteDarkMode ? Colors.white : Colors.black87)),
                    subtitle: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.green,
                        inactiveTrackColor: Colors.green.withValues(alpha: 0.2),
                        thumbColor: Colors.green,
                        overlayColor: Colors.green.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: cropFactor,
                        min: 0.5,
                        max: 1.0,
                        onChanged: (v) {
                          cropFactor = v;
                          setModalState(() {});
                          _updateImageParamsInText(start, end, altText, basePath, rotation, shadow, cropFactor);
                        },
                      ),
                    ),
                    trailing: Text('${(cropFactor * 100).toInt()}%', style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black54)),
                  ),
                  
                  // Delete option
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    title: Text(trx('Delete Image', 'ছবি মুছুন'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final updatedText = _contentController.text.replaceRange(start, end, '');
                      _contentController.value = TextEditingValue(
                        text: updatedText,
                        selection: TextSelection.collapsed(offset: start),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _isEditingImageDialogOpened = false;
    });
  }

  void _updateImageParamsInText(int start, int end, String alt, String path, double rot, double shad, double crop) {
    final text = _contentController.text;
    final newPath = '$path?rotate=${rot.toInt()}&shadow=${shad.toInt()}&crop=$crop';
    final newFullMatch = '![$alt]($newPath)';
    final updatedText = text.replaceRange(start, end, newFullMatch);
    
    _contentController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + newFullMatch.length),
    );
  }

  Widget _buildInlineImageCards(Color textColor) {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, _) {
        final currentText = _contentController.text;
        final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
        final currentMatches = imageRegex.allMatches(currentText).toList();
        if (currentMatches.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.photo_library_rounded, size: 14,
                        color: _isNoteDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Attached Images (${currentMatches.length})',
                      style: TextStyle(
                          fontSize: 12,
                          color: _isNoteDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ...currentMatches.asMap().entries.map((entry) {
                final idx = entry.key;
                final match = entry.value;
                final altText = match.group(1) ?? 'Image';
                final pathWithParams = match.group(2) ?? '';

                String basePath = pathWithParams;
                double rotation = 0;
                try {
                  final uri = Uri.parse(pathWithParams);
                  basePath = uri.path;
                  rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
                } catch (_) {}

                final isNetwork = basePath.startsWith('http') ||
                    basePath.startsWith('https') ||
                    basePath.startsWith('blob:');
                final quarters = (rotation ~/ 90).toInt() % 4;

                Widget thumbnail = _buildThumbnail(basePath, isNetwork, quarters);

                return Draggable<int>(
                  data: idx,
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isNoteDarkMode ? const Color(0xFF333333) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [thumbnail, const SizedBox(width: 8), Expanded(child: Text(altText, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
                    ),
                  ),
                  childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _imageCard(thumbnail, altText, idx, match, currentText, textColor)),
                  child: DragTarget<int>(
                    onAcceptWithDetails: (details) {
                      final fromIdx = details.data;
                      final toIdx = idx;
                      if (fromIdx == toIdx) return;
                      final allM = imageRegex.allMatches(currentText).toList();
                      if (fromIdx >= allM.length || toIdx >= allM.length) return;
                      final fromM = allM[fromIdx];
                      final toM = allM[toIdx];
                      String newText = currentText;
                      if (fromM.start > toM.start) {
                        newText = newText.replaceRange(fromM.start, fromM.end, toM.group(0)!);
                        newText = newText.replaceRange(toM.start, toM.end, fromM.group(0)!);
                      } else {
                        newText = newText.replaceRange(toM.start, toM.end, fromM.group(0)!);
                        newText = newText.replaceRange(fromM.start, fromM.end, toM.group(0)!);
                      }
                      _contentController.value = TextEditingValue(
                        text: newText,
                        selection: _contentController.selection,
                      );
                    },
                    builder: (ctx, candidateData, _) => _imageCard(
                      thumbnail, altText, idx, match, currentText, textColor,
                      highlight: candidateData.isNotEmpty,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(String basePath, bool isNetwork, int quarters) {
    Widget img;
    if (isNetwork) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          basePath, width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _brokenImageBox(),
        ),
      );
    } else if (kIsWeb) {
      img = Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_rounded, color: Colors.blue, size: 28),
          SizedBox(height: 2),
          Text(trx('Image', 'ছবি'), style: TextStyle(fontSize: 10, color: Colors.blue)),
        ]),
      );
    } else {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(basePath), width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _brokenImageBox(),
        ),
      );
    }
    if (quarters > 0) img = RotatedBox(quarterTurns: quarters, child: img);
    return img;
  }

  Widget _brokenImageBox() => Container(
    width: 72, height: 72, color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28)),
  );

  Widget _imageCard(Widget thumbnail, String altText, int idx, RegExpMatch match,
      String currentText, Color textColor, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: highlight
            ? (_isNoteDarkMode ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50)
            : (_isNoteDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? Colors.blue : (_isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
          width: highlight ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.drag_indicator_rounded,
                color: _isNoteDarkMode ? Colors.grey.shade600 : Colors.grey.shade400, size: 20),
            const SizedBox(width: 6),
            thumbnail,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(altText,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Image ${idx + 1}  •  Hold to reorder',
                      style: TextStyle(fontSize: 11,
                          color: _isNoteDarkMode ? Colors.grey.shade500 : Colors.grey.shade500)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showImageEditDialog(match.start, match.end, altText, match.group(2) ?? ''),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tune_rounded, size: 16, color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    final updatedText = currentText.replaceRange(match.start, match.end, '');
                    _contentController.value = TextEditingValue(
                      text: updatedText,
                      selection: TextSelection.collapsed(offset: match.start),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_rounded, size: 16, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty && _audioFilePath == null && _imageFilePath == null) return;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    String? audioUrl;
    String? imageUrl = _imageFilePath;
    
    if (_audioFilePath != null) {
      try {
        final File audioFile = File(_audioFilePath!);
        // ফায়ারবেস ক্লাউড স্টোরেজে আপলোড
        final storageRef = FirebaseStorage.instance.ref().child('notes_audio/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a');
        final uploadTask = kIsWeb
            ? await storageRef.putData(await audioFile.readAsBytes())
            : await storageRef.putFile(audioFile);
        audioUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Audio Upload Error: $e");
      }
    }

    // ছবি ফায়ারবেস ক্লাউড স্টোরেজে আপলোড (লেগাসি অ্যাটাচমেন্ট থাকলে)
    if (_imageFilePath != null && !_contentController.text.contains(_imageFilePath!)) {
      try {
        final File imageFile = File(_imageFilePath!);
        final storageRef = FirebaseStorage.instance.ref().child('notes_images/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = kIsWeb
            ? await storageRef.putData(await imageFile.readAsBytes())
            : await storageRef.putFile(imageFile);
        imageUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        debugPrint("Image Upload Error: $e");
      }
    }

    // আপলোড এম্বেডেড লোকাল ইমেজ ফাইল বা ব্রাউজার ব্লব ফাইল
    String noteContent = _contentController.toMarkdown();
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    final matches = imageRegex.allMatches(noteContent).toList();
    
    for (final match in matches) {
      final altText = match.group(1) ?? 'Image';
      final pathWithParams = match.group(2) ?? '';
      
      final uri = Uri.parse(pathWithParams);
      final basePath = uri.path;
      
      if (!basePath.startsWith('http') && !basePath.startsWith('https')) {
        try {
          Uint8List bytes;
          if (kIsWeb || basePath.startsWith('blob:')) {
            // ব্রাউজার ব্লব URL থেকে রিড করা
            final response = await http.get(Uri.parse(basePath));
            bytes = response.bodyBytes;
          } else {
            // লোকাল স্টোরেজ থেকে রিড করা
            bytes = await File(basePath).readAsBytes();
          }

          final storageRef = FirebaseStorage.instance.ref().child('notes_images/${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}.jpg');
          final uploadTask = await storageRef.putData(bytes);
          final networkUrl = await uploadTask.ref.getDownloadURL();
          
          final queryStr = uri.hasQuery ? '?${uri.query}' : '';
          final newPathWithParams = '$networkUrl$queryStr';
          
          final oldMatch = match.group(0)!;
          final newMatch = '![$altText]($newPathWithParams)';
          noteContent = noteContent.replaceAll(oldMatch, newMatch);
        } catch (e) {
          debugPrint("Error uploading inline image: $e");
        }
      }
    }

    final noteData = {
      'title': _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Untitled Note',
      'content': noteContent.trim(),
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (widget.noteId != null) {
      final noteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .doc(widget.noteId);
      await _saveVersionSnapshot(noteRef, noteData['title'] as String, noteData['content'] as String);
      await noteRef.set(noteData, SetOptions(merge: true));
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notes')
          .add(noteData);
    }

    _titleController.clear();
    _contentController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus(); // কিবোর্ড নামিয়ে দেওয়ার জন্য
    }
    
    setState(() {
      _isSaving = false;
      _audioFilePath = null;
      _imageFilePath = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Note saved securely!'.tr())));
      if (widget.noteId != null) {
        Navigator.pop(context); // Return after editing existing note
      }
    }
  }

  /// সেভ করার আগে আগের লেখাটা versions সাব-কালেকশনে রেখে দেয় (সর্বোচ্চ ১০টা)
  Future<void> _saveVersionSnapshot(DocumentReference noteRef, String newTitle, String newContent) async {
    try {
      final old = await noteRef.get();
      final data = old.data() as Map<String, dynamic>?;
      if (data == null) return;
      final oldTitle = (data['title'] ?? '').toString();
      final oldContent = (data['content'] ?? '').toString();
      if (oldTitle == newTitle && oldContent == newContent) return; // কিছু বদলায়নি

      final versions = noteRef.collection('versions');
      await versions.add({
        'title': oldTitle,
        'content': oldContent,
        'savedAt': FieldValue.serverTimestamp(),
      });

      // পুরনো ভার্সন ছেঁটে ফেলা (শেষ ১০টা রাখা)
      final all = await versions.orderBy('savedAt', descending: true).get();
      if (all.docs.length > 10) {
        for (final d in all.docs.skip(10)) {
          await d.reference.delete();
        }
      }
    } catch (e) {
      debugPrint('Version snapshot error: $e');
    }
  }

  void _showVersionHistory() {
    final textColor = _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text(trx('Version History', 'আগের ভার্সন'), style: TextStyle(color: textColor)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: (widget.noteId == null || currentUser == null)
              ? Text(trx('A new note has no earlier versions yet. Save it, and later edits will keep the old text here.', 'নতুন নোটের এখনো কোনো আগের ভার্সন নেই। নোটটি সেভ করে পরে এডিট করলে আগের লেখাগুলো এখানে জমা হবে।'),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
              : FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .collection('notes')
                      .doc(widget.noteId)
                      .collection('versions')
                      .orderBy('savedAt', descending: true)
                      .limit(10)
                      .get(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Text(trx('No earlier versions yet. When you edit and save the note, the old text will appear here.', 'এখনো কোনো আগের ভার্সন নেই। নোট এডিট করে সেভ করলে আগের লেখা এখানে আসবে।'),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final v = docs[i].data() as Map<String, dynamic>;
                        final ts = v['savedAt'] as Timestamp?;
                        final when = ts != null ? DateFormat('dd MMM yyyy, h:mm a').format(ts.toDate()) : 'Just now';
                        final content = (v['content'] ?? '').toString();
                        final preview = content.length > 60 ? '${content.substring(0, 60)}...' : content;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(when, style: TextStyle(color: textColor, fontSize: 14)),
                          subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _titleController.text = (v['title'] ?? '').toString();
                                _contentController.setMarkdownText(content);
                              });
                              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                                  content: Text(trx('Restored the version from $when. Tap Save to keep it.', '$when-এর ভার্সন ফিরিয়ে আনা হয়েছে। রাখতে চাইলে Save চাপুন।'))));
                            },
                            child: Text(trx('Restore', 'ফিরিয়ে আনুন')),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(trx('Close', 'বন্ধ'))),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNote(String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNoteDarkMode ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor,
        title: Text(trx('Delete Note?', 'নোট মুছবেন?'), style: TextStyle(color: _isNoteDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface)),
        content: Text(trx('Are you sure you want to delete this note?', 'আপনি কি নোটটি মুছে ফেলতে চান?'),
          style: TextStyle(color: _isNoteDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('notes')
            .doc(docId);
        final backup = (await ref.get()).data();
        await ref.delete();
        showUndoSnackBar(messenger, trx('Note deleted.', 'নোট মুছে ফেলা হয়েছে।'), () async {
          if (backup != null) await ref.set(backup);
        });
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(trx('Could not delete the note: $e', 'নোট মোছা যায়নি: $e'))),
        );
      }
    }
  }

  void _showPreviousNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isDark = _isNoteDarkMode; 
        Color cardColor = isDark ? const Color(0xFF2D2D2D) : Theme.of(context).cardColor;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(trx('Previous Notes', 'আগের নোট'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                  IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              Expanded(
                child: currentUser == null 
                  ? Center(child: Text(trx('Please log in to view notes.', 'নোট দেখতে লগইন করুন।'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _notesAllStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const SkeletonCardList(count: 3, shrinkWrap: true, padding: EdgeInsets.symmetric(vertical: 8));
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(trx('No notes yet. Write your first note above!', 'এখনো কোনো নোট নেই। উপরে প্রথম নোটটা লিখুন!'), style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)));

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final title = data['title'] ?? 'Untitled';
                            final content = _stripMarkdown(data['content'] ?? '');
                            final timestamp = data['timestamp'] as Timestamp?;
                            final audioUrl = data['audioUrl'] as String?;
                            final imageUrl = data['imageUrl'] as String?;
                            String dateStr = 'Just now';
                            if (timestamp != null) {
                              dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                            }

                            return Card(
                              color: cardColor,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(
                                    noteId: doc.id,
                                    title: title,
                                    content: data['content'] ?? '',
                                    date: dateStr,
                                    audioUrl: audioUrl,
                                    imageUrl: imageUrl,
                                  )));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          if (audioUrl != null)
                                            Icon(Icons.mic_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20),
                                          if (imageUrl != null)
                                            Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.image_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20)),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            tooltip: 'Delete Note',
                                            onPressed: () => _confirmDeleteNote(doc.id),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(dateStr, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.black38, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _audioRecorder.dispose();
    _historyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isNoteDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    Color textColor = _isNoteDarkMode ? Colors.white : Colors.black87;
    Color cardColor = _isNoteDarkMode ? const Color(0xFF2D2D2D) : Colors.white;

    return Scaffold(
      resizeToAvoidBottomInset: true, // কিবোর্ড উঠলে ভিউ উপরে উঠে যাবে
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(trx('Smart Notes', 'স্মার্ট নোট'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo (Max 5 steps)',
            onPressed: _performUndo,
          ),
          IconButton(
            icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.save_rounded),
            tooltip: 'Save Note',
            onPressed: _isSaving ? null : _saveNote,
          ),
          IconButton(
            icon: Icon(_isNoteDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Dark Mode',
            onPressed: () => setState(() => _isNoteDarkMode = !_isNoteDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Version History',
            onPressed: () => _showVersionHistory(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // FAB এর জন্য জায়গা
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isProcessingAI)
              const LinearProgressIndicator(color: Colors.indigoAccent),
            
            // 1. Plain Bold Title Field (Directly on Page Background)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  color: _isNoteDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Note Title...',
                  hintStyle: TextStyle(
                    color: _isNoteDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // 2. Smart Editor Container
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  // Boxed Content Body
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isNoteDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // ডায়েরির মতো দাগ দেওয়ার জন্য
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LinedPaperPainter(lineHeight: _fontSize * 1.5, isDarkMode: _isNoteDarkMode),
                            ),
                          ),
                          TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            maxLines: null,
                            minLines: 10,
                            style: TextStyle(fontSize: _fontSize, color: textColor, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Start writing your notes here...',
                              hintStyle: TextStyle(
                                color: _isNoteDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              filled: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Rich Text Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isNoteDarkMode ? const Color(0xFF333333) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                      border: Border(top: BorderSide(color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade200)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFormatBtn(Icons.format_bold_rounded, () => _contentController.toggleStyle(const TextStyle(fontWeight: FontWeight.bold), _lastSelection), tooltip: 'Bold'),
                          _buildFormatBtn(Icons.format_italic_rounded, () => _contentController.toggleStyle(const TextStyle(fontStyle: FontStyle.italic), _lastSelection), tooltip: 'Italic'),
                          _buildFormatBtn(Icons.format_quote_rounded, () => _insertFormatting('\n> ', ''), tooltip: 'Quote'),
                          _buildFormatBtn(Icons.format_list_bulleted_rounded, _insertBullet, tooltip: 'Bullet List'),
                          _buildFormatBtn(Icons.format_color_text_rounded, _pickTextColor, tooltip: 'Text Color'),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
                          _buildFormatBtn(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded, _toggleAudioRecording, tooltip: 'Record Audio', color: _isRecording ? Colors.red : Colors.deepOrange),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
                          _buildFormatBtn(Icons.summarize_rounded, _summarizeNoteWithAI, tooltip: 'AI Summary', color: Colors.purple),
                          _buildFormatBtn(Icons.auto_awesome_rounded, _writeWithAI, tooltip: 'Write with AI', color: Colors.indigo),
                          Container(width: 1, height: 24, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 8)),
                          _buildFormatBtn(Icons.text_increase_rounded, () => setState(() => _fontSize += 2), tooltip: 'Increase Font'),
                          _buildFormatBtn(Icons.text_decrease_rounded, () => setState(() => _fontSize > 10 ? _fontSize -= 2 : null), tooltip: 'Decrease Font'),
                        ],
                      ),
                    ),
                  ),

                  // Audio Attachment Indicator
                  if (_audioFilePath != null && !_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(trx('Voice note attached', 'ভয়েস নোট যুক্ত'), style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => setState(() => _audioFilePath = null)),
                        ],
                      ),
                    ),

                  // Image Attachment Indicator
                  if (_imageFilePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_imageFilePath!), width: 40, height: 40, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Text(trx('Image attached', 'ছবি যুক্ত'), style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => setState(() => _imageFilePath = null)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 2. Previous Notes Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(trx('Previous Notes', 'আগের নোট'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7))),
                  TextButton(onPressed: _showPreviousNotesBottomSheet, child: Text(trx('View All', 'সব দেখুন')))
                ],
              ),
            ),
            currentUser == null 
              ? Center(child: Text(trx('Please log in to view notes.', 'নোট দেখতে লগইন করুন।')))
              : StreamBuilder<QuerySnapshot>(
                  stream: _notesLimitStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const SkeletonCardList(count: 3, shrinkWrap: true, padding: EdgeInsets.symmetric(vertical: 8));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(trx('No notes yet. Write your first note above!', 'এখনো কোনো নোট নেই। উপরে প্রথম নোটটা লিখুন!'), style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Untitled';
                        final content = _stripMarkdown(data['content'] ?? '');
                        final timestamp = data['timestamp'] as Timestamp?;
                        final audioUrl = data['audioUrl'] as String?;
                        final imageUrl = data['imageUrl'] as String?;
                        String dateStr = 'Just now';
                        if (timestamp != null) {
                          dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                        }

                        return Card(
                          color: cardColor,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(
                                noteId: doc.id,
                                title: title,
                                content: data['content'] ?? '',
                                date: dateStr,
                                audioUrl: audioUrl,
                                imageUrl: imageUrl,
                              )));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      if (audioUrl != null)
                                        Icon(Icons.mic_rounded, color: textColor.withValues(alpha: 0.6), size: 20),
                                      if (imageUrl != null)
                                        Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.image_rounded, color: textColor.withValues(alpha: 0.6), size: 20)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete Note',
                                        onPressed: () => _confirmDeleteNote(doc.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(dateStr, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ),
                        );
                    },
                  );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatBtn(IconData icon, VoidCallback onTap, {String? tooltip, Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? (_isNoteDarkMode ? Colors.grey.shade300 : Colors.black87)),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
    );
  }

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*|\*'), '')
        .replaceAll(RegExp(r'<color=[^>]*>|<\/color>'), '')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)|\[.*?\]\(.*?\)'), '[Image]');
  }
}

// ==========================================
// Note Detail Screen (নোট পড়ার স্ক্রিন)
// ==========================================
class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final String title;
  final String content;
  final String date;
  final String? audioUrl;
  final String? imageUrl;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    required this.title,
    required this.content,
    required this.date,
    this.audioUrl,
    this.imageUrl,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  bool _isNoteDarkMode = false;
  bool _isPlayingAudio = false;
  bool _isPlayingAttachedAudio = false; // User Recorded Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlayingAttachedAudio = false);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlayingAudio = false);
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleAttachedAudio() async {
    if (widget.audioUrl == null) return;
    if (_isPlayingAttachedAudio) {
      await _audioPlayer.pause();
      setState(() => _isPlayingAttachedAudio = false);
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl!));
      setState(() => _isPlayingAttachedAudio = true);
    }
  }

  String _stripMarkdownForTTS(String text) {
    return text
        .replaceAll(RegExp(r'\*\*|\*'), '')
        .replaceAll(RegExp(r'<color=[^>]*>|<\/color>'), '')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)|\[.*?\]\(.*?\)'), '');
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      await _flutterTts.stop();
      setState(() {
        _isPlayingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Audio paused.'.tr()),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      final textToRead = _stripMarkdownForTTS(widget.content);
      if (textToRead.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Note is empty or has no readable text.'.tr())),
        );
        return;
      }
      
      final bool hasBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(textToRead);
      if (hasBengali) {
        await _flutterTts.setLanguage("bn-BD");
      } else {
        await _flutterTts.setLanguage("en-US");
      }
      
      setState(() {
        _isPlayingAudio = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(hasBengali ? 'নোটটি পড়ে শোনানো হচ্ছে...' : 'Reading note aloud...'),
            ],
          ),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _flutterTts.speak(textToRead);
    }
  }

  bool _isGeneratingQuiz = false;

  // নোট থেকে কুইজ (ফ্ল্যাশকার্ড ডেক) তৈরি করে সাথে সাথে খুলে দেয়
  Future<void> _generateQuizFromNote() async {
    if (_isGeneratingQuiz) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (widget.content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('নোটটি খালি, কুইজ বানানো যাবে না।'.tr())));
      return;
    }
    setState(() => _isGeneratingQuiz = true);
    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('✨ Generating AI Quiz from this note...'.tr())));
    try {
      final apiKey = await AIService.getSavedApiKey(user.uid);
      final cards = await AIService.generateQuizFromNote(widget.content, apiKey);
      if (!mounted) return;
      if (cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
            content: Text('এই নোট থেকে প্রশ্ন বানানো গেল না। নোটে আরও তথ্য লিখুন বা Profile → AI Settings-এ Gemini API Key দিন।'.tr())));
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final cardList = <Map<String, dynamic>>[];
      for (int i = 0; i < cards.length; i++) {
        cardList.add({'id': '$now$i', 'front': cards[i]['front'], 'back': cards[i]['back'], 'difficulty': 'medium'});
      }
      final title = 'Quiz: ${widget.title.isEmpty ? 'Note' : widget.title}';
      final deckTitle = title.length > 30 ? title.substring(0, 30) : title;
      final ref = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('flashcard_decks')
          .add({
        'title': deckTitle,
        'description': 'Quiz generated from your note "${widget.title}".',
        'cards': cardList,
        'sourceNoteId': widget.noteId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeckDashboardScreen(deckId: ref.id, deckTitle: deckTitle, allCards: cardList),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not make the quiz: $e', 'কুইজ বানাতে সমস্যা হয়েছে: $e'))));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isNoteDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    Color textColor = _isNoteDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(_isNoteDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Dark Mode',
            onPressed: () => setState(() => _isNoteDarkMode = !_isNoteDarkMode),
          ),
          IconButton(
            icon: Icon(_isPlayingAudio ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded, color: Colors.deepPurple),
            tooltip: 'Read Aloud (TTS)',
            onPressed: _toggleAudio,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 8),
            Text(widget.date, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            Divider(height: 40, color: _isNoteDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
            // Markdown রেন্ডার করার জন্য Text এর বদলে MarkdownBody ব্যবহার করা হলো
            SelectionArea(
              child: MarkdownBody(
                selectable: true,
                data: widget.content,
                softLineBreak: true,
                extensionSet: md.ExtensionSet(
                  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  [
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                    ColorSyntax(),
                  ],
                ),
                builders: {
                  'color': ColorElementBuilder(context, isDarkMode: _isNoteDarkMode),
                },
                sizedImageBuilder: (config) => _NoteDetailImageWidget(pathWithParams: config.uri.toString()),
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(fontSize: 18, height: 1.8, color: textColor),
                  h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  h2: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  h3: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  h4: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  h5: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  h6: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
                  strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  listBullet: TextStyle(fontSize: 18, color: textColor),
                  blockquote: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.8)),
                  blockquoteDecoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
                  ),
                ),
              ),
            ), 
            
            if (widget.imageUrl != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(widget.imageUrl!, fit: BoxFit.cover, width: double.infinity),
              ),
            ],
            
            if (widget.audioUrl != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: Icon(_isPlayingAttachedAudio ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: _toggleAttachedAudio,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(trx('Recorded Voice Note', 'রেকর্ড করা ভয়েস নোট'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // Edit Note Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickNotesScreen(
                        noteId: widget.noteId,
                        initialTitle: widget.title,
                        initialContent: widget.content,
                      ),
                    ),
                  ).then((_) {
                    // Pop this screen when returning from editing to refresh list view
                    Navigator.pop(context);
                  });
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(trx('Edit Note', 'নোট এডিট')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 80), // Fab এর জন্য জায়গা
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateQuizFromNote,
        icon: const Icon(Icons.quiz_rounded),
        label: Text(trx('Generate AI Quiz', 'AI কুইজ বানান')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ==========================================
// Custom Markdown Editor & Renderer Helper Classes
// ==========================================

Color getAdaptiveColor(Color color, bool isDark) {
  final int val = color.value & 0xFFFFFF;
  if (isDark) {
    switch (val) {
      case 0xF44336: // Colors.red
      case 0xD32F2F:
        return const Color(0xFFE57373); // red 300
      case 0x2196F3: // Colors.blue
      case 0x1976D2:
        return const Color(0xFF64B5F6); // blue 300
      case 0x4CAF50: // Colors.green
      case 0x388E3C:
        return const Color(0xFF81C784); // green 300
      case 0xFFEB3B: // Colors.yellow
      case 0xFBC02D:
        return const Color(0xFFFFF176); // yellow 300
      case 0xFF9800: // Colors.orange
      case 0xF57C00:
        return const Color(0xFFFFB74D); // orange 300
      case 0x9C27B0: // Colors.purple
      case 0x7B1FA2:
        return const Color(0xFFBA68C8); // purple 300
      case 0xE91E63: // Colors.pink
      case 0xC2185B:
        return const Color(0xFFF06292); // pink 300
      case 0x009688: // Colors.teal
      case 0x00796B:
        return const Color(0xFF4DB6AC); // teal 300
      default:
        return color;
    }
  } else {
    switch (val) {
      case 0xF44336: // Colors.red
        return const Color(0xFFD32F2F); // red 700
      case 0x2196F3: // Colors.blue
        return const Color(0xFF1976D2); // blue 700
      case 0x4CAF50: // Colors.green
        return const Color(0xFF388E3C); // green 700
      case 0xFFEB3B: // Colors.yellow
        return const Color(0xFFF57C00); // map to dark gold/orange for readability
      case 0xFF9800: // Colors.orange
        return const Color(0xFFE65100); // orange 900
      case 0x9C27B0: // Colors.purple
        return const Color(0xFF7B1FA2); // purple 700
      case 0xE91E63: // Colors.pink
        return const Color(0xFFC2185B); // pink 700
      case 0x009688: // Colors.teal
        return const Color(0xFF00796B); // teal 700
      default:
        return color;
    }
  }
}

class _TagToken {
  final String type; // 'color_start', 'color_end', 'bold', 'italic', 'text'
  final String value;
  _TagToken(this.type, this.value);
}

class _StyleScope {
  final String type; // 'bold', 'italic', 'color'
  final int startIndex;
  final Color? color;
  _StyleScope(this.type, this.startIndex, {this.color});
}

class _StyleSpan {
  final int start;
  final int end;
  final TextStyle style;

  _StyleSpan({required this.start, required this.end, required this.style});
}

class _TagInsertion {
  final int index;
  final String tag;
  _TagInsertion({required this.index, required this.tag});
}

class RichTextEditingController extends TextEditingController {
  final BuildContext context;
  final bool Function() isDarkMode;
  List<_StyleSpan> spans = [];
  TextStyle currentToggleStyle = const TextStyle();

  RichTextEditingController({super.text, required this.context, required this.isDarkMode});

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    
    if (oldText != newText) {
      _updateSpans(oldText, newText, newValue.selection);
      
      // Apply currentToggleStyle to newly typed characters
      if (currentToggleStyle != const TextStyle() && newText.length > oldText.length) {
        // Find the insertion point
        int startDiff = 0;
        while (startDiff < oldText.length &&
               startDiff < newText.length &&
               oldText[startDiff] == newText[startDiff]) {
          startDiff++;
        }
        final int insertedLen = newText.length - oldText.length;
        if (insertedLen > 0) {
          spans.add(_StyleSpan(
            start: startDiff,
            end: startDiff + insertedLen,
            style: currentToggleStyle,
          ));
          _mergeAdjacentSpans();
        }
      }
    }
    
    super.value = newValue;
  }

  void _updateSpans(String oldText, String newText, TextSelection newSelection) {
    int startDiff = 0;
    while (startDiff < oldText.length &&
           startDiff < newText.length &&
           oldText[startDiff] == newText[startDiff]) {
      startDiff++;
    }
    
    int oldEnd = oldText.length;
    int newEnd = newText.length;
    while (oldEnd > startDiff &&
           newEnd > startDiff &&
           oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    
    final int deletedLen = oldEnd - startDiff;
    final int insertedLen = newEnd - startDiff;
    
    final List<_StyleSpan> updatedSpans = [];
    
    for (final span in spans) {
      int s = span.start;
      int e = span.end;
      
      if (startDiff <= s) {
        s -= deletedLen;
        s += insertedLen;
        e -= deletedLen;
        e += insertedLen;
      }
      else if (startDiff > s && startDiff < e) {
        e -= deletedLen;
        e += insertedLen;
      }
      
      if (s < e && s >= 0 && e <= newText.length) {
        updatedSpans.add(_StyleSpan(start: s, end: e, style: span.style));
      }
    }
    
    spans = updatedSpans;
  }

  void toggleStyle(TextStyle styleToToggle, TextSelection selection) {
    if (!selection.isValid || selection.isCollapsed) {
      // Toggle the style for future typing
      if (styleToToggle.color != null) {
        if (currentToggleStyle.color == styleToToggle.color) {
          // Remove the color if same color is toggled again
          currentToggleStyle = currentToggleStyle.copyWith(color: null);
        } else {
          currentToggleStyle = currentToggleStyle.copyWith(color: styleToToggle.color);
        }
      } else {
        currentToggleStyle = currentToggleStyle.merge(styleToToggle);
      }
      notifyListeners();
      return;
    }
    
    final int start = selection.start;
    final int end = selection.end;
    
    bool isApplied = true;
    for (int i = start; i < end; i++) {
      if (!_isStyleAppliedAt(i, styleToToggle)) {
        isApplied = false;
        break;
      }
    }
    
    if (isApplied) {
      _removeStyleFromRange(start, end, styleToToggle);
    } else {
      _addStyleToRange(start, end, styleToToggle);
    }
    
    notifyListeners();
  }

  bool _isStyleAppliedAt(int index, TextStyle targetStyle) {
    for (final span in spans) {
      if (index >= span.start && index < span.end) {
        if (targetStyle.fontWeight == FontWeight.bold && span.style.fontWeight == FontWeight.bold) return true;
        if (targetStyle.fontStyle == FontStyle.italic && span.style.fontStyle == FontStyle.italic) return true;
        if (targetStyle.color != null && span.style.color == targetStyle.color) return true;
      }
    }
    return false;
  }

  void _addStyleToRange(int start, int end, TextStyle styleToAdd) {
    _removeStyleFromRange(start, end, styleToAdd); // clear overlaps of same attribute type
    spans.add(_StyleSpan(start: start, end: end, style: styleToAdd));
    _mergeAdjacentSpans();
  }

  void _removeStyleFromRange(int start, int end, TextStyle styleToRemove) {
    final List<_StyleSpan> newSpans = [];
    for (final span in spans) {
      bool isMatch = false;
      if (styleToRemove.fontWeight == FontWeight.bold && span.style.fontWeight == FontWeight.bold) isMatch = true;
      if (styleToRemove.fontStyle == FontStyle.italic && span.style.fontStyle == FontStyle.italic) isMatch = true;
      if (styleToRemove.color != null && span.style.color != null) isMatch = true;
      
      if (!isMatch) {
        newSpans.add(span);
        continue;
      }
      
      if (end <= span.start || start >= span.end) {
        newSpans.add(span);
      }
      else if (start <= span.start && end >= span.end) {
        // Discard span
      }
      else if (start > span.start && end < span.end) {
        newSpans.add(_StyleSpan(start: span.start, end: start, style: span.style));
        newSpans.add(_StyleSpan(start: end, end: span.end, style: span.style));
      }
      else if (start <= span.start && end < span.end) {
        newSpans.add(_StyleSpan(start: end, end: span.end, style: span.style));
      }
      else if (start > span.start && end >= span.end) {
        newSpans.add(_StyleSpan(start: span.start, end: start, style: span.style));
      }
    }
    spans = newSpans;
  }

  void _mergeAdjacentSpans() {
    spans.sort((a, b) => a.start.compareTo(b.start));
    final List<_StyleSpan> merged = [];
    
    for (final span in spans) {
      if (merged.isEmpty) {
        merged.add(span);
      } else {
        final last = merged.last;
        bool canMerge = last.end == span.start && _areStylesEqual(last.style, span.style);
        if (canMerge) {
          merged[merged.length - 1] = _StyleSpan(start: last.start, end: span.end, style: last.style);
        } else {
          merged.add(span);
        }
      }
    }
    spans = merged;
  }

  bool _areStylesEqual(TextStyle a, TextStyle b) {
    return a.fontWeight == b.fontWeight &&
           a.fontStyle == b.fontStyle &&
           a.color == b.color;
  }

  String toMarkdown() {
    final String plainText = text;
    if (plainText.isEmpty) return '';
    if (spans.isEmpty) return plainText;

    // Build per-character style info
    final List<TextStyle?> charStyles = List.filled(plainText.length, null);
    for (final span in spans) {
      for (int i = span.start; i < span.end && i < plainText.length; i++) {
        charStyles[i] = charStyles[i] == null ? span.style : charStyles[i]!.merge(span.style);
      }
    }

    // Group consecutive chars with same style into segments
    final StringBuffer result = StringBuffer();
    int i = 0;
    while (i < plainText.length) {
      final TextStyle? style = charStyles[i];
      int j = i + 1;
      while (j < plainText.length && _styleEquivalent(charStyles[j], style)) {
        j++;
      }
      final segText = plainText.substring(i, j);
      if (style == null) {
        result.write(segText);
      } else {
        String seg = segText;
        // innermost: wrap with bold/italic
        final isBold = style.fontWeight == FontWeight.bold;
        final isItalic = style.fontStyle == FontStyle.italic;
        if (isBold && isItalic) {
          seg = '***$seg***';
        } else if (isBold) {
          seg = '**$seg**';
        } else if (isItalic) {
          seg = '*$seg*';
        }
        // outermost: wrap with color if set
        if (style.color != null) {
          final colorHex = _getColorHex(style.color!);
          seg = '<color=$colorHex>$seg</color>';
        }
        result.write(seg);
      }
      i = j;
    }
    return result.toString();
  }

  bool _styleEquivalent(TextStyle? a, TextStyle? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.fontWeight == b.fontWeight &&
           a.fontStyle == b.fontStyle &&
           a.color == b.color;
  }

  String _getColorHex(Color color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.blue) return 'blue';
    if (color == Colors.green) return 'green';
    if (color == Colors.yellow) return 'yellow';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.pink) return 'pink';
    if (color == Colors.teal) return 'teal';
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  void setMarkdownText(String markdown) {
    final parsed = parseMarkdownToSpans(markdown);
    value = TextEditingValue(
      text: parsed.plainText,
      selection: TextSelection.collapsed(offset: parsed.plainText.length),
    );
    spans = parsed.spans;
    notifyListeners();
  }

  ParsedMarkdown parseMarkdownToSpans(String markdown) {
    final List<_TagToken> tokens = [];
    int i = 0;
    while (i < markdown.length) {
      if (markdown.startsWith('**', i)) {
        tokens.add(_TagToken('bold', '**'));
        i += 2;
      } else if (markdown.startsWith('*', i)) {
        tokens.add(_TagToken('italic', '*'));
        i += 1;
      } else if (markdown.startsWith('</color>', i)) {
        tokens.add(_TagToken('color_end', '</color>'));
        i += 8;
      } else if (markdown.startsWith('<color=', i)) {
        int endIdx = markdown.indexOf('>', i);
        if (endIdx != -1) {
          final tag = markdown.substring(i, endIdx + 1);
          tokens.add(_TagToken('color_start', tag));
          i = endIdx + 1;
        } else {
          tokens.add(_TagToken('text', markdown[i]));
          i++;
        }
      } else {
        tokens.add(_TagToken('text', markdown[i]));
        i++;
      }
    }

    final List<_StyleSpan> spans = [];
    final StringBuffer plainText = StringBuffer();
    final List<_StyleScope> activeScopes = [];

    for (final token in tokens) {
      if (token.type == 'text') {
        plainText.write(token.value);
      } else if (token.type == 'color_start') {
        final colorStr = token.value.substring(7, token.value.length - 1);
        Color? tagColor;
        if (colorStr.startsWith('#')) {
          final hex = colorStr.substring(1);
          final val = int.tryParse(hex, radix: 16);
          if (val != null) tagColor = Color(val | 0xFF000000);
        } else {
          switch (colorStr.toLowerCase()) {
            case 'red': tagColor = Colors.red; break;
            case 'blue': tagColor = Colors.blue; break;
            case 'green': tagColor = Colors.green; break;
            case 'yellow': tagColor = Colors.yellow; break;
            case 'orange': tagColor = Colors.orange; break;
            case 'purple': tagColor = Colors.purple; break;
            case 'pink': tagColor = Colors.pink; break;
            case 'teal': tagColor = Colors.teal; break;
          }
        }
        activeScopes.add(_StyleScope('color', plainText.length, color: tagColor));
      } else if (token.type == 'color_end') {
        int idx = activeScopes.lastIndexWhere((s) => s.type == 'color');
        if (idx != -1) {
          final scope = activeScopes.removeAt(idx);
          if (scope.color != null) {
            spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: TextStyle(color: scope.color)));
          }
        }
      } else if (token.type == 'bold') {
        int idx = activeScopes.lastIndexWhere((s) => s.type == 'bold');
        if (idx == -1) {
          activeScopes.add(_StyleScope('bold', plainText.length));
        } else {
          final scope = activeScopes.removeAt(idx);
          spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontWeight: FontWeight.bold)));
        }
      } else if (token.type == 'italic') {
        int idx = activeScopes.lastIndexWhere((s) => s.type == 'italic');
        if (idx == -1) {
          activeScopes.add(_StyleScope('italic', plainText.length));
        } else {
          final scope = activeScopes.removeAt(idx);
          spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontStyle: FontStyle.italic)));
        }
      }
    }

    // Clean up any unmatched scopes by closing them at plainText.length
    for (final scope in activeScopes) {
      if (scope.type == 'bold') {
        spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (scope.type == 'italic') {
        spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (scope.type == 'color' && scope.color != null) {
        spans.add(_StyleSpan(start: scope.startIndex, end: plainText.length, style: TextStyle(color: scope.color)));
      }
    }

    return ParsedMarkdown(plainText: plainText.toString(), spans: spans);
  }

  void insertImage(String imagePath) {
    final currentText = this.text;
    final sel = selection;
    // Always ensure there is a blank line before and after the image tag
    // so the cursor can easily land below it for continued typing.
    final String prefix = (sel.isValid && sel.start > 0 && currentText[sel.start - 1] != '\n') ? '\n' : '';
    final imageTag = '${prefix}![Image]($imagePath?rotate=0&shadow=0&crop=1.0)\n';
    
    if (sel.isValid && sel.start >= 0 && sel.end <= currentText.length) {
      final newText = currentText.replaceRange(sel.start, sel.end, imageTag);
      // Cursor goes right AFTER the trailing newline so user can type immediately
      final cursorPos = sel.start + imageTag.length;
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorPos),
      );
    } else {
      final newText = currentText + imageTag;
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final String text = this.text;
    if (text.isEmpty) return TextSpan(text: '', style: style);

    final int len = text.length;
    final List<TextStyle> charStyles = List.generate(len, (_) => style ?? const TextStyle());

    // Apply bold, italic, color spans — with bounds guard
    for (final span in spans) {
      final int s = span.start.clamp(0, len);
      final int e = span.end.clamp(0, len);
      for (int i = s; i < e; i++) {
        TextStyle spanStyle = span.style;
        if (spanStyle.color != null) {
          spanStyle = spanStyle.copyWith(color: getAdaptiveColor(spanStyle.color!, isDarkMode()));
        }
        charStyles[i] = charStyles[i].merge(spanStyle);
      }
    }

    // Apply inline image tag styling (renders as styled text, no WidgetSpan crash)
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    for (final match in imageRegex.allMatches(text)) {
      final int mStart  = match.start.clamp(0, len);
      final int mEnd    = match.end.clamp(0, len);
      final int altStart = (mStart + 2).clamp(0, len);
      final int altEnd   = (altStart + (match.group(1) ?? '').length).clamp(0, len);
      final int pathStart = (altEnd + 1).clamp(0, len); // ']('
      final int pathEnd   = mEnd;

      for (int i = mStart;    i < altStart  && i < len; i++) charStyles[i] = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
      for (int i = altStart;  i < altEnd    && i < len; i++) charStyles[i] = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline);
      for (int i = altEnd;    i < pathStart && i < len; i++) charStyles[i] = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
      for (int i = pathStart; i < pathEnd   && i < len; i++) charStyles[i] = const TextStyle(fontSize: 0, color: Colors.transparent);
    }

    // Quote/bullet paragraph formatting — with bounds guard
    final quoteRegex  = RegExp(r'(^|\n)>\s*(.*)');
    final bulletRegex = RegExp(r'(^|\n)[•\*\-]\s+(.*)');

    void applyParagraphStyle(RegExp regex, TextStyle paraStyle) {
      for (final match in regex.allMatches(text)) {
        int startIdx = match.start.clamp(0, len);
        if (startIdx < len && text[startIdx] == '\n') startIdx++;
        final int endIdx = match.end.clamp(0, len);
        for (int i = startIdx; i < endIdx; i++) {
          charStyles[i] = charStyles[i].merge(paraStyle);
        }
      }
    }

    applyParagraphStyle(
      quoteRegex,
      TextStyle(fontStyle: FontStyle.italic, color: isDarkMode() ? Colors.grey.shade400 : Colors.grey.shade600),
    );
    applyParagraphStyle(
      bulletRegex,
      const TextStyle(fontWeight: FontWeight.w500),
    );

    // Build final TextSpan list by grouping consecutive same-style chars
    final List<TextSpan> children = [];
    int start = 0;
    TextStyle currentStyle = charStyles[0];
    for (int i = 1; i < len; i++) {
      if (charStyles[i] != currentStyle) {
        children.add(TextSpan(text: text.substring(start, i), style: currentStyle));
        start = i;
        currentStyle = charStyles[i];
      }
    }
    children.add(TextSpan(text: text.substring(start), style: currentStyle));

    return TextSpan(children: children, style: style);
  }


}

class _ParagraphFormatRange {
  final int start;
  final int end;
  final TextStyle style;

  _ParagraphFormatRange({required this.start, required this.end, required this.style});
}

class ParsedMarkdown {
  final String plainText;
  final List<_StyleSpan> spans;
  ParsedMarkdown({required this.plainText, required this.spans});
}

class ColorSyntax extends md.InlineSyntax {
  // dotAll:true so it spans across line breaks inside the tag
  ColorSyntax() : super(r'<color=(#[0-9a-fA-F]{6}|[a-zA-Z]+)>([\s\S]*?)</color>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final colorVal = match.group(1) ?? '';
    final innerMarkdown = match.group(2) ?? '';

    // Parse the inner content so **bold** and *italic* inside color work
    final innerDocument = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    // Parse inline content from inner markdown string
    final innerNodes = innerDocument.parseInline(innerMarkdown);

    final element = md.Element('color', innerNodes);
    element.attributes['value'] = colorVal;
    parser.addNode(element);
    return true;
  }
}

class ColorElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDarkMode;
  ColorElementBuilder(this.context, {required this.isDarkMode});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final baseStyle = preferredStyle ?? const TextStyle();
    return Text.rich(
      _buildSpan(element, baseStyle),
    );
  }

  TextSpan _buildSpan(md.Node node, TextStyle baseStyle) {
    if (node is md.Text) {
      return TextSpan(text: node.text, style: baseStyle);
    }
    if (node is md.Element) {
      TextStyle style = baseStyle;
      if (node.tag == 'strong' || node.tag == 'b') {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (node.tag == 'em' || node.tag == 'i') {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (node.tag == 'color') {
        final colorStr = node.attributes['value'] ?? '';
        Color? tagColor;
        if (colorStr.startsWith('#')) {
          final hex = colorStr.substring(1);
          final val = int.tryParse(hex, radix: 16);
          if (val != null) {
            tagColor = Color(val | 0xFF000000);
          }
        } else {
          switch (colorStr.toLowerCase()) {
            case 'red': tagColor = Colors.red; break;
            case 'blue': tagColor = Colors.blue; break;
            case 'green': tagColor = Colors.green; break;
            case 'yellow': tagColor = Colors.yellow; break;
            case 'orange': tagColor = Colors.orange; break;
            case 'purple': tagColor = Colors.purple; break;
            case 'pink': tagColor = Colors.pink; break;
            case 'teal': tagColor = Colors.teal; break;
          }
        }
        if (tagColor != null) {
          style = style.copyWith(color: getAdaptiveColor(tagColor, isDarkMode));
        }
      }
      
      return TextSpan(
        children: node.children?.map((c) => _buildSpan(c, style)).toList(),
        style: style,
      );
    }
    return const TextSpan();
  }
}

class InlineImageWidget extends StatefulWidget {
  final String pathWithParams;
  final void Function(String newPathWithParams) onChanged;
  final VoidCallback onDelete;

  const InlineImageWidget({super.key, required this.pathWithParams, required this.onChanged, required this.onDelete});

  @override
  State<InlineImageWidget> createState() => _InlineImageWidgetState();
}

class _InlineImageWidgetState extends State<InlineImageWidget> {
  late double _rotation;
  late double _shadow;
  late double _cropFactor;
  late String _basePath;

  @override
  void initState() {
    super.initState();
    _parseParams();
  }

  @override
  void didUpdateWidget(InlineImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathWithParams != widget.pathWithParams) {
      _parseParams();
    }
  }

  void _parseParams() {
    try {
      final uri = Uri.parse(widget.pathWithParams);
      _basePath = uri.path;
      _rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
      _shadow = double.tryParse(uri.queryParameters['shadow'] ?? '0') ?? 0;
      _cropFactor = double.tryParse(uri.queryParameters['crop'] ?? '1.0') ?? 1.0;
    } catch (e) {
      _basePath = widget.pathWithParams;
      _rotation = 0;
      _shadow = 0;
      _cropFactor = 1.0;
    }
  }

  void _updateParams() {
    final newPath = '$_basePath?rotate=${_rotation.toInt()}&shadow=${_shadow.toInt()}&crop=$_cropFactor';
    widget.onChanged(newPath);
  }

  void _showEditDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(trx('Edit Image', 'ছবি এডিট'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  
                  // Rotate option
                  ListTile(
                    leading: const Icon(Icons.rotate_right_rounded, color: Colors.blueAccent),
                    title: Text(trx('Rotate 90°', '৯০° ঘোরান'), style: TextStyle(color: Colors.black87)),
                    trailing: Text('${_rotation.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    onTap: () {
                      setState(() {
                        _rotation = (_rotation + 90) % 360;
                      });
                      setModalState(() {});
                      _updateParams();
                    },
                  ),
                  
                  // Shadow option — vignette overlay on image
                  ListTile(
                    leading: const Icon(Icons.brightness_3_rounded, color: Colors.blueGrey),
                    title: Text(trx('Vignette Shadow', 'কোণায় ছায়া'), style: TextStyle(color: Colors.black87)),
                    subtitle: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.2),
                        thumbColor: Colors.blueAccent,
                        overlayColor: Colors.blueAccent.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: _shadow,
                        min: 0,
                        max: 20,
                        divisions: 10,
                        onChanged: (v) {
                          setState(() { _shadow = v; });
                          setModalState(() {});
                          _updateParams();
                        },
                      ),
                    ),
                    trailing: Text('${_shadow.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  
                  // Crop option
                  ListTile(
                    leading: const Icon(Icons.crop_rounded, color: Colors.green),
                    title: Text(trx('Crop / Zoom Factor', 'কাটা / জুম'), style: TextStyle(color: Colors.black87)),
                    subtitle: Slider(
                      value: _cropFactor,
                      min: 0.5,
                      max: 1.0,
                      onChanged: (v) {
                        setState(() {
                          _cropFactor = v;
                        });
                        setModalState(() {});
                        _updateParams();
                      },
                    ),
                    trailing: Text('${(_cropFactor * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  
                  // Delete option
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    title: Text(trx('Delete Image', 'ছবি মুছুন'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = _basePath.startsWith('http') || _basePath.startsWith('https') || _basePath.startsWith('blob:');
    
    Widget imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        _basePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        ),
      );
    } else {
      if (kIsWeb) {
        imageWidget = Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        );
      } else {
        imageWidget = Image.file(
          File(_basePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
          ),
        );
      }
    }

    if (_cropFactor < 1.0) {
      imageWidget = ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: _cropFactor,
          heightFactor: _cropFactor,
          child: imageWidget,
        ),
      );
    }

    // Vignette shadow overlay ON the image itself
    if (_shadow > 0) {
      final double opacity = (_shadow / 20.0).clamp(0.0, 0.75);
      imageWidget = Stack(
        children: [
          imageWidget,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: opacity)],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final int quarters = (_rotation ~/ 90) % 4;
    if (quarters > 0) {
      imageWidget = RotatedBox(quarterTurns: quarters, child: imageWidget);
    }

    return GestureDetector(
      onTap: _showEditDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageWidget,
        ),
      ),
    );
  }
}

class _NoteDetailImageWidget extends StatelessWidget {
  final String pathWithParams;
  const _NoteDetailImageWidget({required this.pathWithParams});

  @override
  Widget build(BuildContext context) {
    String basePath = pathWithParams;
    double rotation = 0;
    double shadow = 0;
    double cropFactor = 1.0;

    try {
      final uri = Uri.parse(pathWithParams);
      basePath = uri.path;
      rotation = double.tryParse(uri.queryParameters['rotate'] ?? '0') ?? 0;
      shadow = double.tryParse(uri.queryParameters['shadow'] ?? '0') ?? 0;
      cropFactor = double.tryParse(uri.queryParameters['crop'] ?? '1.0') ?? 1.0;
    } catch (e) {
      basePath = pathWithParams;
    }

    final isNetwork = basePath.startsWith('http') || basePath.startsWith('https') || basePath.startsWith('blob:');
    
    Widget imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        basePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        ),
      );
    } else {
      if (kIsWeb) {
        imageWidget = Container(
          height: 120,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
        );
      } else {
        imageWidget = Image.file(
          File(basePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
          ),
        );
      }
    }

    if (cropFactor < 1.0) {
      imageWidget = ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: cropFactor,
          heightFactor: cropFactor,
          child: imageWidget,
        ),
      );
    }

    final int quarters = (rotation ~/ 90) % 4;
    if (quarters > 0) {
      imageWidget = RotatedBox(quarterTurns: quarters, child: imageWidget);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        boxShadow: shadow > 0 ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: shadow,
            spreadRadius: shadow / 4,
          )
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageWidget,
      ),
    );
  }
}

// ডায়েরির মতো দাগ আঁকার জন্য কাস্টম পেইন্টার
class _LinedPaperPainter extends CustomPainter {
  final double lineHeight;
  final bool isDarkMode;
  _LinedPaperPainter({required this.lineHeight, this.isDarkMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300
      ..strokeWidth = 1.0;

    for (double y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

