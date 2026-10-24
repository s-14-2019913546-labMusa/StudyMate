import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_sheet_routine_service.dart';

// ─────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────
class SheetFolder {
  final String id;
  String name;
  String url;
  String icon;
  String color;
  DateTime? lastSynced;
  int? lastSyncCount;

  SheetFolder({
    required this.id,
    required this.name,
    required this.url,
    this.icon = '📚',
    this.color = '#10B981',
    this.lastSynced,
    this.lastSyncCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'icon': icon,
        'color': color,
        'lastSynced': lastSynced?.toIso8601String(),
        'lastSyncCount': lastSyncCount,
      };

  factory SheetFolder.fromJson(Map<String, dynamic> json) => SheetFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String? ?? '',
        icon: json['icon'] as String? ?? '📚',
        color: json['color'] as String? ?? '#10B981',
        lastSynced: json['lastSynced'] != null
            ? DateTime.tryParse(json['lastSynced'] as String)
            : null,
        lastSyncCount: json['lastSyncCount'] as int?,
      );
}

// ─────────────────────────────────────────────
// Persistence
// ─────────────────────────────────────────────
class SheetFolderStorage {
  static const _key = 'studymate_sheet_folders_v2';

  static Future<List<SheetFolder>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SheetFolder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<SheetFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(folders.map((f) => f.toJson()).toList()));
  }
}

// ─────────────────────────────────────────────
// Presets
// ─────────────────────────────────────────────
const _kPresets = [
  {'name': 'BCS Tracker', 'icon': '🎯', 'color': '#3B82F6'},
  {'name': 'Bank Job', 'icon': '🏦', 'color': '#F59E0B'},
  {'name': 'Medical', 'icon': '🩺', 'color': '#EF4444'},
  {'name': 'University', 'icon': '🎓', 'color': '#8B5CF6'},
  {'name': 'Engineering', 'icon': '⚙️', 'color': '#6366F1'},
  {'name': 'Language', 'icon': '🌐', 'color': '#10B981'},
  {'name': 'Daily Routine', 'icon': '📅', 'color': '#F97316'},
  {'name': 'Custom', 'icon': '📂', 'color': '#64748B'},
];

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class MultiSheetManagerScreen extends StatefulWidget {
  const MultiSheetManagerScreen({super.key});

  @override
  State<MultiSheetManagerScreen> createState() =>
      _MultiSheetManagerScreenState();
}

