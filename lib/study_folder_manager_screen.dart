import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'language_manager.dart';
import 'study_folder_details_screen.dart';

class StudyFolderManagerScreen extends StatefulWidget {
  const StudyFolderManagerScreen({super.key});

  @override
  State<StudyFolderManagerScreen> createState() => _StudyFolderManagerScreenState();
}

class _StudyFolderManagerScreenState extends State<StudyFolderManagerScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Modern HSL color palette options
  final List<Color> _paletteColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF14B8A6), // Teal
    const Color(0xFFF43F5E), // Rose
    const Color(0xFFD97706), // Amber
    const Color(0xFF10B981), // Emerald
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFF97316), // Orange
  ];

  Future<void> _createFolder() async {
    if (_currentUser == null) return;

    final TextEditingController nameController = TextEditingController();
    Color selectedColor = _paletteColors[0];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Create Folder'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Folder Name'.tr(),
                        hintText: 'Enter folder name'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Choose Color'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _paletteColors.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: colorScheme.onSurface, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Create Folder'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      final name = nameController.text.trim();
      final colorHex = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .collection('studyFolders')
            .doc();

        await docRef.set({
          'id': docRef.id,
          'name': name,
          'color': colorHex,
          'createdAt': FieldValue.serverTimestamp(),
          'subjects': [],
        });
      } catch (e) {
        debugPrint('Error creating study folder: $e');
      }
    }
  }

  Future<void> _deleteFolder(String folderId, String folderName) async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this folder?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .collection('studyFolders')
            .doc(folderId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder Deleted Successfully!'.tr())),
          );
        }
      } catch (e) {
        debugPrint('Error deleting study folder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete folder!'.tr())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Special Hub'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFolder,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add, size: 28),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .collection('studyFolders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No folders created yet'.tr(),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to create a folder'.tr(),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final folderId = docs[index].id;
              final name = data['name'] ?? '';
              final colorHex = data['color'] ?? '#6366F1';
              final subjects = data['subjects'] as List<dynamic>? ?? [];

              Color folderColor;
              try {
                folderColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
              } catch (e) {
                folderColor = const Color(0xFF6366F1);
              }

              // Count total topics inside subjects
              int totalTopics = 0;
              for (var sub in subjects) {
                if (sub is Map<String, dynamic> && sub['topics'] != null) {
                  totalTopics += (sub['topics'] as List).length;
                }
              }

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudyFolderDetailsScreen(
                          folderId: folderId,
                          folderName: name,
                          colorHex: colorHex,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: folderColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.folder_rounded, color: folderColor, size: 28),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              onPressed: () => _deleteFolder(folderId, name),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${subjects.length} ${'Subjects'.tr()} • $totalTopics ${'Topic'.tr()}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
