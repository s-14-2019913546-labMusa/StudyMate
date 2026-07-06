import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'group_details_screen.dart';
import 'chat_profile_screen.dart';
import 'language_manager.dart';
import 'chat_theme_manager.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? receiverId; // For one-on-one chats
  final bool isGroupChat;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.receiverId,
    this.isGroupChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  bool _isUploading = false;

  // Mentions State
  bool _isTypingMention = false;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    // Ensure chat document exists for one-on-one chats
    if (!widget.isGroupChat && widget.receiverId != null) {
      _ensureChatDocumentExists();
    } else {
      _markAsRead();
    }
    
    if (widget.isGroupChat) {
      _fetchGroupMembers();
    }
    _messageController.addListener(_onTextChanged);
  }

  Future<void> _fetchGroupMembers() async {
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
      if (chatDoc.exists) {
        final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
        List<Map<String, dynamic>> members = [];
        // Fetch up to 30 members individually (avoid whereIn 10 item limit)
        for (String pId in participants.take(30)) {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(pId).get();
          if (uDoc.exists) {
            members.add({
              'uid': uDoc.id,
              'name': uDoc.data()?['displayName'] ?? 'Study Buddy',
              'photoUrl': uDoc.data()?['photoUrl'] ?? '',
            });
          }
        }
        if (mounted) {
          setState(() {
            _groupMembers = members;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
    }
  }

  void _onTextChanged() {
    if (!widget.isGroupChat) return;

    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.baseOffset <= 0) {
      if (_isTypingMention) setState(() => _isTypingMention = false);
      return;
    }

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtSignIndex = textBeforeCursor.lastIndexOf('@');
    
    if (lastAtSignIndex != -1) {
      if (lastAtSignIndex == 0 || textBeforeCursor[lastAtSignIndex - 1] == ' ' || textBeforeCursor[lastAtSignIndex - 1] == '\n') {
        final query = textBeforeCursor.substring(lastAtSignIndex + 1);
        if (!query.contains(' ') && !query.contains('\n')) {
          if (!_isTypingMention || _mentionQuery != query) {
            setState(() {
              _isTypingMention = true;
              _mentionQuery = query.toLowerCase();
            });
          }
          return;
        }
      }
    }
    if (_isTypingMention) {
      setState(() => _isTypingMention = false);
    }
  }

  void _insertMention(String name) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);
    
    final lastAtSignIndex = textBeforeCursor.lastIndexOf('@');
    if (lastAtSignIndex != -1) {
      final newTextBefore = textBeforeCursor.substring(0, lastAtSignIndex);
      final mentionText = '@$name ';
      
      _messageController.value = TextEditingValue(
        text: newTextBefore + mentionText + textAfterCursor,
        selection: TextSelection.collapsed(offset: newTextBefore.length + mentionText.length),
      );
      setState(() {
        _isTypingMention = false;
        _mentionQuery = '';
      });
    }
  }

  Future<void> _ensureChatDocumentExists() async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final doc = await chatRef.get();
    if (!doc.exists) {
      await chatRef.set({
        'participants': [_currentUser!.uid, widget.receiverId],
        'isGroup': false,
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {_currentUser.uid: 0, widget.receiverId!: 0},
      });
    }
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markAsRead() {
    if (_currentUser != null) {
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'unreadCount.${_currentUser.uid}': 0,
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    _messageController.clear();
    _scrollToBottom();

    await _addMessageToFirestore(content: text, type: 'text');
  }

  Future<void> _addMessageToFirestore({
    required String content,
    required String type,
    String? fileName,
    int? fileSize,
  }) async {
    if (_currentUser == null) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    await chatRef.collection('messages').add({
      'senderId': _currentUser.uid,
      'senderName': _currentUser.displayName ?? 'User',
      'content': content,
      'type': type,
      'fileName': fileName,
      'fileSize': fileSize,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update last message and unread counts for all participants
    final chatDoc = await chatRef.get();
    final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    final unreadUpdates = <String, dynamic>{};
    for (var pId in participants) {
      if (pId != _currentUser.uid) {
        unreadUpdates['unreadCount.$pId'] = FieldValue.increment(1);
      }
    }

    await chatRef.update({
      'lastMessage': type == 'image' ? '📷 Photo' : (type == 'file' ? '📄 File' : content),
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      ...unreadUpdates,
    });
  }

  Future<void> _pickAndUploadFile({bool pickImage = true}) async {
    if (_isUploading) return;

    File? fileToUpload;
    String? fileName;

    if (pickImage) {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        fileToUpload = File(pickedFile.path);
        fileName = pickedFile.name;
      }
    } else {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        fileToUpload = File(result.files.single.path!);
        fileName = result.files.single.name;
      }
    }

    if (fileToUpload == null) return;

    setState(() => _isUploading = true);

    try {
      final fileType = pickImage ? 'image' : 'file';
      final ref = FirebaseStorage.instance
          .ref('chat_media')
          .child(widget.chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = ref.putFile(fileToUpload);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      final fileSize = await fileToUpload.length();

      await _addMessageToFirestore(
        content: downloadUrl,
        type: fileType,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // _getThemeDecoration moved to ChatThemeManager

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, chatSnap) {
        Map<String, dynamic> chatData = {};
        if (chatSnap.hasData && chatSnap.data!.exists) {
          chatData = chatSnap.data!.data() as Map<String, dynamic>;
        }

        final themeName = chatData['theme'] as String? ?? 'default';
        final nicknames = chatData['nicknames'] as Map<String, dynamic>? ?? {};
        final blocked = chatData['blocked'] as Map<String, dynamic>? ?? {};

        // Nickname for the other user
        final receiverNickname = widget.receiverId != null ? nicknames[widget.receiverId] as String? : null;
        final chatTitle = receiverNickname ?? widget.chatName;

        // Block status
        final isMutedByMe = widget.receiverId != null && (blocked[_currentUser?.uid] == true);
        final isMutedByOther = widget.receiverId != null && (blocked[widget.receiverId] == true);
        final isBlocked = isMutedByMe || isMutedByOther;

        return Scaffold( // Main Scaffold
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar( // Custom AppBar
            elevation: 0.5,
            backgroundColor: theme.cardColor,
            title: widget.isGroupChat
                ? _buildGroupAppBarTitle(context)
                : _buildOneOnOneAppBarTitle(context, chatTitle),
            actions: [ // Actions
              if (widget.isGroupChat)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailsScreen(
                          groupId: widget.chatId,
                          groupName: widget.chatName,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Container(
            decoration: ChatThemeManager.getThemeDecoration(themeName, isDark),
            child: Column( // Body with messages and input
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('Say hello! 👋'));
                      }

                      final messages = snapshot.data!.docs;

                      WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final data = message.data() as Map<String, dynamic>;
                          final isMe = data['senderId'] == _currentUser?.uid;
                          final isFirstMessage = index == messages.length - 1 ||
                              (messages[index + 1].data() as Map<String, dynamic>)['senderId'] != data['senderId'];
                          final isSystemMessage = data['senderId'] == 'system';

                          if (isSystemMessage) {
                            return _SystemMessageBubble(message: data['content'] ?? '');
                          }
                          
                          final receiverUnread = (!widget.isGroupChat && widget.receiverId != null)
                              ? (chatData['unreadCount']?[widget.receiverId] ?? 0)
                              : 0;
                          final bool showSeenIndicator = index == 0 && isMe && (receiverUnread == 0);

                          return _MessageBubble(
                            data: data,
                            isMe: isMe,
                            isGroupChat: widget.isGroupChat,
                            themeName: themeName,
                            messageId: message.id,
                            chatId: widget.chatId,
                            showSeenIndicator: showSeenIndicator,
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(),
                  ),
                _buildMentionList(),
                _buildMessageInput(theme, isBlocked, isMutedByMe),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildMentionList() {
    if (!_isTypingMention || _groupMembers.isEmpty) return const SizedBox.shrink();

    final filteredMembers = _groupMembers.where((m) {
      final name = (m['name'] as String).toLowerCase();
      return name.startsWith(_mentionQuery) || name.contains(' $_mentionQuery');
    }).toList();

    if (filteredMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: filteredMembers.length,
        itemBuilder: (context, index) {
          final member = filteredMembers[index];
          final photoUrl = member['photoUrl'] as String;
          return ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
            ),
            title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: () => _insertMention(member['name']),
          );
        },
      ),
    );
  }

  // AppBar for One-on-One Chat
  Widget _buildOneOnOneAppBarTitle(BuildContext context, String displayName) {
    return FutureBuilder<DocumentSnapshot>(
      future: widget.receiverId != null
          ? FirebaseFirestore.instance.collection('users').doc(widget.receiverId).get()
          : null,
      builder: (context, userSnapshot) {
        String photoUrl = '';
        bool isOnline = false;

        if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          photoUrl = userData['photoUrl'] ?? '';
          final lastSeen = (userData['lastSeen'] as Timestamp?)?.toDate();
          isOnline = lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 2;
        }

        ImageProvider? avatarImage;
        if (photoUrl.isNotEmpty) {
          avatarImage = photoUrl.startsWith('http')
              ? NetworkImage(photoUrl)
              : FileImage(File(photoUrl)) as ImageProvider;
        }

        return GestureDetector(
          onTap: () {
            if (widget.receiverId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatProfileScreen(
                    chatId: widget.chatId,
                    receiverId: widget.receiverId!,
                    receiverName: widget.chatName,
                  ),
                ),
              );
            }
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: avatarImage,
                    child: avatarImage == null ? const Icon(Icons.person, size: 20) : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).cardColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        );
      }
    );
  }

  // AppBar for Group Chat
  Widget _buildGroupAppBarTitle(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        final groupData = snapshot.hasData ? snapshot.data!.data() as Map<String, dynamic>? : null;
        final groupPhotoUrl = groupData?['groupPhotoUrl'] as String?;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(
                  groupId: widget.chatId,
                  groupName: widget.chatName,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: groupPhotoUrl != null ? NetworkImage(groupPhotoUrl) : null,
                child: groupPhotoUrl == null ? const Icon(Icons.groups_rounded, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chatName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text('Tap for group info', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(ThemeData theme, bool isBlocked, bool isMutedByMe) {
    if (isBlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
        child: SafeArea(
          child: Center(
            child: Text(
              isMutedByMe 
                  ? 'You have muted this chat. Enable messages in settings to chat.'.tr()
                  : 'Messages are disabled for this chat.'.tr(),
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment Button
            IconButton(
              icon: const Icon(Icons.attach_file_rounded),
              onPressed: _showAttachmentMenu,
              color: theme.colorScheme.primary,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            FloatingActionButton(
              onPressed: _sendMessage,
              mini: true,
              elevation: 2,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadFile(pickImage: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Document (PDF)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadFile(pickImage: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Message Bubble Widgets ---

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final bool isGroupChat;
  final String themeName;
  final String messageId;
  final String chatId;
  final bool showSeenIndicator;

  const _MessageBubble({
    required this.data,
    required this.isMe,
    required this.isGroupChat,
    required this.themeName,
    required this.messageId,
    required this.chatId,
    required this.showSeenIndicator,
  });

  Color _getBubbleColor(String? themeName, bool isMe, ThemeData themeData) {
    if (themeName == null || themeName == 'default') {
      return isMe ? themeData.colorScheme.primary : themeData.cardColor;
    }
    if (!isMe) {
      return themeData.brightness == Brightness.dark 
          ? Colors.black.withValues(alpha: 0.4) 
          : Colors.white.withValues(alpha: 0.7);
    }
    switch (themeName) {
      case 'sunset': return const Color(0xFFFF7E5F);
      case 'forest': return const Color(0xFF11998E);
      case 'ocean': return const Color(0xFF02AABD);
      case 'midnight': return const Color(0xFF203A43);
      case 'lavender': return const Color(0xFFB19FFB);
      default: return themeData.colorScheme.primary;
    }
  }

  Color _getBubbleTextColor(String? themeName, bool isMe, ThemeData themeData) {
    if (themeName == null || themeName == 'default') {
      return isMe ? Colors.white : themeData.colorScheme.onSurface;
    }
    if (!isMe) {
      return themeData.colorScheme.onSurface;
    }
    return Colors.white;
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reactions'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        final myId = FirebaseAuth.instance.currentUser?.uid;
                        if (myId != null) {
                          final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
                          if (reactions[myId] == emoji) {
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .collection('messages')
                                .doc(messageId)
                                .update({'reactions.$myId': FieldValue.delete()});
                          } else {
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .collection('messages')
                                .doc(messageId)
                                .update({'reactions.$myId': emoji});
                          }
                        }
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text('Copy Text'.tr()),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: data['content'] ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Message copied to clipboard!'.tr())),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Theme
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft; // Alignment
    final color = _getBubbleColor(themeName, isMe, theme);
    final textColor = _getBubbleTextColor(themeName, isMe, theme);

    // Generate a color from sender's name for group chats
    final List<Color> nameColors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal, Colors.pink];
    final senderName = data['senderName'] ?? 'User';
    final nameColor = isMe
        ? Colors.transparent
        : nameColors[senderName.hashCode % nameColors.length];

    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeString = timestamp != null ? DateFormat('h:mm a').format(timestamp) : '';

    final reactionsMap = Map<String, dynamic>.from(data['reactions'] ?? {});
    final List<String> uniqueEmojis = [];
    reactionsMap.forEach((uid, emoji) {
      if (!uniqueEmojis.contains(emoji)) {
        uniqueEmojis.add(emoji);
      }
    });

    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isGroupChat && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: nameColor,
                  fontWeight: FontWeight.bold),
              ),
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onLongPress: () => _showMessageOptions(context),
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: color,
                    border: (isMe || themeName != 'default') ? null : Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(context, textColor),
                      const SizedBox(height: 4),
                      Text(
                        timeString,
                        style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
              if (reactionsMap.isNotEmpty)
                Positioned(
                  bottom: -10,
                  right: isMe ? null : -6,
                  left: isMe ? -6 : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          uniqueEmojis.join(''),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (reactionsMap.length > 1) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${reactionsMap.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (showSeenIndicator)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 4.0),
              child: Text(
                'Seen'.tr(),
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    final type = data['type'] ?? 'text';
    final content = data['content'] ?? '';

    switch (type) {
      case 'image':
        return GestureDetector(
          onTap: () => _showFullScreenImage(context, content),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              content,
              loadingBuilder: (context, child, progress) {
                return progress == null ? child : const CircularProgressIndicator();
              },
              errorBuilder: (context, error, stack) => const Icon(Icons.broken_image),
            ),
          ),
        );
      case 'file':
        return _FileMessage(
          url: content,
          fileName: data['fileName'] ?? 'File',
          fileSize: data['fileSize'],
          textColor: textColor,
        );
      case 'text':
      default:
        return _buildHighlightedText(context, content, textColor);
    }
  }

  Widget _buildHighlightedText(BuildContext context, String text, Color textColor) {
    if (!text.contains('@')) {
      return Text(text, style: TextStyle(color: textColor, fontSize: 15));
    }

    final words = text.split(' ');
    List<TextSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.startsWith('@') && word.length > 1) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: TextStyle(
              color: isMe ? Colors.white : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word ',
            style: TextStyle(color: textColor, fontSize: 15),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileMessage extends StatefulWidget {
  final String url;
  final String fileName;
  final int? fileSize;
  final Color textColor;

  const _FileMessage({
    required this.url,
    required this.fileName,
    this.fileSize,
    required this.textColor,
  });

  @override
  State<_FileMessage> createState() => _FileMessageState();
}

class _FileMessageState extends State<_FileMessage> {
  bool _isDownloading = false;
  double _progress = 0.0;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _downloadAndOpenFile() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.fileName}';
      final file = File(filePath);

      // If file already exists, open it directly
      if (await file.exists()) {
        await OpenFilex.open(filePath);
        setState(() => _isDownloading = false);
      } else {
        // Download the file
        final response = await http.get(Uri.parse(widget.url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download file: ${response.statusCode}');
        }

        await OpenFilex.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isDownloading ? null : _downloadAndOpenFile,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_rounded, color: widget.textColor, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.fileSize != null)
                        Text(
                          _formatBytes(widget.fileSize!),
                          style: TextStyle(color: widget.textColor.withValues(alpha: 0.7), fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final String message;
  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}