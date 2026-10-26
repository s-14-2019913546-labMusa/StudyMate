import 'package:flutter/material.dart';
import 'daily_routine.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'google_sheet_syllabus_service.dart';

class SharedTaskForm extends StatefulWidget {
  final Function(Task) onSubmit;
  final List<String> categories;
  final String submitButtonText;
  final String? initialSubject;
  final String? initialTopic;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final String? initialCategory;
  final String? initialNotes;
  final bool allowPast;
  final DateTime? targetDate;

  const SharedTaskForm({
    super.key,
    required this.onSubmit,
    required this.categories,
    this.submitButtonText = 'Save',
    this.initialSubject,
    this.initialTopic,
    this.initialStartTime,
    this.initialEndTime,
    this.initialCategory,
    this.initialNotes,
    this.allowPast = false,
    this.targetDate,
  });

  @override
  State<SharedTaskForm> createState() => _SharedTaskFormState();
}

class _SharedTaskFormState extends State<SharedTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _sheetUrlController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isPrivate = false;
  String _selectedCategory = 'Study';
  String _selectedSubCategory = 'None';
  String? _timeError;
  List<String> _studyFolders = [];

  // Google Sheet Syllabus Hierarchical Mode
  int _entryMode = 0; // 0: Manual, 1: From Google Sheet
  Map<String, Map<String, List<String>>> _syllabusTree = {};
  String? _selectedSheetSubject;
  String? _selectedSheetChapter;
  final Set<String> _selectedSheetTopics = {};
  bool _isLoadingSyllabus = false;
  bool _showSheetUrlInput = false;
  String? _savedSheetUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null && widget.initialSubject!.isNotEmpty) {
      _subjectController.text = widget.initialSubject!;
    }
    if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
      _topicController.text = widget.initialTopic!;
    }
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _notesController.text = widget.initialNotes!;
    }
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      final rawCat = widget.initialCategory!.trim();
      if (widget.categories.contains(rawCat)) {
        _selectedCategory = rawCat;
        _selectedSubCategory = 'None';
      } else {
        _selectedCategory = 'Study';
        final lower = rawCat.toLowerCase();
        if (lower.contains('bcs') || lower.contains('বিসিএস')) {
          _selectedSubCategory = 'BCS Preparation (বিসিএস)';
        } else if (lower.contains('bank') || lower.contains('ব্যাংক')) {
          _selectedSubCategory = 'Bank Job (জব উইথ মানিক)';
        } else if (lower.contains('primary') || lower.contains('govt') || lower.contains('প্রাইমারি')) {
          _selectedSubCategory = 'Primary / Govt Job';
        } else {
          _selectedSubCategory = rawCat;
        }
      }
    }
    _loadCustomFolders();
    _loadSyllabusData();
  }

  Future<void> _loadSyllabusData() async {
    final tree = await GoogleSheetSyllabusService.loadSyllabusTree();
    final savedUrl = await GoogleSheetSyllabusService.getSavedSyllabusUrl();
    if (mounted) {
      setState(() {
        _syllabusTree = tree;
        _savedSheetUrl = savedUrl;
        if (savedUrl != null) {
          _sheetUrlController.text = savedUrl;
        }
      });
    }
  }

  Future<void> _refreshSyllabusFromSheet() async {
    final url = _sheetUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoadingSyllabus = true);
    try {
      final updatedTree = await GoogleSheetSyllabusService.fetchAndCacheSyllabus(url);
      if (mounted) {
        setState(() {
          _syllabusTree = updatedTree;
          _savedSheetUrl = url;
          _showSheetUrlInput = false;
          _selectedSheetSubject = null;
          _selectedSheetChapter = null;
          _selectedSheetTopics.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Syllabus updated successfully from Google Sheet!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sheet: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSyllabus = false);
    }
  }

  Future<void> _loadCustomFolders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('studyFolders')
          .get();
      final folderNames = snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      if (mounted && folderNames.isNotEmpty) {
        setState(() {
          _studyFolders = folderNames;
        });
      }
    } catch (e) {
      debugPrint("Error loading study folders: $e");
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _handleSubmit() {
    setState(() => _timeError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startTime == null || _endTime == null) {
      setState(() => _timeError = 'Please select both start and end times.');
      return;
    }
    final now = DateTime.now();
    final baseDate = widget.targetDate ?? now;
    final start = DateTime(baseDate.year, baseDate.month, baseDate.day, _startTime!.hour, _startTime!.minute);
    var end = DateTime(baseDate.year, baseDate.month, baseDate.day, _endTime!.hour, _endTime!.minute);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    if (!widget.allowPast) {
      final bufferTime = now.subtract(const Duration(minutes: 1));
      if (start.isBefore(bufferTime)) {
        setState(() => _timeError = 'Start time cannot be in the past!');
        return;
      }
      if (end.isBefore(bufferTime)) {
        setState(() => _timeError = 'End time cannot be in the past!');
        return;
      }
    }
    final durationMinutes = end.difference(start).inMinutes;
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _subjectController.text.trim(),
      subject: _subjectController.text.trim(),
      topic: _topicController.text.trim(),
      challenges: _challengesController.text.trim(),
      notes: _notesController.text.trim(),
      startTime: start,
      endTime: end,
      isPrivate: _isPrivate,
      category: (_selectedCategory == 'Study' && _selectedSubCategory != 'None') ? _selectedSubCategory : _selectedCategory,
      totalDurationMinutes: durationMinutes,
    );
    widget.onSubmit(newTask);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _challengesController.dispose();
    _notesController.dispose();
    _sheetUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> availableChapters = (_selectedSheetSubject != null && _syllabusTree.containsKey(_selectedSheetSubject))
        ? _syllabusTree[_selectedSheetSubject]!.keys.toList()
        : [];

    final List<String> availableTopics = (_selectedSheetSubject != null &&
            _selectedSheetChapter != null &&
            _syllabusTree.containsKey(_selectedSheetSubject) &&
            _syllabusTree[_selectedSheetSubject]!.containsKey(_selectedSheetChapter))
        ? _syllabusTree[_selectedSheetSubject]![_selectedSheetChapter]!
        : [];

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Switch: Manual vs Google Sheet
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _entryMode = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _entryMode == 0 ? colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _entryMode == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: _entryMode == 0 ? Colors.white : onSurfaceColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ম্যানুয়াল টাস্ক',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _entryMode == 0 ? Colors.white : onSurfaceColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _entryMode = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _entryMode == 1 ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _entryMode == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.table_chart_rounded,
                              size: 18,
                              color: _entryMode == 1 ? Colors.white : onSurfaceColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'গুগল শিট থেকে',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _entryMode == 1 ? Colors.white : onSurfaceColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Google Sheet Mode Banner & Controls
            if (_entryMode == 1) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _savedSheetUrl != null
                                ? 'গুগল শিটের সিলেবাস সক্রিয় রয়েছে'
                                : 'গুগল শিট লিঙ্ক যুক্ত করুন',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showSheetUrlInput ? Icons.close : Icons.link_rounded,
                            size: 20,
                            color: const Color(0xFF10B981),
                          ),
                          tooltip: 'Change Sheet Link',
                          onPressed: () => setState(() => _showSheetUrlInput = !_showSheetUrlInput),
                        ),
                      ],
                    ),
                    if (_showSheetUrlInput) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sheetUrlController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Paste Google Sheet Link...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoadingSyllabus ? null : _refreshSyllabusFromSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: _isLoadingSyllabus
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sync', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Step 1: Subject Dropdown from Sheet
              Text('Subject Name (বিষয় নির্বাচন)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedSheetSubject,
                hint: const Text('বিষয় সিলেক্ট করুন...'),
                items: _syllabusTree.keys.map((sub) => DropdownMenuItem(
                  value: sub,
                  child: Text(sub, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSheetSubject = val;
                    _selectedSheetChapter = null;
                    _selectedSheetTopics.clear();
                    _subjectController.text = val ?? '';
                    _topicController.text = '';
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
                ),
                validator: (v) => v == null || v.isEmpty ? 'একটি বিষয় নির্বাচন করুন' : null,
              ),

              // Step 2: Chapter / Era / Section Dropdown
              if (_selectedSheetSubject != null && availableChapters.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Chapter / Era (অধ্যায় বা যুগ)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSheetChapter,
                  hint: const Text('অধ্যায় বা যুগ সিলেক্ট করুন...'),
                  items: availableChapters.map((ch) => DropdownMenuItem(
                    value: ch,
                    child: Text(ch, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSheetChapter = val;
                      _selectedSheetTopics.clear();
                      _topicController.text = '';
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.layers_rounded, color: Colors.blue),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                  ),
                ),
              ],

              // Step 3: Micro-Topics Multi-Select Chips
              if (_selectedSheetChapter != null && availableTopics.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Topics (টপিক সিলেক্ট করুন — একাধিক নির্বাচনযোগ্য)'.tr(),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: onSurfaceColor)),
                    if (_selectedSheetTopics.isNotEmpty)
                      Text(
                        '${_selectedSheetTopics.length} selected',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: onSurfaceColor.withValues(alpha: 0.15)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTopics.map((topic) {
                      final isSelected = _selectedSheetTopics.contains(topic);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(topic, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : onSurfaceColor)),
                        selectedColor: const Color(0xFF10B981),
                        checkmarkColor: Colors.white,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedSheetTopics.add(topic);
                            } else {
                              _selectedSheetTopics.remove(topic);
                            }
                            _topicController.text = _selectedSheetTopics.join(', ');
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ] else ...[
              // Standard Manual Subject
              Text('Subject Name (বিষয়)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                style: TextStyle(color: onSurfaceColor),
                decoration: InputDecoration(
                  hintText: 'Enter Subject Name'.tr(),
                  hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.subject, color: colorScheme.primary),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter subject name'.tr() : null,
              ),
              const SizedBox(height: 16),
            ],

            // Topic Name (Either auto-filled from sheet chips or manually typed)
            Text('Topic Name (বিষয়বস্তু)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _topicController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: _entryMode == 1 ? 'Selected topics appear here...' : 'Enter Topic Name'.tr(),
                hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.title_rounded, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),

            // Challenges
            Text('Possible Challenges (সম্ভাব্য সমস্যা)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _challengesController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: 'Describe potential issues or difficulties...'.tr(),
                hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.warning_amber_rounded, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),

            // Notes / Goal
            Text('Task Goal / Notes (লক্ষ্য ও নোট)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: 'Enter notes or specific goals...'.tr(),
                hintStyle: TextStyle(color: onSurfaceColor.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.notes, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),

            // Category (Work, Sports, Study, Other)
            Text('Category'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final catItems = {
                ...widget.categories,
                _selectedCategory,
              }.toList();

              return DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: catItems.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: onSurfaceColor)))).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedCategory = v ?? _selectedCategory;
                    if (_selectedCategory != 'Study') {
                      _selectedSubCategory = 'None';
                    }
                  });
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Job Category (Renamed from Sub-category when Study is chosen)
            if (_selectedCategory == 'Study') ...[
              Text('Job Category (জব ক্যাটাগরি / ফোল্ডার)'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final subCatItems = {
                  'None',
                  'BCS Preparation (বিসিএস)',
                  'Bank Job (জব উইথ মানিক)',
                  'Primary / Govt Job',
                  ..._studyFolders,
                  _selectedSubCategory,
                }.toList();

                return DropdownButtonFormField<String>(
                  initialValue: _selectedSubCategory,
                  items: subCatItems.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: onSurfaceColor)))).toList(),
                  onChanged: (v) => setState(() => _selectedSubCategory = v ?? 'None'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.work_outline_rounded, color: Colors.orange),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            // Private toggle
            Row(
              children: [
                Checkbox(value: _isPrivate, onChanged: (v) => setState(() => _isPrivate = v ?? false)),
                Text('Private Task'.tr()),
              ],
            ),
            const SizedBox(height: 16),
            // Time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(true),
                    icon: Icon(
                      Icons.access_time_rounded,
                      color: _startTime != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    label: Text(
                      _startTime == null ? 'Start Time'.tr() : _startTime!.format(context),
                      style: TextStyle(
                        color: _startTime != null ? colorScheme.primary : onSurfaceColor,
                        fontWeight: _startTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _startTime != null
                            ? colorScheme.primary
                            : onSurfaceColor.withValues(alpha: 0.3),
                        width: _startTime != null ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(false),
                    icon: Icon(
                      Icons.access_time_rounded,
                      color: _endTime != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    label: Text(
                      _endTime == null ? 'End Time'.tr() : _endTime!.format(context),
                      style: TextStyle(
                        color: _endTime != null ? colorScheme.primary : onSurfaceColor,
                        fontWeight: _endTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _endTime != null
                            ? colorScheme.primary
                            : onSurfaceColor.withValues(alpha: 0.3),
                        width: _endTime != null ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Inline error display
            if (_timeError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(_timeError!, style: const TextStyle(color: Colors.red)),
              ),
            // Save button
            ElevatedButton(
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(widget.submitButtonText.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
