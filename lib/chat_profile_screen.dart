import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'social_hub_screen.dart';
import 'task_history_screen.dart';
import 'language_manager.dart';

class ChatProfileScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;

  const ChatProfileScreen({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends State<ChatProfileScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  
  String? _receiverNickname;
  String _selectedTheme = 'default';
  bool _isMutedByMe = false;

  Map<String, dynamic> _receiverUserData = {};

  final List<Map<String, dynamic>> _themesList = [
    {
      'id': 'default',
      'name': 'Classic (Default)',
      'colors': [Colors.grey, Colors.grey],
    },
    {
      'id': 'sunset',
      'name': 'Sunset Glow',
      'colors': [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
    },
    {
      'id': 'forest',
      'name': 'Forest Green',
      'colors': [Color(0xFF11998E), Color(0xFF38EF7D)],
    },
    {
      'id': 'ocean',
      'name': 'Ocean Breeze',
      'colors': [Color(0xFF02AABD), Color(0xFF00CDAC)],
    },
    {
      'id': 'midnight',
      'name': 'Midnight Star',
      'colors': [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    },
    {
      'id': 'lavender',
      'name': 'Lavender Dream',
      'colors': [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_currentUser == null) return;
    try {
      // Load receiver detailed profile info
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverId).get();
      if (userDoc.exists && userDoc.data() != null) {
        _receiverUserData = userDoc.data()!;
      }

      // Load chat settings
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
      if (chatDoc.exists && chatDoc.data() != null) {
        final chatData = chatDoc.data()!;
        final nicknames = chatData['nicknames'] as Map<String, dynamic>? ?? {};
        final theme = chatData['theme'] as String? ?? 'default';
        final blocked = chatData['blocked'] as Map<String, dynamic>? ?? {};

        setState(() {
          _receiverNickname = nicknames[widget.receiverId] as String?;
          _selectedTheme = theme;
          _isMutedByMe = blocked[_currentUser.uid] == true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading chat settings: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateNickname(String? nickname) async {
    if (_currentUser == null) return;
    final cleanNickname = nickname?.trim();
    
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'nicknames': {
          widget.receiverId: (cleanNickname == null || cleanNickname.isEmpty) ? FieldValue.delete() : cleanNickname,
        }
      }, SetOptions(merge: true));

      setState(() {
        _receiverNickname = cleanNickname;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nickname updated successfully!'.tr())),
        );
      }
    } catch (e) {
      debugPrint("Error updating nickname: $e");
    }
  }

  Future<void> _updateTheme(String themeId) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'theme': themeId,
      }, SetOptions(merge: true));

      setState(() {
        _selectedTheme = themeId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat theme updated!'.tr())),
        );
      }
    } catch (e) {
      debugPrint("Error updating theme: $e");
    }
  }

  Future<void> _toggleMute(bool value) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'blocked': {
          _currentUser.uid: value,
        }
      }, SetOptions(merge: true));

      setState(() {
        _isMutedByMe = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Chat messages muted.'.tr() : 'Chat messages enabled.'.tr())),
        );
      }
    } catch (e) {
      debugPrint("Error toggling mute: $e");
    }
  }

  void _showNicknameDialog() {
    final textController = TextEditingController(text: _receiverNickname ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Set Nickname'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter nickname...'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                _updateNickname(null);
                Navigator.pop(context);
              },
              child: Text('Clear'.tr(), style: const TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateNickname(textController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Save'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Chat Theme'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _themesList.length,
                  itemBuilder: (context, index) {
                    final th = _themesList[index];
                    final isSelected = th['id'] == _selectedTheme;
                    return GestureDetector(
                      onTap: () {
                        _updateTheme(th['id']);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                  width: 3,
                                ),
                                gradient: LinearGradient(
                                  colors: List<Color>.from(th['colors']),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 28)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (th['name'] as String).tr(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Chat Settings'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final photoUrl = _receiverUserData['photoUrl'] as String?;
    ImageProvider? avatarImage;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarImage = photoUrl.startsWith('http')
          ? NetworkImage(photoUrl)
          : FileImage(File(photoUrl)) as ImageProvider;
    }

    final displayTitleName = _receiverNickname ?? widget.receiverName;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Chat Settings'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar and Name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayTitleName,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (_receiverNickname != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(${widget.receiverName})',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Options Group
              Text(
                'Customize'.tr(),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                      title: Text('Set Nickname'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(_receiverNickname ?? 'Add nickname for this chat'.tr(), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _showNicknameDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                      title: Text('Change Theme'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(_selectedTheme.toUpperCase().tr(), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _showThemeSelector,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy Group
              Text(
                'Privacy & Support'.tr(),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.notifications_off_outlined, color: theme.colorScheme.primary),
                      title: Text('Mute Messages'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('Turn off messaging for this contact'.tr(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      value: _isMutedByMe,
                      onChanged: _toggleMute,
                      activeThumbColor: theme.colorScheme.primary,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary),
                      title: Text('View Profile'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('Visit real profile & academic details'.tr(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FriendDetailsScreen(
                              friendId: widget.receiverId,
                              friendName: widget.receiverName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tasks Section Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskHistoryScreen(
                        userId: widget.receiverId,
                        userName: _receiverNickname ?? widget.receiverName,
                        isFriendView: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.task_alt_rounded),
                label: Text('View Tasks List'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
