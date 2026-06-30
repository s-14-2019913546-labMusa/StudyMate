import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:hijri/hijri_calendar.dart';
import 'package:pdf/pdf.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:easy_localization/easy_localization.dart' as el;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:screenshot/screenshot.dart';

class DailyDiaryScreen extends StatefulWidget {
  const DailyDiaryScreen({super.key});

  @override
  State<DailyDiaryScreen> createState() => _DailyDiaryScreenState();
}

class _DailyDiaryScreenState extends State<DailyDiaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _diaryController = TextEditingController();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();
  String? _editingDocId;

  // Settings
  double _fontSize = 18.0;
  String _fontFamily = 'System';
  String _bgTheme = 'Default';
  String? _bgImageBase64;
  double _bgOpacity = 0.2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _loadTodayEntry();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diaryController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('diary_font_size') ?? 18.0;
      _fontFamily = prefs.getString('diary_font_family') ?? 'System';
      _bgTheme = prefs.getString('diary_bg_theme') ?? 'Default';
      _bgImageBase64 = prefs.getString('diary_bg_image');
      _bgOpacity = prefs.getDouble('diary_bg_opacity') ?? 0.2;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('diary_font_size', _fontSize);
    prefs.setString('diary_font_family', _fontFamily);
    prefs.setString('diary_bg_theme', _bgTheme);
    if (_bgImageBase64 != null) {
      prefs.setString('diary_bg_image', _bgImageBase64!);
    } else {
      prefs.remove('diary_bg_image');
    }
    prefs.setDouble('diary_bg_opacity', _bgOpacity);
  }

  Future<void> _pickImage(void Function(void Function()) setModalState) async {
    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: xFile.path,
          uiSettings: [
            AndroidUiSettings(
                toolbarTitle: 'Crop Image',
                toolbarColor: Colors.deepOrange,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9
                ]),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
            WebUiSettings(context: context),
          ],
        );
        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          final base64String = base64Encode(bytes);
          setState(() => _bgImageBase64 = base64String);
          setModalState(() => _bgImageBase64 = base64String);
          _saveSettings();
        }
      }
    } catch (e) {
      debugPrint('Error picking/cropping image: $e');
    }
  }

  String _getBengaliDate(DateTime date) {
    final year = date.year;
    final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    int dayOfYear = int.parse(DateFormat('D').format(date));
    int offset = isLeapYear ? 1 : 0;
    
    int bYear = year - 593;
    if (date.month < 4 || (date.month == 4 && date.day < 14)) bYear--;
    
    List<int> bMonthDays = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, isLeapYear ? 30 : 29, 30];
    List<String> bMonths = ['বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র'];
    
    int startDay = 104 + offset;
    int currentDay = dayOfYear;
    if (currentDay < startDay) currentDay += 365 + offset;
    
    int daysPassed = currentDay - startDay;
    int m = 0;
    while (daysPassed >= bMonthDays[m]) {
      daysPassed -= bMonthDays[m];
      m++;
    }
    
    int bDay = daysPassed + 1;
    
    String convertToBanglaNumber(String number) {
      const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
      for (int i = 0; i < english.length; i++) {
        number = number.replaceAll(english[i], bangla[i]);
      }
      return number;
    }
    
    return '${convertToBanglaNumber(bDay.toString())} ${bMonths[m]} ${convertToBanglaNumber(bYear.toString())}';
  }

  String _getHijriDate(DateTime date) {
    try {
      final hDate = HijriCalendar.fromDate(date);
      return hDate.toFormat("dd MMMM yyyy");
    } catch (e) {
      return '';
    }
  }

  void _loadTodayEntry() {
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    setState(() {
      _diaryController.text = "তারিখ: $dateStr\nশিরোনাম: \n\n";
      _editingDocId = null;
    });
  }

  Future<void> _saveTodayEntry() async {
    if (_uid == null || _diaryController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final docId = _editingDocId ?? Timestamp.now().millisecondsSinceEpoch.toString();
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('dailyDiary')
          .doc(docId)
          .set({
        'date': Timestamp.fromDate(_selectedDate),
        'dateString': dateStr,
        'content': _diaryController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diary saved successfully!')));
      }
      
      _loadTodayEntry();
      
    } catch (e) {
      debugPrint('Error saving diary: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save diary.')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Diary Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Font Size'),
                      trailing: DropdownButton<double>(
                        value: _fontSize,
                        items: const [
                          DropdownMenuItem(value: 14.0, child: Text('Small')),
                          DropdownMenuItem(value: 18.0, child: Text('Medium')),
                          DropdownMenuItem(value: 24.0, child: Text('Large')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fontSize = v);
                            setModalState(() => _fontSize = v);
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Font Style'),
                      trailing: DropdownButton<String>(
                        value: _fontFamily,
                        items: const [
                          DropdownMenuItem(value: 'System', child: Text('System')),
                          DropdownMenuItem(value: 'Tiro Bangla', child: Text('Tiro Bangla')),
                          DropdownMenuItem(value: 'Anek Bangla', child: Text('Anek Bangla')),
                          DropdownMenuItem(value: 'Lora', child: Text('Lora')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fontFamily = v);
                            setModalState(() => _fontFamily = v);
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Background Theme'),
                      trailing: DropdownButton<String>(
                        value: _bgTheme,
                        items: const [
                          DropdownMenuItem(value: 'Default', child: Text('Default')),
                          DropdownMenuItem(value: 'Spring', child: Text('Spring (Falgun)')),
                          DropdownMenuItem(value: 'Monsoon', child: Text('Monsoon (Ashar)')),
                          DropdownMenuItem(value: 'Autumn', child: Text('Autumn (Sarat)')),
                          DropdownMenuItem(value: 'Winter', child: Text('Winter (Poush)')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _bgTheme = v);
                            setModalState(() => _bgTheme = v);
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Custom Background Image'),
                      trailing: ElevatedButton(
                        onPressed: () => _pickImage(setModalState),
                        child: const Text('Pick Image'),
                      ),
                    ),
                    if (_bgImageBase64 != null) ...[
                      ListTile(
                        title: const Text('Image Opacity'),
                        subtitle: Slider(
                          value: _bgOpacity,
                          min: 0.05,
                          max: 1.0,
                          onChanged: (v) {
                            setState(() => _bgOpacity = v);
                            setModalState(() => _bgOpacity = v);
                            _saveSettings();
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() => _bgImageBase64 = null);
                            setModalState(() => _bgImageBase64 = null);
                            _saveSettings();
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getBackgroundColor(bool isDark) {
    if (isDark) return Colors.grey.shade900;
    switch (_bgTheme) {
      case 'Spring': return const Color(0xFFF9FBE7);
      case 'Monsoon': return const Color(0xFFECEFF1);
      case 'Autumn': return const Color(0xFFE0F7FA);
      case 'Winter': return const Color(0xFFEFEBE9);
      default: return const Color(0xFFFDFBF7);
    }
  }

  TextStyle _getTextStyle(bool isDark) {
    TextStyle baseStyle = TextStyle(
      height: 2.2,
      fontSize: _fontSize,
      color: isDark ? Colors.white : Colors.black87,
    );
    
    switch (_fontFamily) {
      case 'Tiro Bangla': return GoogleFonts.tiroBangla(textStyle: baseStyle);
      case 'Anek Bangla': return GoogleFonts.anekBangla(textStyle: baseStyle);
      case 'Lora': return GoogleFonts.lora(textStyle: baseStyle);
      default: return baseStyle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Today's Page"),
            Tab(text: 'Old Pages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayPage(),
          _buildOldPages(),
        ],
      ),
    );
  }

  Widget _buildTodayPage() {
    final engDate = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);
    final benDate = _getBengaliDate(_selectedDate);
    final hijriDate = _getHijriDate(_selectedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textStyle = _getTextStyle(isDark);
    final lineHeight = _fontSize * 2.2;
    final startY = lineHeight;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _getBackgroundColor(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // --- HEADER MARGIN AREA ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: () {
                                  setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                                  _loadTodayEntry();
                                },
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(engDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(benDate, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                                    Text(hijriDate, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed: () {
                                  setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                                  _loadTodayEntry();
                                },
                              ),
                            ],
                          ),
                        ),
                        // Margin line
                        Divider(color: Colors.redAccent.withOpacity(0.5), thickness: 2, height: 2),
                        // --- MAIN WRITING AREA ---
                        Expanded(
                          child: Stack(
                            children: [
                              if (_bgImageBase64 != null)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: _bgOpacity,
                                    child: Image.memory(
                                      base64Decode(_bgImageBase64!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: LinedPaperPainter(
                                      lineColor: isDark ? Colors.grey.shade800 : Colors.blue.shade200,
                                      lineHeight: lineHeight,
                                      startY: startY,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
                                child: TextField(
                                  controller: _diaryController,
                                  maxLines: null,
                                  expands: true,
                                  keyboardType: TextInputType.multiline,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Dear Diary...',
                                    contentPadding: EdgeInsets.symmetric(vertical: 0.0),
                                  ),
                                  style: textStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTodayEntry,
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
              label: Text(_editingDocId == null ? 'Save Entry' : 'Update Entry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOldPages() {
    if (_uid == null) return const Center(child: Text('User not logged in'));
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                label: const Text('1 Week PDF'),
                onPressed: () => _downloadPDF(7),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                label: const Text('1 Month PDF'),
                onPressed: () => _downloadPDF(30),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .collection('dailyDiary')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No entries found.'));
              
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final dateStr = data['dateString'] as String;
                  final content = data['content'] as String;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExpansionTile(
                      title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(content),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                                onPressed: () {
                                  setState(() {
                                    _diaryController.text = content;
                                    _editingDocId = doc.id;
                                    _selectedDate = (data['date'] as Timestamp).toDate();
                                    _tabController.animateTo(0);
                                  });
                                },
                              ),
                              const SizedBox(width: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text('PDF'),
                                onPressed: () => _handlePdfButton(dateStr, content),
                              ),
                              const SizedBox(width: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                onPressed: () => _confirmDelete(doc.id),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- PAGINATED PDF GENERATION USING SCREENSHOT --- //
  
  List<String> _wrapText(String text, int maxCharsPerLine) {
    List<String> lines = [];
    List<String> paragraphs = text.split('\n');
    for (String paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        lines.add('');
        continue;
      }
      List<String> words = paragraph.split(' ');
      String currentLine = '';
      for (String word in words) {
        if (currentLine.isEmpty) {
          currentLine = word;
        } else if ((currentLine + ' ' + word).length <= maxCharsPerLine) {
          currentLine += ' ' + word;
        } else {
          lines.add(currentLine);
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }
    }
    return lines;
  }

  Future<void> _confirmDelete(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this diary entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('dailyDiary')
            .doc(docId)
            .delete();
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diary entry deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete entry: $e')),
          );
        }
      }
    }
  }

  void _showPdfPreview(String dateStr, List<pw.MemoryImage> images) {
    Future<Uint8List> generatePdfBytes() async {
      final pdf = pw.Document();
      for (var image in images) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image, fit: pw.BoxFit.cover),
              );
            },
          ),
        );
      }
      return pdf.save();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('PDF Preview - $dateStr'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share PDF',
                onPressed: () async {
                  final bytes = await generatePdfBytes();
                  await Printing.sharePdf(bytes: bytes, filename: 'Diary_$dateStr.pdf');
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) => generatePdfBytes(),
            allowPrinting: true,
            allowSharing: false, // Disable default sharing to use our bulletproof appbar action
          ),
        ),
      ),
    );
  }

  Future<void> _handlePdfButton(String dateStr, String content) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final images = await _buildPdfPageImages(dateStr, content);
      
      if (mounted) Navigator.pop(context); // dismiss loader
      
      if (images.isNotEmpty && mounted) {
        _showPdfPreview(dateStr, images);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate PDF pages (Empty images list).')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }
  
  Future<List<pw.MemoryImage>> _buildPdfPageImages(String dateStr, String content) async {
    const isDark = false; 
    final textStyle = _getTextStyle(isDark);
    final lineHeight = _fontSize * 2.2;
    final startY = lineHeight;

    final wrappedLines = _wrapText(content, 48);
    final int linesPerPage = 15;
    
    final totalPages = (wrappedLines.length / linesPerPage).ceil().clamp(1, 9999);
    final List<pw.MemoryImage> pageImages = [];

    for (int i = 0; i < totalPages; i++) {
      final screenshotController = ScreenshotController();
      final isFirstPage = i == 0;
      final int startLine = i * linesPerPage;
      final int endLine = (startLine + linesPerPage).clamp(0, wrappedLines.length);
      final pageText = wrappedLines.sublist(startLine, endLine).join('\n');
      
      final widgetToCapture = Container(
        key: UniqueKey(),
        width: 794,
        height: 1123,
        color: const Color(0xFFF5F5F5), // Grey canvas background like the app
        padding: const EdgeInsets.all(32.0),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
              )
            ],
          ),
          child: Stack(
            children: [
              // Background Image in Writing Area only
              if (_bgImageBase64 != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: _bgOpacity,
                    child: Image.memory(base64Decode(_bgImageBase64!), fit: BoxFit.cover),
                  ),
                ),
              Column(
                children: [
                  if (isFirstPage) ...[
                    // Header margin area only on first page
                    Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    Divider(color: Colors.redAccent.withOpacity(0.5), thickness: 2, height: 2),
                  ],
                  // Writing area
                  Expanded(
                    child: Stack(
                      children: [
                        // Draw background lines all the way to the bottom
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LinedPaperPainter(
                              lineColor: Colors.blue.shade200,
                              lineHeight: lineHeight,
                              startY: startY,
                              showPageBreaks: false,
                            ),
                          ),
                        ),
                        // Text chunk for this page
                        Positioned(
                          top: 0,
                          left: 24.0,
                          right: 24.0,
                          child: Text(
                            pageText,
                            style: textStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      try {
        final bytes = await screenshotController.captureFromWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Material(child: widgetToCapture),
            ),
          ),
          delay: const Duration(milliseconds: 1000), // Increased delay to ensure images/fonts load
          context: context,
        );
        pageImages.add(pw.MemoryImage(bytes));
      } catch (e, stacktrace) {
        debugPrint('Screenshot error page $i: $e\n$stacktrace');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Page $i Render Error: $e')));
        }
      }
    }
    
    return pageImages;
  }

  Future<void> _downloadPDF(int days) async {
    if (_uid == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Paginated PDF... This may take a moment.')));
    
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('dailyDiary')
          .where('dateString', isGreaterThanOrEqualTo: startStr)
          .orderBy('dateString', descending: true)
          .get();
          
      if (snapshot.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entries found in this range.')));
        return;
      }
      
      final pdf = pw.Document();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['dateString'];
        final content = data['content'] ?? '';
        
        if (content.trim().isNotEmpty) {
          final images = await _buildPdfPageImages(dateStr, content);
          for (var image in images) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: pw.EdgeInsets.zero,
                build: (pw.Context context) {
                  return pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  );
                },
              ),
            );
          }
        }
      }
      
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Diary_Last_${days}_Days.pdf');
      
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    }
  }


}

class LinedPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;
  final double startY;
  final bool showPageBreaks;
  final int linesPerPage;
  
  LinedPaperPainter({
    required this.lineColor, 
    required this.lineHeight, 
    required this.startY,
    this.showPageBreaks = true,
    this.linesPerPage = 15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;
      
    int lineCount = 1;
    for (double y = startY; y < size.height; y += lineHeight) {
      if (showPageBreaks && lineCount % linesPerPage == 0) {
        // Draw a page break indicator
        final breakPaint = Paint()
          ..color = Colors.redAccent.withValues(alpha: 0.5)
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), breakPaint);
        
        // Draw "Page X" text
        final textSpan = TextSpan(
          text: 'Page ${(lineCount ~/ linesPerPage) + 1}',
          style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(size.width - textPainter.width - 16, y - textPainter.height - 4));
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      lineCount++;
    }
  }

  @override
  bool shouldRepaint(covariant LinedPaperPainter oldDelegate) {
    return oldDelegate.lineHeight != lineHeight || 
           oldDelegate.startY != startY || 
           oldDelegate.lineColor != lineColor ||
           oldDelegate.showPageBreaks != showPageBreaks;
  }
}
