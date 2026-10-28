import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../chat_bubble_service.dart';
import '../chat_screen.dart';

class FloatingChatManager extends StatefulWidget {
  final Widget child;
  const FloatingChatManager({super.key, required this.child});

  @override
  State<FloatingChatManager> createState() => _FloatingChatManagerState();
}

class _FloatingChatManagerState extends State<FloatingChatManager>
    with SingleTickerProviderStateMixin {
  final ChatBubbleService _bubbleService = ChatBubbleService();

  // Position coordinates of the bubble
  double _x = 20.0;
  double _y = 200.0;
  bool _isDragging = false;
  bool _isOverRemoveTarget = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bubbleService.init();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _bubbleService.activeBubble.addListener(_onBubbleChanged);
    _bubbleService.isExpanded.addListener(_onExpandedChanged);
  }

  void _onBubbleChanged() {
    if (mounted) {
      if (_bubbleService.activeBubble.value != null) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
      setState(() {});
    }
  }

  void _onExpandedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bubbleService.activeBubble.removeListener(_onBubbleChanged);
    _bubbleService.isExpanded.removeListener(_onExpandedChanged);
    _animController.dispose();
    super.dispose();
  }

  void _snapToEdge(Size screenSize) {
    final midX = screenSize.width / 2;
    setState(() {
      if (_x < midX) {
        _x = 12.0;
      } else {
        _x = screenSize.width - 68.0;
      }
      // Constrain Y
      if (_y < 60) _y = 60;
      if (_y > screenSize.height - 120) _y = screenSize.height - 120;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // The main app underlying content
        widget.child,

        // Remove Target Zone at Bottom when dragging
        if (_isDragging)
          Positioned(
            bottom: 30,
            left: screenSize.width / 2 - 35,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isOverRemoveTarget ? 75 : 65,
              height: _isOverRemoveTarget ? 75 : 65,
              decoration: BoxDecoration(
                color: _isOverRemoveTarget
                    ? Colors.red.shade600
                    : Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

        // Floating Chat Bubble
        ValueListenableBuilder<ChatBubbleInfo?>(
          valueListenable: _bubbleService.activeBubble,
          builder: (context, bubble, _) {
            if (bubble == null) return const SizedBox.shrink();

            final isExpanded = _bubbleService.isExpanded.value;

            return Positioned(
              left: _x,
              top: _y,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() => _isDragging = true);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _x += details.delta.dx;
                    _y += details.delta.dy;

                    // Check if over bottom remove target
                    final removeZoneY = screenSize.height - 110;
                    final removeZoneX = screenSize.width / 2;
                    final dist = (_x + 28 - removeZoneX).abs() +
                        (_y + 28 - removeZoneY).abs();
                    _isOverRemoveTarget = dist < 75;
                  });
                },
                onPanEnd: (_) {
                  setState(() => _isDragging = false);
                  if (_isOverRemoveTarget) {
                    HapticFeedback.mediumImpact();
                    _bubbleService.hideBubble();
                  } else {
                    _snapToEdge(screenSize);
                  }
                },
                onTap: () {
                  HapticFeedback.selectionClick();
                  _bubbleService.toggleExpand();
                },
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildBubbleWidget(bubble, isExpanded),
                ),
              ),
            );
          },
        ),

        // Expanded Floating Chat Popup Modal Window
        ValueListenableBuilder<ChatBubbleInfo?>(
          valueListenable: _bubbleService.activeBubble,
          builder: (context, bubble, _) {
            if (bubble == null || !_bubbleService.isExpanded.value) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                child: GestureDetector(
                  onTap: () => _bubbleService.collapse(),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {}, // Prevent taps inside from closing
                      child: _buildFloatingChatWindow(bubble, screenSize),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBubbleWidget(ChatBubbleInfo bubble, bool isExpanded) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: bubble.photoUrl != null && bubble.photoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      bubble.photoUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
          if (bubble.unreadCount > 0 && !isExpanded)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  bubble.unreadCount > 9 ? '9+' : '${bubble.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingChatWindow(ChatBubbleInfo bubble, Size screenSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = (screenSize.width * 0.88).clamp(300.0, 420.0);
    final height = (screenSize.height * 0.65).clamp(420.0, 580.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header
            _buildWindowHeader(bubble, isDark),

            // Messages List Body
            Expanded(
              child: _FloatingChatMessagesList(chatId: bubble.chatId),
            ),

            // Input Bar
            _FloatingChatInputBar(
              chatId: bubble.chatId,
              receiverId: bubble.receiverId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowHeader(ChatBubbleInfo bubble, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bubble.chatName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                    SizedBox(width: 5),
                    Text(
                      'অনলাইন চ্যাট বাবল',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Full Screen Button
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded,
                color: Colors.white, size: 20),
            tooltip: 'ফুল স্ক্রিনে খুলুন',
            onPressed: () {
              _bubbleService.collapse();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatId: bubble.chatId,
                    chatName: bubble.chatName,
                    isGroupChat: bubble.isGroupChat,
                    receiverId: bubble.receiverId,
                  ),
                ),
              );
            },
          ),
          // Minimize Button
          IconButton(
            icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 22),
            tooltip: 'মিনিমাইজ',
            onPressed: () => _bubbleService.collapse(),
          ),
          // Close / Hide Button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            tooltip: 'বন্ধ করুন',
            onPressed: () => _bubbleService.hideBubble(),
          ),
        ],
      ),
    );
  }
}

class _FloatingChatMessagesList extends StatelessWidget {
  final String chatId;
  const _FloatingChatMessagesList({required this.chatId});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(35)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: isDark ? Colors.white24 : Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'কোনো মেসেজ নেই\nচ্যাট শুরু করতে হাই বলুন!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final bool isMe = data['senderId'] == currentUserId;
            final String content = data['content'] ?? '';
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            final String timeStr = ts != null
                ? DateFormat('hh:mm a').format(ts.toDate())
                : '';

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe
                      ? null
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : (isDark ? Colors.white54 : Colors.black45),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FloatingChatInputBar extends StatefulWidget {
  final String chatId;
  final String? receiverId;

  const _FloatingChatInputBar({required this.chatId, this.receiverId});

  @override
  State<_FloatingChatInputBar> createState() => _FloatingChatInputBarState();
}

class _FloatingChatInputBarState extends State<_FloatingChatInputBar> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);
    _textCtrl.clear();

    try {
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

      await chatRef.collection('messages').add({
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Study Mate',
        'content': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final chatDoc = await chatRef.get();
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final unreadUpdates = <String, dynamic>{};
      for (var pId in participants) {
        if (pId != user.uid) {
          unreadUpdates['unreadCount.$pId'] = FieldValue.increment(1);
        }
      }

      await chatRef.update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        ...unreadUpdates,
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error sending floating chat message: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: const InputDecoration(
                  hintText: 'রিপ্লাই লিখুন...',
                  hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF4F46E5),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSending ? null : _sendMessage,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
