import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// =============================================
// DATA MODELS
// =============================================

class CountdownFolder {
  final String id;
  final String name;
  final String iconCodePoint;
  final String colorHex;
  final DateTime createdAt;

  CountdownFolder({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    required this.createdAt,
  });

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  IconData get icon {
    try {
      final cp = int.parse(iconCodePoint);
      return IconData(cp, fontFamily: 'MaterialIcons');
    } catch (_) {
      return Icons.folder_rounded;
    }
  }

  factory CountdownFolder.fromMap(Map<String, dynamic> map, String id) {
    return CountdownFolder(
      id: id,
      name: map['name'] ?? '',
      iconCodePoint: map['iconCodePoint'] ?? Icons.folder_rounded.codePoint.toString(),
      colorHex: map['colorHex'] ?? '#6366F1',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorHex': colorHex,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class CountdownEntry {
  final String id;
  final String title;
  final String organization;
  final DateTime deadlineDate;
  final DateTime? examDate;
  final String status; // 'not_applied', 'applied', 'missed'
  final String link;
  final String secretNote; // গুরুত্বপূর্ণ পাসওয়ার্ড ও আইডি নম্বরের জন্য
  final bool isPinned;
  final DateTime createdAt;

  CountdownEntry({
    required this.id,
    required this.title,
    required this.organization,
    required this.deadlineDate,
    this.examDate,
    this.status = 'not_applied',
    this.link = '',
    this.secretNote = '',
    this.isPinned = false,
    required this.createdAt,
  });

  int get daysUntilDeadline => deadlineDate.difference(DateTime.now()).inDays;
  bool get isExpired => deadlineDate.isBefore(DateTime.now());

  Color getCountdownColor(BuildContext context) {
    if (status == 'applied') return Colors.green;
    if (isExpired) return Colors.grey;
    if (daysUntilDeadline <= 2) return Colors.red;
    if (daysUntilDeadline <= 7) return Colors.orange;
    return Colors.green.shade600;
  }

  factory CountdownEntry.fromMap(Map<String, dynamic> map, String id) {
    return CountdownEntry(
      id: id,
      title: map['title'] ?? '',
      organization: map['organization'] ?? '',
      deadlineDate: (map['deadlineDate'] as Timestamp).toDate(),
      examDate: map['examDate'] != null ? (map['examDate'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'not_applied',
      link: map['link'] ?? '',
      secretNote: map['secretNote'] ?? '',
      isPinned: map['isPinned'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'organization': organization,
        'deadlineDate': Timestamp.fromDate(deadlineDate),
        'examDate': examDate != null ? Timestamp.fromDate(examDate!) : null,
        'status': status,
        'link': link,
        'secretNote': secretNote,
        'isPinned': isPinned,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// =============================================
// MAIN SCREEN — Folder List
// =============================================

class SpecialDayCountdownScreen extends StatefulWidget {
  const SpecialDayCountdownScreen({super.key});

  @override
  State<SpecialDayCountdownScreen> createState() => _SpecialDayCountdownScreenState();
}

class _SpecialDayCountdownScreenState extends State<SpecialDayCountdownScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CollectionReference get _foldersRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_user!.uid)
      .collection('countdownFolders');

  // ফোল্ডার তৈরি করার ডায়ালগ
  Future<void> _showAddFolderDialog({CountdownFolder? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String selectedColor = existing?.colorHex ?? '#6366F1';
    String selectedIcon = existing?.iconCodePoint ?? Icons.folder_rounded.codePoint.toString();

    final List<Map<String, dynamic>> colorOptions = [
      {'hex': '#6366F1', 'color': const Color(0xFF6366F1)},
      {'hex': '#EF4444', 'color': const Color(0xFFEF4444)},
      {'hex': '#10B981', 'color': const Color(0xFF10B981)},
      {'hex': '#F59E0B', 'color': const Color(0xFFF59E0B)},
      {'hex': '#3B82F6', 'color': const Color(0xFF3B82F6)},
      {'hex': '#EC4899', 'color': const Color(0xFFEC4899)},
      {'hex': '#8B5CF6', 'color': const Color(0xFF8B5CF6)},
      {'hex': '#14B8A6', 'color': const Color(0xFF14B8A6)},
    ];

    final List<Map<String, dynamic>> iconOptions = [
      {'code': Icons.folder_rounded.codePoint.toString(), 'icon': Icons.folder_rounded},
      {'code': Icons.work_rounded.codePoint.toString(), 'icon': Icons.work_rounded},
      {'code': Icons.school_rounded.codePoint.toString(), 'icon': Icons.school_rounded},
      {'code': Icons.star_rounded.codePoint.toString(), 'icon': Icons.star_rounded},
      {'code': Icons.business_center_rounded.codePoint.toString(), 'icon': Icons.business_center_rounded},
      {'code': Icons.public_rounded.codePoint.toString(), 'icon': Icons.public_rounded},
      {'code': Icons.local_hospital_rounded.codePoint.toString(), 'icon': Icons.local_hospital_rounded},
      {'code': Icons.account_balance_rounded.codePoint.toString(), 'icon': Icons.account_balance_rounded},
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'নতুন ফোল্ডার তৈরি করুন' : 'ফোল্ডার সম্পাদনা করুন',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ফোল্ডারের নাম',
                      hintText: 'যেমন: সরকারি চাকরি, Scholarship...',
                      prefixIcon: const Icon(Icons.folder_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text('রঙ বাছুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: colorOptions.map((c) {
                      final isSelected = selectedColor == c['hex'];
                      return GestureDetector(
                        onTap: () => setLocalState(() => selectedColor = c['hex']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c['color'],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('আইকন বাছুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: iconOptions.map((ic) {
                      final isSelected = selectedIcon == ic['code'];
                      final selColor = Color(int.parse(selectedColor.replaceFirst('#', '0xFF')));
                      return GestureDetector(
                        onTap: () => setLocalState(() => selectedIcon = ic['code']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? selColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? selColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(ic['icon'], color: isSelected ? selColor : Colors.grey, size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('বাতিল'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (nameController.text.trim().isNotEmpty) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(int.parse(selectedColor.replaceFirst('#', '0xFF'))),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(existing == null ? 'তৈরি করুন' : 'সেভ করুন'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      final folder = CountdownFolder(
        id: existing?.id ?? '',
        name: nameController.text.trim(),
        iconCodePoint: selectedIcon,
        colorHex: selectedColor,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      if (existing == null) {
        await _foldersRef.add(folder.toMap());
      } else {
        await _foldersRef.doc(existing.id).update(folder.toMap());
      }
    }
  }

  Future<void> _deleteFolder(CountdownFolder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ফোল্ডার মুছুন', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('"${folder.name}" ফোল্ডার এবং এর সকল এন্ট্রি মুছে যাবে। নিশ্চিত?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Delete all entries first
      final entries = await _foldersRef.doc(folder.id).collection('entries').get();
      for (var doc in entries.docs) {
        await doc.reference.delete();
      }
      await _foldersRef.doc(folder.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('লগইন প্রয়োজন')));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Special Day Countdown',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ডেডলাইন ট্র্যাক করুন, সুযোগ মিস করবেন না',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'এন্ট্রি সার্চ করুন (নাম, প্রতিষ্ঠান, নোট)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : _buildFolderList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFolderDialog,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('নতুন ফোল্ডার', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
    );
  }

  // সার্চ রেজাল্ট (সব ফোল্ডারের সব এন্ট্রি সার্চ করবে)
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _foldersRef.snapshots(),
      builder: (ctx, folderSnap) {
        if (!folderSnap.hasData) return const Center(child: CircularProgressIndicator());
        final folders = folderSnap.data!.docs
            .map((d) => CountdownFolder.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: folders.length,
          itemBuilder: (ctx, fi) {
            final folder = folders[fi];
            return StreamBuilder<QuerySnapshot>(
              stream: _foldersRef.doc(folder.id).collection('entries').snapshots(),
              builder: (ctx, entrySnap) {
                if (!entrySnap.hasData) return const SizedBox.shrink();
                final matched = entrySnap.data!.docs
                    .map((d) => CountdownEntry.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .where((e) =>
                        e.title.toLowerCase().contains(_searchQuery) ||
                        e.organization.toLowerCase().contains(_searchQuery) ||
                        e.secretNote.toLowerCase().contains(_searchQuery) ||
                        e.link.toLowerCase().contains(_searchQuery))
                    .toList();

                if (matched.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        children: [
                          Icon(folder.icon, color: folder.color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            folder.name,
                            style: TextStyle(
                              color: folder.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...matched.map((entry) => _buildEntryCard(entry, folder, folder.id)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFolderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _foldersRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final folders = snap.data!.docs
            .map((d) => CountdownFolder.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: folders.length,
          itemBuilder: (ctx, i) => _buildFolderCard(folders[i]),
        );
      },
    );
  }

  Widget _buildFolderCard(CountdownFolder folder) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CountdownFolderDetailScreen(folder: folder),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: folder.color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: folder.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: folder.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(folder.icon, color: folder.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    _buildFolderEntrySummary(folder),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'edit') _showAddFolderDialog(existing: folder);
                  if (val == 'delete') _deleteFolder(folder);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('সম্পাদনা করুন')]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('মুছুন', style: TextStyle(color: Colors.red))]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderEntrySummary(CountdownFolder folder) {
    return StreamBuilder<QuerySnapshot>(
      stream: _foldersRef.doc(folder.id).collection('entries').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Text('লোড হচ্ছে...', style: TextStyle(fontSize: 12));
        final entries = snap.data!.docs
            .map((d) => CountdownEntry.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();
        final active = entries.where((e) => !e.isExpired && e.status != 'applied').length;
        final applied = entries.where((e) => e.status == 'applied').length;
        return Text(
          '${entries.length} এন্ট্রি  •  $applied টি আবেদন করা  •  $active টি সক্রিয়',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        );
      },
    );
  }

  Widget _buildEntryCard(CountdownEntry entry, CountdownFolder folder, String folderId) {
    return GestureDetector(
      onTap: () => _showEntryPreview(entry, folder, folderId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: folder.color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            _buildStatusDot(entry, folder),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(entry.organization, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            _buildCountdownBadge(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot(CountdownEntry entry, CountdownFolder folder) {
    Color c;
    IconData ico;
    if (entry.status == 'applied') { c = Colors.green; ico = Icons.check_circle_rounded; }
    else if (entry.isExpired) { c = Colors.grey; ico = Icons.cancel_rounded; }
    else { c = folder.color; ico = Icons.schedule_rounded; }
    return Icon(ico, color: c, size: 22);
  }

  Widget _buildCountdownBadge(CountdownEntry entry) {
    if (entry.status == 'applied') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: const Text('Applied ✓', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    if (entry.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: const Text('Expired', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    final days = entry.daysUntilDeadline;
    Color bg;
    if (days <= 2) {
      bg = Colors.red;
    } else if (days <= 7) {
      bg = Colors.orange;
    } else {
      bg = Colors.green.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('$days দিন', style: TextStyle(color: bg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // এন্ট্রি প্রিভিউ মডাল
  void _showEntryPreview(CountdownEntry entry, CountdownFolder folder, String folderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryPreviewSheet(
        entry: entry,
        folder: folder,
        folderId: folderId,
        foldersRef: _foldersRef,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.create_new_folder_rounded, size: 48, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          const Text('কোনো ফোল্ডার নেই', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'নিচের বাটনে ক্লিক করে\nনতুন ফোল্ডার তৈরি করুন',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// =============================================
// FOLDER DETAIL SCREEN — Entry List
// =============================================

class CountdownFolderDetailScreen extends StatefulWidget {
  final CountdownFolder folder;
  const CountdownFolderDetailScreen({super.key, required this.folder});

  @override
  State<CountdownFolderDetailScreen> createState() => _CountdownFolderDetailScreenState();
}

class _CountdownFolderDetailScreenState extends State<CountdownFolderDetailScreen>
    with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CollectionReference get _entriesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_user!.uid)
      .collection('countdownFolders')
      .doc(widget.folder.id)
      .collection('entries');

  CollectionReference get _foldersRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_user!.uid)
      .collection('countdownFolders');

  // নতুন এন্ট্রি যোগ বা সম্পাদনা
  Future<void> _showAddEntryDialog({CountdownEntry? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final orgCtrl = TextEditingController(text: existing?.organization ?? '');
    final linkCtrl = TextEditingController(text: existing?.link ?? '');
    final secretCtrl = TextEditingController(text: existing?.secretNote ?? '');
    DateTime selectedDeadline = existing?.deadlineDate ?? DateTime.now().add(const Duration(days: 7));
    DateTime? selectedExamDate = existing?.examDate;
    String selectedStatus = existing?.status ?? 'not_applied';
    bool isPinned = existing?.isPinned ?? false;

    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final colorScheme = Theme.of(ctx).colorScheme;
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              existing == null ? 'নতুন এন্ট্রি যোগ করুন' : 'এন্ট্রি সম্পাদনা করুন',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx, false),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Title
                        _buildFieldLabel('চাকরি / প্রোগ্রামের নাম *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: titleCtrl,
                          decoration: _inputDeco('যেমন: BCS 46th Prelim Apply', Icons.title_rounded, colorScheme),
                          validator: (v) => v == null || v.isEmpty ? 'নাম দিন' : null,
                        ),
                        const SizedBox(height: 14),

                        // Organization
                        _buildFieldLabel('প্রতিষ্ঠানের নাম'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: orgCtrl,
                          decoration: _inputDeco('যেমন: BPSC, BRDB, বিশ্ববিদ্যালয়...', Icons.business_rounded, colorScheme),
                        ),
                        const SizedBox(height: 14),

                        // Deadline Date
                        _buildFieldLabel('আবেদনের শেষ তারিখ *'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDeadline,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) setLocalState(() => selectedDeadline = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(12),
                              color: widget.folder.color.withValues(alpha: 0.05),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, color: widget.folder.color, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd MMMM, yyyy').format(selectedDeadline),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Icon(Icons.arrow_drop_down_rounded, color: colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Exam Date (optional)
                        _buildFieldLabel('পরীক্ষার তারিখ (ঐচ্ছিক)'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedExamDate ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) setLocalState(() => selectedExamDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_rounded, color: Colors.purple.shade400, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  selectedExamDate != null
                                      ? DateFormat('dd MMMM, yyyy').format(selectedExamDate!)
                                      : 'তারিখ বেছে নিন (ঐচ্ছিক)',
                                  style: TextStyle(
                                    fontWeight: selectedExamDate != null ? FontWeight.w600 : FontWeight.normal,
                                    color: selectedExamDate != null ? null : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                if (selectedExamDate != null)
                                  GestureDetector(
                                    onTap: () => setLocalState(() => selectedExamDate = null),
                                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                                  )
                                else
                                  Icon(Icons.arrow_drop_down_rounded, color: colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Status
                        _buildFieldLabel('আবেদনের স্ট্যাটাস'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            {'val': 'not_applied', 'label': 'আবেদন করিনি', 'color': Colors.orange, 'icon': Icons.schedule_rounded},
                            {'val': 'applied', 'label': 'আবেদন করেছি', 'color': Colors.green, 'icon': Icons.check_circle_rounded},
                            {'val': 'missed', 'label': 'মিস হয়েছে', 'color': Colors.red, 'icon': Icons.cancel_rounded},
                          ].map((s) {
                            final isSelected = selectedStatus == s['val'];
                            final c = s['color'] as Color;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setLocalState(() => selectedStatus = s['val'] as String),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? c.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? c : Colors.transparent, width: 2),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(s['icon'] as IconData, color: isSelected ? c : colorScheme.onSurfaceVariant, size: 20),
                                      const SizedBox(height: 4),
                                      Text(
                                        s['label'] as String,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? c : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Link
                        _buildFieldLabel('সার্কুলার লিংক (ঐচ্ছিক)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: linkCtrl,
                          decoration: _inputDeco('https://...', Icons.link_rounded, colorScheme),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 14),

                        // Secret Note (গুরুত্বপূর্ণ পাসওয়ার্ড ও আইডি)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'গোপন নোট (পাসওয়ার্ড / আইডি / গুরুত্বপূর্ণ তথ্য)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: secretCtrl,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'যেমন:\nUser ID: 12345\nPassword: abc@123\nRoll: 001\nRegistration No: XYZ...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.amber.withValues(alpha: 0.06),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Pin toggle
                        Row(
                          children: [
                            Switch(
                              value: isPinned,
                              onChanged: (v) => setLocalState(() => isPinned = v),
                              activeColor: widget.folder.color,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.push_pin_rounded, size: 18),
                            const SizedBox(width: 6),
                            const Text('উপরে পিন করুন', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(ctx, true);
                              }
                            },
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              existing == null ? 'এন্ট্রি সেভ করুন' : 'আপডেট করুন',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.folder.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      final entry = CountdownEntry(
        id: existing?.id ?? '',
        title: titleCtrl.text.trim(),
        organization: orgCtrl.text.trim(),
        deadlineDate: selectedDeadline,
        examDate: selectedExamDate,
        status: selectedStatus,
        link: linkCtrl.text.trim(),
        secretNote: secretCtrl.text.trim(),
        isPinned: isPinned,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      if (existing == null) {
        await _entriesRef.add(entry.toMap());
      } else {
        await _entriesRef.doc(existing.id).update(entry.toMap());
      }
    }
  }

  Widget _buildFieldLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
  }

  InputDecoration _inputDeco(String hint, IconData icon, ColorScheme cs) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: widget.folder.color, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.folder.color, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _deleteEntry(String entryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('এন্ট্রি মুছুন?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('এই এন্ট্রিটি স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (confirm == true) await _entriesRef.doc(entryId).delete();
  }

  void _showEntryPreview(CountdownEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryPreviewSheet(
        entry: entry,
        folder: widget.folder,
        folderId: widget.folder.id,
        foldersRef: _foldersRef,
        onEdit: () => _showAddEntryDialog(existing: entry),
        onDelete: () => _deleteEntry(entry.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.folder.color,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(widget.folder.icon, size: 20),
            const SizedBox(width: 8),
            Text(widget.folder.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'সক্রিয়'),
            Tab(text: 'আবেদন করা'),
            Tab(text: 'মেয়াদ শেষ'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _entriesRef.orderBy('createdAt', descending: false).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = snap.hasData
              ? snap.data!.docs
                  .map((d) => CountdownEntry.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .toList()
              : <CountdownEntry>[];

          // ফিল্টার
          final active = allEntries.where((e) => !e.isExpired && e.status != 'applied' && e.status != 'missed').toList();
          final applied = allEntries.where((e) => e.status == 'applied').toList();
          final expired = allEntries.where((e) => e.isExpired || e.status == 'missed').toList();

          // পিনড এন্ট্রি উপরে
          active.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return a.daysUntilDeadline.compareTo(b.daysUntilDeadline);
          });

          return TabBarView(
            controller: _tabController,
            children: [
              _buildEntryList(active, 'কোনো সক্রিয় এন্ট্রি নেই'),
              _buildEntryList(applied, 'এখনো কোনো আবেদন করা হয়নি'),
              _buildEntryList(expired, 'মেয়াদোত্তীর্ণ এন্ট্রি নেই'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEntryDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('নতুন এন্ট্রি', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.folder.color,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEntryList(List<CountdownEntry> entries, String emptyMsg) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 60, color: widget.folder.color.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(emptyMsg, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: entries.length,
      itemBuilder: (ctx, i) => _buildDetailedEntryCard(entries[i]),
    );
  }

  Widget _buildDetailedEntryCard(CountdownEntry entry) {
    final folder = widget.folder;
    final days = entry.daysUntilDeadline;
    Color urgencyColor;
    String urgencyLabel;

    if (entry.status == 'applied') {
      urgencyColor = Colors.green;
      urgencyLabel = '✓ Applied';
    } else if (entry.status == 'missed') {
      urgencyColor = Colors.grey;
      urgencyLabel = 'মিস';
    } else if (entry.isExpired) {
      urgencyColor = Colors.grey;
      urgencyLabel = 'Expired';
    } else if (days == 0) {
      urgencyColor = Colors.red;
      urgencyLabel = 'আজই শেষ!';
    } else if (days <= 2) {
      urgencyColor = Colors.red;
      urgencyLabel = '$days দিন বাকি 🚨';
    } else if (days <= 7) {
      urgencyColor = Colors.orange;
      urgencyLabel = '$days দিন বাকি ⚠️';
    } else {
      urgencyColor = Colors.green.shade600;
      urgencyLabel = '$days দিন বাকি';
    }

    return GestureDetector(
      onTap: () => _showEntryPreview(entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: urgencyColor.withValues(alpha: entry.isPinned ? 0.5 : 0.2), width: entry.isPinned ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: urgencyColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left color bar
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: urgencyColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (entry.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(Icons.push_pin_rounded, size: 14, color: folder.color),
                              ),
                            Expanded(
                              child: Text(
                                entry.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        if (entry.organization.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.organization,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Countdown badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      urgencyLabel,
                      style: TextStyle(color: urgencyColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Date row
              Row(
                children: [
                  _dateChip(
                    Icons.event_busy_rounded,
                    'ডেডলাইন: ${DateFormat('d MMM, yy').format(entry.deadlineDate)}',
                    urgencyColor,
                  ),
                  if (entry.examDate != null) ...[
                    const SizedBox(width: 8),
                    _dateChip(
                      Icons.assignment_rounded,
                      'পরীক্ষা: ${DateFormat('d MMM, yy').format(entry.examDate!)}',
                      Colors.purple,
                    ),
                  ],
                ],
              ),
              if (entry.secretNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      const Text('গোপন নোট সেভ আছে', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// =============================================
// ENTRY PREVIEW BOTTOM SHEET
// =============================================

class EntryPreviewSheet extends StatefulWidget {
  final CountdownEntry entry;
  final CountdownFolder folder;
  final String folderId;
  final CollectionReference foldersRef;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EntryPreviewSheet({
    super.key,
    required this.entry,
    required this.folder,
    required this.folderId,
    required this.foldersRef,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<EntryPreviewSheet> createState() => _EntryPreviewSheetState();
}

class _EntryPreviewSheetState extends State<EntryPreviewSheet> {
  bool _showSecretNote = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final folder = widget.folder;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = entry.daysUntilDeadline;

    Color urgencyColor;
    String urgencyText;
    if (entry.status == 'applied') { urgencyColor = Colors.green; urgencyText = 'আবেদন সম্পন্ন ✓'; }
    else if (entry.status == 'missed') { urgencyColor = Colors.grey; urgencyText = 'মিস হয়েছে'; }
    else if (entry.isExpired) { urgencyColor = Colors.grey; urgencyText = 'মেয়াদ শেষ'; }
    else if (days == 0) { urgencyColor = Colors.red; urgencyText = 'আজই শেষ দিন! 🚨'; }
    else if (days <= 2) { urgencyColor = Colors.red; urgencyText = 'মাত্র $days দিন বাকি! 🚨'; }
    else if (days <= 7) { urgencyColor = Colors.orange; urgencyText = '$days দিন বাকি ⚠️'; }
    else { urgencyColor = Colors.green.shade600; urgencyText = '$days দিন বাকি'; }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.88) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: folder.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(folder.icon, color: folder.color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(folder.name, style: TextStyle(fontSize: 12, color: folder.color, fontWeight: FontWeight.bold)),
                          Text(entry.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (entry.organization.isNotEmpty)
                            Text(entry.organization, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Countdown banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [urgencyColor, urgencyColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(urgencyText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            'আবেদনের শেষ: ${DateFormat('dd MMMM, yyyy').format(entry.deadlineDate)}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details card
                _buildInfoCard([
                  if (entry.examDate != null)
                    _infoRow(Icons.assignment_rounded, 'পরীক্ষার তারিখ', DateFormat('dd MMMM, yyyy').format(entry.examDate!), Colors.purple),
                  _infoRow(
                    entry.status == 'applied' ? Icons.check_circle_rounded : (entry.status == 'missed' ? Icons.cancel_rounded : Icons.schedule_rounded),
                    'আবেদনের স্ট্যাটাস',
                    entry.status == 'applied' ? 'আবেদন করা হয়েছে ✓' : (entry.status == 'missed' ? 'মিস হয়েছে ✗' : 'এখনো আবেদন করা হয়নি'),
                    urgencyColor,
                  ),
                  if (entry.link.isNotEmpty)
                    _infoRow(Icons.link_rounded, 'সার্কুলার লিংক', entry.link, Colors.blue),
                ]),
                const SizedBox(height: 12),

                // Secret note section
                if (entry.secretNote.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => setState(() => _showSecretNote = !_showSecretNote),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'গোপন নোট',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ),
                              Icon(
                                _showSecretNote ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.amber, size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showSecretNote ? 'লুকান' : 'দেখুন',
                                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_showSecretNote) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SelectableText(
                                entry.secretNote,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action buttons
                Row(
                  children: [
                    if (widget.onEdit != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onEdit!();
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('সম্পাদনা'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: folder.color,
                            side: BorderSide(color: folder.color),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (widget.onEdit != null && widget.onDelete != null) const SizedBox(width: 10),
                    if (widget.onDelete != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDelete!();
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('মুছুন'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