class _MultiSheetManagerScreenState extends State<MultiSheetManagerScreen> {
  List<SheetFolder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await SheetFolderStorage.loadAll();
    if (mounted) setState(() { _folders = folders; _isLoading = false; });
  }

  Future<void> _saveFolders() => SheetFolderStorage.saveAll(_folders);

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  void _openAddSheet({SheetFolder? preset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFolderSheet(
        existing: preset,
        onSave: (folder) async {
          final idx = _folders.indexWhere((f) => f.id == folder.id);
          if (idx >= 0) {
            setState(() => _folders[idx] = folder);
          } else {
            setState(() => _folders.add(folder));
          }
          await _saveFolders();
        },
      ),
    );
  }

  void _editFolder(int i) => _openAddSheet(preset: _folders[i]);

  void _deleteFolder(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Folder?'),
        content: Text('Remove "${_folders[i].name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _folders.removeAt(i));
      await _saveFolders();
    }
  }

  void _openFolder(SheetFolder folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SheetFolderDetailScreen(
          folder: folder,
          onSyncComplete: (count) async {
            setState(() {
              folder.lastSynced = DateTime.now();
              folder.lastSyncCount = count;
            });
            await _saveFolders();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Study Sheets',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: _showHelp),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(),
        icon: const Icon(Icons.add_rounded),
        label:
            const Text('Add Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? _buildEmpty(isDark)
              : _buildGrid(isDark),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.table_chart_rounded,
                  size: 72, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 28),
            Text('No Sheet Folders Yet',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Text(
              'Link your Google Sheets — BCS, Bank, Medical, or anything!\nEach sheet gets its own folder.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                  height: 1.6),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _kPresets.take(6).map((p) {
                final color = _parseColor(p['color']!);
                return GestureDetector(
                  onTap: () => _openAddSheet(
                    preset: SheetFolder(
                      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
                      name: p['name']!,
                      icon: p['icon']!,
                      color: p['color']!,
                      url: '',
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p['icon']!,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(p['name']!,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(bool isDark) {
    return Column(
      children: [
        // Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_special_rounded,
                    color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_folders.length} Sheet Folder${_folders.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text('Tap a folder to sync & view',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemCount: _folders.length,
            itemBuilder: (ctx, i) => _FolderCard(
              folder: _folders[i],
              onTap: () => _openFolder(_folders[i]),
              onEdit: () => _editFolder(i),
              onDelete: () => _deleteFolder(i),
              parseColor: _parseColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.help_outline_rounded, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('How it works'),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpStep(step: '1', text: 'Open Google Sheets and create your study plan (BCS, Bank, etc.)'),
            _HelpStep(step: '2', text: 'Click "Share" → "Anyone with the link can view"'),
            _HelpStep(step: '3', text: 'Tap "+ Add Sheet" here and paste the link'),
            _HelpStep(step: '4', text: 'Name it "BCS Tracker" or "Bank Job" etc.'),
            _HelpStep(step: '5', text: 'Tap the folder → "Fetch & Preview" → "Sync to Routine"'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Folder Card
// ─────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final SheetFolder folder;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color Function(String) parseColor;

  const _FolderCard({
    required this.folder,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = parseColor(folder.color);
    final hasUrl = folder.url.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(folder.icon,
                            style: const TextStyle(fontSize: 28)),
                        const Spacer(),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') onEdit();
                            if (v == 'delete') onDelete();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit')
                                ])),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red))
                                ])),
                          ],
                          child: Icon(Icons.more_vert_rounded,
                              size: 20,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      folder.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (folder.lastSynced != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✓ ${folder.lastSyncCount ?? 0} synced',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasUrl
                            ? color.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasUrl ? '🔗 Sheet linked' : '⚠️ No link',
                        style: TextStyle(
                            fontSize: 10,
                            color: hasUrl ? color : Colors.orange,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Add / Edit Sheet Bottom Sheet
// ─────────────────────────────────────────────
class _AddFolderSheet extends StatefulWidget {
  final SheetFolder? existing;
  final Future<void> Function(SheetFolder) onSave;
  const _AddFolderSheet({this.existing, required this.onSave});

  @override
  State<_AddFolderSheet> createState() => _AddFolderSheetState();
}

class _AddFolderSheetState extends State<_AddFolderSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;
  String _icon = '📚';
  String _color = '#10B981';
  bool _saving = false;

  static const _icons = [
    '📚','🎯','🏦','🩺','🎓','⚙️','🌐','📅','📊','🔬','📝','💡','🏆','📐','🧪',
  ];
  static const _colors = [
    '#10B981','#3B82F6','#F59E0B','#EF4444',
    '#8B5CF6','#6366F1','#F97316','#64748B',
    '#EC4899','#14B8A6','#84CC16','#06B6D4',
  ];

  Color _parse(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _urlCtrl = TextEditingController(text: widget.existing?.url ?? '');
    _icon = widget.existing?.icon ?? '📚';
    _color = widget.existing?.color ?? '#10B981';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _urlCtrl.text = d!.text!.trim());
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a folder name')));
      return;
    }
    setState(() => _saving = true);
    final folder = SheetFolder(
      id: widget.existing?.id ??
          'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      icon: _icon,
      color: _color,
      lastSynced: widget.existing?.lastSynced,
      lastSyncCount: widget.existing?.lastSyncCount,
    );
    await widget.onSave(folder);
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _parse(_color);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(children: [
              Text(_icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text(
                widget.existing == null ? 'New Sheet Folder' : 'Edit Folder',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isDark ? Colors.white : Colors.black87),
              ),
            ]),
            const SizedBox(height: 20),

            // Presets row (only for new)
            if (widget.existing == null ||
                widget.existing!.url.isEmpty) ...[
              Text('Quick Presets',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _kPresets.map((p) {
                    final c = _parse(p['color']!);
                    return GestureDetector(
                      onTap: () => setState(() {
                        _nameCtrl.text = p['name']!;
                        _icon = p['icon']!;
                        _color = p['color']!;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: c.withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          Text(p['icon']!,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(p['name']!,
                              style: TextStyle(
                                  color: c,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Name
            _label('Folder Name', isDark),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. BCS Tracker, Bank Job...',
                prefixText: '$_icon  ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                filled: true,
              ),
            ),
            const SizedBox(height: 18),

            // URL
            _label('Google Sheet Link', isDark),
            const SizedBox(height: 6),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                prefixIcon: const Icon(Icons.table_chart_rounded,
                    color: Color(0xFF10B981)),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: _paste,
                    tooltip: 'Paste'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                filled: true,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Share the sheet as "Anyone with the link can view"',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white30 : Colors.black38),
            ),
            const SizedBox(height: 18),

            // Icon picker
            _label('Icon', isDark),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _icons.map((ic) {
                  final sel = _icon == ic;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = ic),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: sel
                            ? accent.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? accent : Colors.transparent,
                            width: 2),
                      ),
                      child: Center(
                          child: Text(ic,
                              style: const TextStyle(fontSize: 22))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Color picker
            _label('Color', isDark),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _colors.map((hex) {
                  final c = _parse(hex);
                  final sel = _color == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel ? Colors.white : Colors.transparent,
                            width: 2.5),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: c.withValues(alpha: 0.55),
                                    blurRadius: 8,
                                    spreadRadius: 2)
                              ]
                            : [],
                      ),
                      child: sel
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Save
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Folder',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isDark ? Colors.white60 : Colors.black54));
}

// ─────────────────────────────────────────────
// Detail / Sync Screen (public so dashboard can route to it)
// ─────────────────────────────────────────────
class SheetFolderDetailScreen extends StatefulWidget {
  final SheetFolder folder;
  final Future<void> Function(int count) onSyncComplete;

  const SheetFolderDetailScreen(
      {super.key, required this.folder, required this.onSyncComplete});

  @override
  State<SheetFolderDetailScreen> createState() =>
      _SheetFolderDetailScreenState();
}

class _SheetFolderDetailScreenState
    extends State<SheetFolderDetailScreen> {
  late TextEditingController _urlCtrl;
  bool _loading = false;
  bool _replace = false;
  List<Map<String, String>> _preview = [];
  String? _msg;
  bool _ok = false;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.folder.url);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _urlCtrl.text = d!.text!.trim());
  }

  Future<void> _fetch() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paste your Google Sheet link first')));
      return;
    }
    setState(() { _loading = true; _msg = null; _preview = []; });
    try {
      widget.folder.url = url;
      // persist url update
      final all = await SheetFolderStorage.loadAll();
      final idx = all.indexWhere((f) => f.id == widget.folder.id);
      if (idx >= 0) all[idx] = widget.folder;
      await SheetFolderStorage.saveAll(all);

      final csv = await GoogleSheetRoutineService.fetchCsvContent(url);
      final rows = GoogleSheetRoutineService.parseCsvToRows(csv);
      if (rows.isEmpty) throw Exception('No valid routine data found.');
      setState(() {
        _preview = rows;
        _msg = 'Found ${rows.length} tasks in "${widget.folder.name}"!';
        _ok = true;
      });
    } catch (e) {
      setState(() {
        _msg = e.toString().replaceAll('Exception: ', '');
        _ok = false;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    if (_preview.isEmpty) return;
    setState(() => _loading = true);
    try {
      final count = await GoogleSheetRoutineService.syncRowsToFirestore(
          rows: _preview, replaceExisting: _replace);
      await widget.onSyncComplete(count);
      setState(() {
        _msg = '🎉 Synced $count tasks from "${widget.folder.name}" to Daily Routine!';
        _ok = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('✓ $count tasks added to Daily Routine!'),
          action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.pop(context, true)),
        ));
      }
    } catch (e) {
      setState(() { _msg = e.toString().replaceAll('Exception: ', ''); _ok = false; });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final accent = _parseColor(widget.folder.color);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(children: [
          Text(widget.folder.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(widget.folder.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: Text(widget.folder.icon,
                      style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.folder.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                      Text(
                        widget.folder.lastSynced != null
                            ? 'Last synced: ${_relTime(widget.folder.lastSynced!)} · ${widget.folder.lastSyncCount ?? 0} tasks'
                            : 'Not synced yet',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            // URL
            Text('Google Sheet Link',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                prefixIcon:
                    Icon(Icons.table_chart_rounded, color: accent),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: _paste),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                filled: true,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '📋 Paste your "${widget.folder.name}" Google Sheet link',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 14),

            // Replace toggle
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                value: _replace,
                onChanged: (v) => setState(() => _replace = v),
                title: const Text('Replace existing tasks',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text(
                    _replace
                        ? 'Replaces tasks for matching dates'
                        : 'Merges with existing tasks',
                    style: const TextStyle(fontSize: 12)),
                activeColor: accent,
                secondary: Icon(
                    _replace
                        ? Icons.restart_alt_rounded
                        : Icons.call_merge_rounded,
                    color: accent),
              ),
            ),
            const SizedBox(height: 18),

            // Fetch Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_download_rounded),
                label: Text(_loading ? 'Fetching...' : 'Fetch & Preview',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _loading ? null : _fetch,
              ),
            ),

            if (_msg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _ok
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _ok ? Colors.green : Colors.red),
                ),
                child: Row(children: [
                  Icon(
                      _ok
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _ok ? Colors.green : Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_msg!,
                          style: TextStyle(
                              color: _ok
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.w600))),
                ]),
              ),
            ],

            // Preview
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Preview (${_preview.length} tasks)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Import All'),
                    style: TextButton.styleFrom(foregroundColor: accent),
                    onPressed: _loading ? null : _sync,
                  ),
                ],
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _preview.length,
                itemBuilder: (ctx, i) {
                  final row = _preview[i];
                  final subj = row['subject'] ?? '';
                  final topic = row['topic'] ?? '';
                  final date = row['date'] ?? 'Today';
                  final start = row['start_time'] ?? '';
                  final end = row['end_time'] ?? '';
                  final done = row['status']?.contains('সম্পন্ন') == true ||
                      row['status'] == 'completed';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            accent.withValues(alpha: 0.15),
                        child: done
                            ? Icon(Icons.check, color: accent, size: 18)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                      ),
                      title: Text(
                          subj.isNotEmpty ? subj : topic,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                          '$date${start.isNotEmpty ? '  •  $start–$end' : ''}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: done
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('সম্পন্ন',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            )
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync_rounded),
                  label: Text('Sync ${_preview.length} Tasks to Routine',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _loading ? null : _sync,
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _relTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ─────────────────────────────────────────────
// Help Step Widget
// ─────────────────────────────────────────────
class _HelpStep extends StatelessWidget {
  final String step;
  final String text;
  const _HelpStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: Color(0xFF6366F1), shape: BoxShape.circle),
            child: Center(
                child: Text(step,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
