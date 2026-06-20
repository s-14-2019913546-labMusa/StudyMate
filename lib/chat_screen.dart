import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Helper function to generate a unique chat ID based on two user UIDs
String getChatId(String uid1, String uid2) {
  List<String> ids = [uid1, uid2];
  ids.sort(); // Sort to ensure consistency regardless of who initiates the chat
  return ids.join('_');
}

// Format the timestamp nicely for chat list and chat bubbles
String formatChatTime(Timestamp? timestamp) {
  if (timestamp == null) return '';
  DateTime dateTime = timestamp.toDate();
  DateTime now = DateTime.now();
  
  if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
    return DateFormat('h:mm a').format(dateTime);
  } else if (dateTime.day == now.subtract(const Duration(days: 1)).day &&
             dateTime.month == now.month &&
             dateTime.year == now.year) {
    return 'Yesterday';
  } else {
    return DateFormat('MMM d').format(dateTime);
  }
}

// ==========================================
// Conversations List Screen (Messenger Home)
// ==========================================
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in first")),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 28),
            onPressed: () {
              // Quick search/start chat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select a friend from the Social Hub to start chatting!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search_rounded),
                fillColor: theme.brightness == Brightness.light 
                    ? const Color(0xFFF1F5F9) 
                    : const Color(0xFF1E293B),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Active Friends Horizontal List (Cosmetic Active Now)
          _buildActiveFriendsSection(),

          const Divider(height: 1, thickness: 0.5),

          // Conversation List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start chatting with your study buddies!',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // Filter & Sort doc listing locally as where/orderBy combined query has firestore limitations
                var chatDocs = snapshot.data!.docs;
                chatDocs.sort((a, b) {
                  Timestamp? tA = (a.data() as Map<String, dynamic>)['lastMessageTimestamp'] as Timestamp?;
                  Timestamp? tB = (b.data() as Map<String, dynamic>)['lastMessageTimestamp'] as Timestamp?;
                  if (tA == null) return 1;
                  if (tB == null) return -1;
                  return tB.compareTo(tA); // Descending order
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final chatData = chatDocs[index].data() as Map<String, dynamic>;
                    final List<dynamic> participants = chatData['participants'] ?? [];
                    final String otherUserId = participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');

                    if (otherUserId.isEmpty) return const SizedBox.shrink();

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) return const SizedBox.shrink();
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final displayName = userData['displayName'] ?? 'Study Buddy';
                        final email = userData['email'] ?? '';

                        // Search filter
                        if (_searchQuery.isNotEmpty &&
                            !displayName.toLowerCase().contains(_searchQuery) &&
                            !email.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        final lastMessage = chatData['lastMessage'] ?? '';
                        final lastMessageSenderId = chatData['lastMessageSenderId'] ?? '';
                        final Timestamp? lastMessageTimestamp = chatData['lastMessageTimestamp'] as Timestamp?;
                        final Map<String, dynamic> unreadMap = chatData['unreadCount'] ?? {};
                        final int unreadCount = unreadMap[currentUser!.uid] ?? 0;

                        final bool isUnread = unreadCount > 0 && lastMessageSenderId != currentUser!.uid;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessageSenderId == currentUser!.uid 
                                      ? 'You: $lastMessage' 
                                      : lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                    color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatChatTime(lastMessageTimestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                  color: isUnread ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          trailing: isUnread
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  friendId: otherUserId,
                                  friendName: displayName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Active Now row at the top
  Widget _buildActiveFriendsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final friendDocs = snapshot.data!.docs;

        return Container(
          height: 100,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: friendDocs.length,
            itemBuilder: (context, index) {
              final friendId = friendDocs[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox.shrink();
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final displayName = userData['displayName'] ?? 'Buddy';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            friendId: friendId,
                            friendName: displayName,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'B',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60,
                            child: Text(
                              displayName.split(' ')[0],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ==========================================
// Chat Room Screen (Messenger Chat Window)
// ==========================================
class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatScreen({super.key, required this.friendId, required this.friendName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _chatId = getChatId(currentUser!.uid, widget.friendId);
      _markMessagesAsRead();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mark all unread messages as read in this conversation
  Future<void> _markMessagesAsRead() async {
    if (currentUser == null) return;
    
    // Clear unread count for current user
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'unreadCount': {
        currentUser!.uid: 0,
      }
    }, SetOptions(merge: true));
  }

  // Send message function
  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    _messageController.clear();

    final Timestamp now = Timestamp.now();
    final messageDoc = {
      'senderId': currentUser!.uid,
      'receiverId': widget.friendId,
      'content': text,
      'timestamp': now,
      'isRead': false,
    };

    // Use a transaction/batch to ensure chat update and message addition are synced
    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final messageColRef = chatDocRef.collection('messages');

    // Run in parallel or transaction to update chat metadata
    await chatDocRef.set({
      'participants': [currentUser!.uid, widget.friendId],
      'lastMessage': text,
      'lastMessageSenderId': currentUser!.uid,
      'lastMessageTimestamp': now,
    }, SetOptions(merge: true));

    // Add message doc
    await messageColRef.add(messageDoc);

    // Update unread count for receiver
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot chatSnap = await transaction.get(chatDocRef);
      if (chatSnap.exists) {
        Map<String, dynamic> data = chatSnap.data() as Map<String, dynamic>;
        Map<String, dynamic> unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        int currentUnread = unreadMap[widget.friendId] ?? 0;
        unreadMap[widget.friendId] = currentUnread + 1;
        transaction.update(chatDocRef, {'unreadCount': unreadMap});
      } else {
        transaction.set(chatDocRef, {
          'unreadCount': {
            widget.friendId: 1,
            currentUser!.uid: 0,
          }
        }, SetOptions(merge: true));
      }
    });

    // Auto scroll to bottom
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please login first")));
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 40,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : 'F',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friendName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Active Now',
                    style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call_rounded, color: theme.colorScheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice Call feature is coming soon!')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.videocam_rounded, color: theme.colorScheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video Call feature is coming soon!')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Message Area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // When new messages arrive, mark as read
                _markMessagesAsRead();

                final messageDocs = snapshot.data?.docs ?? [];

                if (messageDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.waving_hand_rounded, size: 36, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Say Hello to ${widget.friendName}!',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text('Start your study discussion here.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Show recent messages at the bottom
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messageDocs.length,
                  itemBuilder: (context, index) {
                    final messageData = messageDocs[index].data() as Map<String, dynamic>;
                    final String senderId = messageData['senderId'] ?? '';
                    final String content = messageData['content'] ?? '';
                    final Timestamp? timestamp = messageData['timestamp'] as Timestamp?;
                    final bool isMe = senderId == currentUser!.uid;

                    return _buildMessageBubble(content, isMe, timestamp, theme);
                  },
                );
              },
            ),
          ),

          // Message Input Field
          _buildMessageInput(theme),
        ],
      ),
    );
  }

  // Message Bubble UI
  Widget _buildMessageBubble(String content, bool isMe, Timestamp? timestamp, ThemeData theme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isMe 
                ? LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
              color: isMe 
                  ? null 
                  : (theme.brightness == Brightness.light 
                      ? const Color(0xFFF1F5F9) 
                      : const Color(0xFF1E293B)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
              ),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
              child: Text(
                formatChatTime(timestamp),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  // Message input bar
  Widget _buildMessageInput(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.mic_none_rounded, color: theme.colorScheme.primary),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: theme.brightness == Brightness.light 
                      ? const Color(0xFFF1F5F9) 
                      : const Color(0xFF1E293B),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
