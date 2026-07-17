import 'dart:async';
import 'package:flutter/material.dart';
import 'package:async/async.dart'; // StreamZip ব্যবহারের জন্য ইমপোর্ট করা হলো
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final bool isEmbedded;
  const ConversationsScreen({super.key, this.isEmbedded = false});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Stream<List<dynamic>> _combinedStream;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Helper to create a consistent one-on-one chat ID
  String _getOneOnOneChatId(String userId1, String userId2) {
    if (userId1.compareTo(userId2) > 0) {
      return '${userId2}_$userId1';
    } else {
      return '${userId1}_$userId2';
    }
  }

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _combinedStream = _createCombinedStream();
    }
  }

  Stream<List<dynamic>> _createCombinedStream() {
    Stream<QuerySnapshot> chatsStream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser!.uid)
        .snapshots();

    Stream<QuerySnapshot> friendsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .snapshots();

    return StreamZip([chatsStream, friendsStream]).map((results) {
      final chatDocs = results[0].docs;
      final friendDocs = results[1].docs;

      final chatParticipantIds = <String>{};
      for (var chatDoc in chatDocs) {
        final participants = List<String>.from(chatDoc['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');
        if (otherUserId.isNotEmpty) {
          chatParticipantIds.add(otherUserId);
        }
      }

      final friendsWithoutChats = friendDocs.where((friendDoc) {
        return !chatParticipantIds.contains(friendDoc.id);
      }).toList();

      List<dynamic> combinedList = [];
      combinedList.addAll(chatDocs);
      combinedList.addAll(friendsWithoutChats);
      return combinedList;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return widget.isEmbedded
          ? const Center(child: Text('Please log in to see conversations.'))
          : const Scaffold(body: Center(child: Text('Please log in to see conversations.')));
    }

    final bodyContent = StreamBuilder<List<dynamic>>(
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No friends or conversations yet.\nFind new study buddies in the Social Hub!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          List<dynamic> items = snapshot.data!;

          // Sort items: Pinned > Unread > Recent Chats > Friends without chats
          items.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final bool aIsPinned = (aData['pinnedBy'] as Map<String, dynamic>?)?[currentUser!.uid] ?? false;
            final bool bIsPinned = (bData['pinnedBy'] as Map<String, dynamic>?)?[currentUser!.uid] ?? false;

            if (aIsPinned && !bIsPinned) return -1;
            if (!aIsPinned && bIsPinned) return 1;

            final int aUnread = aData['unreadCount']?[currentUser!.uid] ?? 0;
            final int bUnread = bData['unreadCount']?[currentUser!.uid] ?? 0;

            if (aUnread > 0 && bUnread == 0) return -1;
            if (aUnread == 0 && bUnread > 0) return 1;

            final Timestamp? aTimestamp = aData['lastMessageTimestamp'];
            final Timestamp? bTimestamp = bData['lastMessageTimestamp'];

            if (aTimestamp != null && bTimestamp != null) {
              return bTimestamp.compareTo(aTimestamp);
            }
            if (aTimestamp != null) return -1; // a is a chat, b is a friend
            if (bTimestamp != null) return 1;  // b is a chat, a is a friend

            return 0; // Both are friends without chats
          });

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final itemData = item.data() as Map<String, dynamic>;

              // Check if it's a chat or just a friend document
              if (item.reference.path.startsWith('chats/')) {
                final chatId = item.id;
                final bool isGroupChat = itemData['isGroup'] ?? false;
                if (isGroupChat) {
                  return _buildGroupConversationTile(context, chatId, itemData);
                } else {
                  return _buildOneOnOneConversationTile(context, chatId, itemData);
                }
              } else {
                // This is a friend document without an existing chat
                return _buildFriendTile(context, item.id);
              }
            },
          );
        },
      );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: bodyContent,
    );
  }

  Future<void> _togglePinChat(String chatId, bool isCurrentlyPinned) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'pinnedBy': {
        currentUser!.uid: !isCurrentlyPinned,
      }
    }, SetOptions(merge: true));
  }

  Widget _buildGroupConversationTile(BuildContext context, String chatId, Map<String, dynamic> chatData) {
    final groupName = chatData['groupName'] ?? 'Unnamed Group';
    final lastMessage = chatData['lastMessage'] ?? 'No messages yet.';
    final timestamp = (chatData['lastMessageTimestamp'] as Timestamp?)?.toDate();
    final timeString = timestamp != null ? DateFormat('h:mm a').format(timestamp) : '';
    final groupPhotoUrl = chatData['groupPhotoUrl'] as String?;
    final bool isPinned = (chatData['pinnedBy'] as Map<String, dynamic>?)?[currentUser!.uid] ?? false;
    final int unreadCount = chatData['unreadCount']?[currentUser!.uid] ?? 0;
    final bool isUnread = unreadCount > 0;

    return ListTile(
      onLongPress: () => _togglePinChat(chatId, isPinned),
      leading: CircleAvatar(
        backgroundImage: groupPhotoUrl != null ? NetworkImage(groupPhotoUrl) : null,
        child: groupPhotoUrl == null ? const Icon(Icons.groups_rounded) : null,
      ),
      title: Text(
        groupName, 
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
          color: isUnread ? Theme.of(context).colorScheme.primary : null,
        )
      ),
      subtitle: Text(
        lastMessage, 
        maxLines: 1, 
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          color: isUnread ? Theme.of(context).colorScheme.onSurface : Colors.grey,
        ),
      ),
      trailing: _buildTrailingWidget(timeString, isPinned, unreadCount),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              chatName: groupName,
              isGroupChat: true, // receiverId is not needed for group chats
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(Map<String, dynamic> userData) {
    final lastSeenTimestamp = userData['lastSeen'] as Timestamp?;
    if (lastSeenTimestamp == null) {
      return Colors.red;
    }
    final lastSeen = lastSeenTimestamp.toDate();
    final difference = DateTime.now().difference(lastSeen);

    if (difference.inMinutes >= 10) {
      return Colors.red;
    }

    final appActive = userData['appActive'] as bool? ?? false;
    if (appActive && difference.inMinutes < 2) {
      return Colors.green;
    }

    return Colors.amber;
  }

  Widget _buildOneOnOneConversationTile(BuildContext context, String chatId, Map<String, dynamic> chatData) {
    final List<dynamic> participants = chatData['participants'] ?? [];
    final otherUserId = participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');
    final bool isPinned = (chatData['pinnedBy'] as Map<String, dynamic>?)?[currentUser!.uid] ?? false;
    final int unreadCount = chatData['unreadCount']?[currentUser!.uid] ?? 0;
    final bool isUnread = unreadCount > 0;

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: Text('Loading chat...'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final nicknames = chatData['nicknames'] as Map<String, dynamic>? ?? {};
        final receiverNickname = nicknames[otherUserId] as String?;
        final receiverName = receiverNickname ?? (userData['displayName'] ?? 'Study Buddy');
        final lastMessage = chatData['lastMessage'] ?? 'No messages yet.';
        final timestamp = (chatData['lastMessageTimestamp'] as Timestamp?)?.toDate();
        final timeString = timestamp != null ? DateFormat('h:mm a').format(timestamp) : '';
        final statusColor = _getStatusColor(userData);

        return ListTile(
          onLongPress: () => _togglePinChat(chatId, isPinned),
          leading: Stack(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            receiverName, 
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
              color: isUnread ? Theme.of(context).colorScheme.primary : null,
            )
          ),
          subtitle: Text(
            lastMessage, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              color: isUnread ? Theme.of(context).colorScheme.onSurface : Colors.grey,
            ),
          ),
          trailing: _buildTrailingWidget(timeString, isPinned, unreadCount),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: _getOneOnOneChatId(currentUser!.uid, otherUserId),
                  chatName: receiverName,
                  receiverId: otherUserId,
                  isGroupChat: false,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendTile(BuildContext context, String friendId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: Text('Loading friend...'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final friendName = userData['displayName'] ?? 'Study Buddy';
        final statusColor = _getStatusColor(userData);

        return ListTile(
          leading: Stack(
            children: [
              const CircleAvatar(child: Icon(Icons.person_outline)),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(friendName, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: const Text('Tap to start a conversation', style: TextStyle(color: Colors.grey)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: _getOneOnOneChatId(currentUser!.uid, friendId),
                  chatName: friendName,
                  receiverId: friendId,
                  isGroupChat: false,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrailingWidget(String timeString, bool isPinned, int unreadCount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeString, 
          style: TextStyle(
            color: unreadCount > 0 ? Theme.of(context).colorScheme.primary : Colors.grey, 
            fontSize: 12,
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPinned) const Icon(Icons.push_pin_rounded, size: 16, color: Colors.amber),
            if (isPinned && unreadCount > 0) const SizedBox(width: 6),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ],
    );
  }
}