import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'chat_screen.dart';
import 'task_details_screen.dart';
import 'gamification_service.dart';
import 'language_manager.dart';
import 'conversations_screen.dart';

// ==========================================
// Social Hub Screen
// ==========================================
class SocialHubScreen extends StatefulWidget {
  final int initialTabIndex;
  const SocialHubScreen({super.key, this.initialTabIndex = 1});

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTabIndex);
    _ensureUserExistsInFirestore();
  }

  Future<void> _ensureUserExistsInFirestore() async {
    if (currentUser == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'uid': currentUser!.uid,
          'displayName': currentUser!.displayName ?? 'Study Buddy',
          'email': currentUser!.email ?? '',
          'streak': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data() as Map<String, dynamic>;
        if (data['displayName'] == null || data['email'] == null) {
          await docRef.update({
            'displayName': data['displayName'] ?? currentUser!.displayName ?? 'Study Buddy',
            'email': data['email'] ?? currentUser!.email ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint("Error ensuring user exists: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ফায়ারবেসে ফ্রেন্ড রিকুয়েস্ট পাঠানোর লজিক
  Future<void> _sendFriendRequest(String targetUserId) async {
    if (currentUser == null) return;
    
    // Target User এর ফ্রেন্ডস কালেকশনে রিকুয়েস্ট পাঠানো হচ্ছে
    await FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('friends').doc(currentUser!.uid).set({
      'status': 'pending',
      'initiatedBy': currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // নিজের কালেকশনেও রেকর্ড রাখা হচ্ছে
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('friends').doc(targetUserId).set({
      'status': 'requested',
      'initiatedBy': currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
  }

  // রিকুয়েস্ট একসেপ্ট করার লজিক
  Future<void> _acceptFriendRequest(String requesterId) async {
    if (currentUser == null) return;

    // উভয়ের স্ট্যাটাস 'accepted' করে দেওয়া
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('friends').doc(requesterId).update({
      'status': 'accepted',
    });
    await FirebaseFirestore.instance.collection('users').doc(requesterId).collection('friends').doc(currentUser!.uid).update({
      'status': 'accepted',
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request accepted!')));
  }

  // নতুন সার্চ লজিক: ইমেইল এবং ইউজার আইডি (Document ID) উভয় দিয়ে সার্চ করা
  Future<List<DocumentSnapshot>> _searchUsers(String query) async {
    if (query.isEmpty) return [];

    final List<DocumentSnapshot> searchResults = [];
    final Set<String> addedIds = {}; // ডুপ্লিকেট রেজাল্ট এড়ানোর জন্য

    // ১. ইমেইল দিয়ে সার্চ (Prefix Search)
    final emailSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    for (var doc in emailSnapshot.docs) {
      if (doc.id != currentUser?.uid) {
        searchResults.add(doc);
        addedIds.add(doc.id);
      }
    }

    // ২. ইউনিক ইউজার আইডি (Document ID) দিয়ে সার্চ (Exact Match)
    try {
      final idDoc = await FirebaseFirestore.instance.collection('users').doc(query).get();
      if (idDoc.exists && idDoc.id != currentUser?.uid && !addedIds.contains(idDoc.id)) {
        searchResults.add(idDoc);
      }
    } catch (e) {
      // যদি query কোনো ভ্যালিড Document ID ফরম্যাট না হয়, তাহলে এরর ইগনোর করবে
    }

    return searchResults;
  }

  // Helper to create a consistent one-on-one chat ID
  String _getOneOnOneChatId(String userId1, String userId2) {
    // Sort the UIDs to ensure the chat ID is always the same regardless of who initiates
    if (userId1.compareTo(userId2) > 0) {
      return '$userId2\_$userId1';
    } else {
      return '$userId1\_$userId2';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: const Text('Social Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Find Friends'),
            Tab(text: 'My Friends'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ConversationsScreen(isEmbedded: true),
          _buildLeaderboardTab(),
          _buildFindFriendsTab(),
          _buildMyFriendsTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  // ==================== TAB 1: FIND FRIENDS ====================
  Widget _buildFindFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by Email or User ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? const Center(child: Text('Search for your study buddies!', style: TextStyle(color: Colors.grey)))
              : FutureBuilder<List<DocumentSnapshot>>(
                  future: _searchUsers(_searchQuery), // আপডেট করা কাস্টম সার্চ ফাংশন
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }

                    final users = snapshot.data!;

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData = users[index].data() as Map<String, dynamic>;
                        final userId = users[index].id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person),
                          ),
                          title: Text(userData['displayName'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${userData['email'] ?? ''}\nID: $userId'), // ইমেইলের নিচে আইডিও দেখাবে
                          trailing: ElevatedButton.icon(
                            onPressed: () => _sendFriendRequest(userId),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
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

  // ==================== TAB 2: MY FRIENDS & REQUESTS ====================
  Widget _buildMyFriendsTab() {
    if (currentUser == null) return const Center(child: Text("Please login first"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('friends').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No friends yet. Start connecting!', style: TextStyle(color: Colors.grey)));
        }

        final docs = snapshot.data!.docs;
        final pendingRequests = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').toList();
        final friends = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'accepted').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pendingRequests.isNotEmpty) ...[
              const Text('Friend Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              ...pendingRequests.map((req) {
                final requesterId = req.id;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(requesterId).get(),
                  builder: (ctx, userSnap) {
                    if (!userSnap.hasData) return const SizedBox.shrink();
                    final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                    return Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(userData['displayName'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _acceptFriendRequest(requesterId),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
              const Divider(height: 32),
            ],
            
            const Text('My Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            if (friends.isEmpty) const Text('You have no friends on your list yet.'),
            ...friends.map((friendDoc) {
              final friendId = friendDoc.id;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                builder: (ctx, userSnap) {
                  if (!userSnap.hasData) return const ListTile(title: Text('Loading...'));
                  final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final photoUrl = userData['photoUrl'] as String?;
                  ImageProvider? avatarImage;
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    avatarImage = photoUrl.startsWith('http')
                        ? NetworkImage(photoUrl)
                        : FileImage(File(photoUrl)) as ImageProvider;
                  }
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(userData['displayName'] ?? 'Study Buddy', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Tap to view tasks'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Send Message',
                          icon: Icon(Icons.chat_bubble_outline_rounded, color: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                              chatId: _getOneOnOneChatId(currentUser!.uid, friendId),
                              chatName: userData['displayName'] ?? 'Study Buddy',
                              receiverId: friendId,
                              isGroupChat: false,
                            )));
                          },
                        ),
                        IconButton(
                          tooltip: 'View Profile',
                          icon: Icon(Icons.account_circle_outlined, color: Theme.of(context).colorScheme.secondary),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendDetailsScreen(
                            friendId: friendId,
                            friendName: userData['displayName'] ?? 'Study Buddy',
                          ))),
                        ),
                      ],
                    ),
                    onTap: () {
                      // বন্ধুর প্রোফাইল এবং আজকের টাস্ক দেখতে নিয়ে যাবে
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FriendProfileScreen(
                        friendId: friendId,
                        friendName: userData['displayName'] ?? 'Study Buddy',
                      )));
                    },
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  // ==================== TAB 3: GROUPS ====================
  Widget _buildGroupsTab() {
    if (currentUser == null) return const Center(child: Text("Please login first"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: true)
          .where('participants', arrayContains: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyGroupsState();
        }

        final groupDocs = snapshot.data!.docs;

        // Sort groups by lastMessageTimestamp descending
        groupDocs.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['lastMessageTimestamp'] as Timestamp?;
          Timestamp? tB = (b.data() as Map<String, dynamic>)['lastMessageTimestamp'] as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _showCreateGroupDialog,
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('Create New Group'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: groupDocs.length,
                itemBuilder: (context, index) {
                  final groupData = groupDocs[index].data() as Map<String, dynamic>;
                  final groupId = groupDocs[index].id;
                  final groupName = groupData['groupName'] ?? 'Unnamed Group';
                  final List<dynamic> participants = groupData['participants'] ?? [];
                  final lastMessage = groupData['lastMessage'] ?? '';
                  final lastMessageSenderName = groupData['lastMessageSenderName'] ?? '';

                  String displayLastMessage = lastMessage;
                  if (lastMessageSenderName.isNotEmpty) {
                    displayLastMessage = '$lastMessageSenderName: $lastMessage';
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.groups_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${participants.length} members • $displayLastMessage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: groupId,
                            chatName: groupName,
                            isGroupChat: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyGroupsState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_rounded, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('My Groups', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create study groups, share routines, and compete with your friends!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create New Group'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateGroupDialog() async {
    if (currentUser == null) return;

    // Fetch user's friends first
    final friendsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .get();

    final List<String> friendIds = friendsQuery.docs.map((d) => d.id).toList();

    final TextEditingController groupNameController = TextEditingController();
    final List<String> selectedFriendIds = [];

    if (friendIds.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Create Group'),
            content: const Text('You need to add some friends first to create a group! Go to "Find Friends" tab to add buddies.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create Study Group',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: groupNameController,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          hintText: 'e.g. Science Study Buddies',
                          prefixIcon: Icon(Icons.group_rounded),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Friends to Add',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: friendIds.length,
                          itemBuilder: (context, index) {
                            final friendId = friendIds[index];
                            final isSelected = selectedFriendIds.contains(friendId);

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData) return const SizedBox.shrink();
                                final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                                final name = userData['displayName'] ?? 'Study Buddy';
                                final email = userData['email'] ?? '';

                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(email),
                                  onChanged: (checked) {
                                    setModalState(() {
                                      if (checked == true) {
                                        selectedFriendIds.add(friendId);
                                      } else {
                                        selectedFriendIds.remove(friendId);
                                      }
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final gName = groupNameController.text.trim();
                          if (gName.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please enter a group name')),
                            );
                            return;
                          }
                          if (selectedFriendIds.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please select at least one friend to add')),
                            );
                            return;
                          }

                          Navigator.pop(ctx); // Close modal
                          await _createNewGroup(gName, selectedFriendIds);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
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

  Future<void> _createNewGroup(String name, List<String> invitedIds) async {
    if (currentUser == null) return;
    try {
      final List<String> participants = [currentUser!.uid, ...invitedIds];
      final chatRef = FirebaseFirestore.instance.collection('chats').doc();
      final String groupId = chatRef.id;

      // Initialize unread count map with 0 for all participants
      final Map<String, int> unreadCount = {
        for (var id in participants) id: 0,
      };

      await chatRef.set({
        'isGroup': true,
        'groupName': name,
        'createdBy': currentUser!.uid,
        'admins': [currentUser!.uid],
        'participants': participants,
        'unreadCount': unreadCount,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '${currentUser!.displayName ?? 'Someone'} created the group "$name"',
        'lastMessageSenderId': 'system',
        'lastMessageSenderName': 'System',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Add a system welcome message
      await chatRef.collection('messages').add({
        'senderId': 'system',
        'content': '${currentUser!.displayName ?? 'Someone'} created the group "$name"',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" created successfully!')),
        );

        // Open chat window for the group
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: groupId,
              chatName: name,
              isGroupChat: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    }
  }

  Widget _buildLeaderboardTab() {
    if (currentUser == null) return const Center(child: Text("Please login first"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No leaderboard data yet.'));
        }

        final users = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'uid': doc.id,
            'displayName': data['displayName'] ?? 'Study Buddy',
            'streak': data['streak'] ?? 0,
            'email': data['email'] ?? '',
          };
        }).toList();

        // Sort by streak descending
        users.sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userItem = users[index];
            final rank = index + 1;
            final isCurrentUser = userItem['uid'] == currentUser!.uid;
            
            String medal = '';
            if (rank == 1) medal = '🥇 ';
            else if (rank == 2) medal = '🥈 ';
            else if (rank == 3) medal = '🥉 ';

            return Card(
              color: isCurrentUser 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                  : Theme.of(context).cardColor,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isCurrentUser 
                    ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.1),
                  child: Text(
                    medal.isEmpty ? '#$rank' : medal,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                title: Text(
                  userItem['displayName'],
                  style: TextStyle(
                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentUser ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                subtitle: Text(userItem['email'], style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      '${userItem['streak']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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

// ==========================================
// Friend's Profile & Tasks Screen
// ==========================================
class FriendProfileScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const FriendProfileScreen({super.key, required this.friendId, required this.friendName});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _adjustDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  // Helper to create a consistent one-on-one chat ID
  String _getOneOnOneChatId(String userId1, String userId2) {
    // Sort the UIDs to ensure the chat ID is always the same regardless of who initiates
    if (userId1.compareTo(userId2) > 0) {
      return '$userId2\_$userId1';
    } else {
      return '$userId1\_$userId2';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateDocId = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final String formattedDate = DateFormat('yyyy-MM-dd (EEEE)').format(_selectedDate);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('${widget.friendName}\'s Profile'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Header
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(widget.friendId).get(),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
              final photoUrl = userData['photoUrl'] as String?;
              ImageProvider? avatarImage;
              if (photoUrl != null && photoUrl.isNotEmpty) {
                avatarImage = photoUrl.startsWith('http')
                    ? NetworkImage(photoUrl)
                    : FileImage(File(photoUrl)) as ImageProvider;
              }
              return Container(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? const Icon(Icons.person, size: 40) : null,
                    ),
                    const SizedBox(height: 12),
                    Text(widget.friendName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                              chatId: _getOneOnOneChatId(FirebaseAuth.instance.currentUser!.uid, widget.friendId),
                              receiverId: widget.friendId,
                              chatName: widget.friendName,
                            )));
                          },
                          icon: const Icon(Icons.message_rounded),
                          label: const Text('Send Message'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FriendDetailsScreen(
                              friendId: widget.friendId,
                              friendName: widget.friendName)));
                          },
                          icon: const Icon(Icons.account_circle_rounded),
                          label: const Text('View Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                            foregroundColor: Theme.of(context).colorScheme.secondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tasks List", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _adjustDate(-1),
                    ),
                    TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        DateFormat('MMM dd').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _adjustDate(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Friend's Tasks for the selected day
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.friendId).collection('dailyRoutines').doc(dateDocId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No tasks set for $formattedDate.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                DailyRoutine routine = DailyRoutine.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
                
                if (routine.tasks.isEmpty) {
                  return const Center(child: Text('No tasks available.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: routine.tasks.length,
                  itemBuilder: (context, index) {
                    final task = routine.tasks[index];
                    
                    double progress = task.totalDurationMinutes > 0
                        ? (task.elapsedSeconds / (task.totalDurationMinutes * 60))
                        : 0.0;
                    if (progress > 1.0) progress = 1.0;
                    int progressPercentage = (progress * 100).toInt();

                    // Status identification
                    String statusText = 'Pending';
                    Color statusColor = Colors.grey;
                    IconData statusIcon = Icons.pending_actions_rounded;

                    if (task.isCompleted || task.status == 'completed') {
                      statusText = 'Completed';
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle_rounded;
                    } else if (task.endTime != null && task.endTime!.isBefore(DateTime.now()) && progress < 0.1) {
                      statusText = 'Missed';
                      statusColor = Colors.red;
                      statusIcon = Icons.error_outline_rounded;
                    } else if (task.status == 'running') {
                      statusText = 'Running';
                      statusColor = Colors.blue;
                      statusIcon = Icons.play_circle_fill_rounded;
                    } else if (task.status == 'paused') {
                      statusText = 'Paused';
                      statusColor = Colors.amber.shade700;
                      statusIcon = Icons.pause_circle_filled_rounded;
                    }

                    String displayTitle = task.isPrivate ? 'Private Task'.tr() : (task.subject ?? task.title);
                    
                    String timeText = '';
                    if (task.startTime != null && task.endTime != null) {
                      timeText = '${DateFormat('h:mm a').format(task.startTime!)} - ${DateFormat('h:mm a').format(task.endTime!)}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailsScreen(
                                task: task,
                                isFriendView: true,
                                onUpdate: (updatedTask) async {
                                  try {
                                    final docRef = FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.friendId)
                                        .collection('dailyRoutines')
                                        .doc(dateDocId);
                                    final docSnap = await docRef.get();
                                    if (docSnap.exists) {
                                      DailyRoutine currentRoutine = DailyRoutine.fromMap(docSnap.data()!, docSnap.id);
                                      int taskIndex = currentRoutine.tasks.indexWhere((t) => t.id == updatedTask.id);
                                      if (taskIndex != -1) {
                                        currentRoutine.tasks[taskIndex] = updatedTask;
                                        await docRef.update({
                                          'tasks': currentRoutine.tasks.map((t) => t.toMap()).toList()
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint("Error updating friend task: $e");
                                  }
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: statusColor, width: 6),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Icon, Title, Private Icon, Status Badge
                              Row(
                                children: [
                                  Icon(statusIcon, color: statusColor, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      displayTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: statusText == 'Missed' ? Colors.red.shade900 : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (task.isPrivate) ...[
                                    const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusText.tr(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Row 2: Category tag & Time if available
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (!task.isPrivate && task.category != null && task.category!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        task.category!.tr(),
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (timeText.isNotEmpty)
                                    Text(
                                      timeText,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Row 3: Progress text
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${progressPercentage}% ' + 'Completed'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${task.elapsedSeconds ~/ 60} / ${task.totalDurationMinutes} mins',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Row 4: Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.shade200,
                                  color: statusColor,
                                  minHeight: 6,
                                ),
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
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Friend's Detailed Profile Screen
// ==========================================
class FriendDetailsScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const FriendDetailsScreen({super.key, required this.friendId, required this.friendName});

  @override
  State<FriendDetailsScreen> createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends State<FriendDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadFriendDetails();
  }

  Future<void> _loadFriendDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.friendId).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _userData = doc.data()!;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading friend details: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showUnfriendConfirmation(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Unfriend ${widget.friendName}?'),
          content: Text('Are you sure you want to remove ${widget.friendName} from your friends list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Unfriend', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('friends').doc(widget.friendId).delete();
        await FirebaseFirestore.instance.collection('users').doc(widget.friendId).collection('friends').doc(currentUser.uid).delete();
        
        if (mounted) {
          // Go back from details screen and refresh previous screens
          Navigator.of(context).pop(); // Pops FriendDetailsScreen
          Navigator.of(context).pop(); // Pops FriendProfileScreen (if open)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed ${widget.friendName} from friends.')),
          );
        }
      } catch (e) {
        debugPrint("Error unfriending: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.friendName}\'s Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String name = _userData['name'] ?? _userData['displayName'] ?? widget.friendName;
    final String bio = _userData['bio'] ?? "Let's study hard together!";
    final String institution = _userData['institution'] ?? "No Institution Set";
    final String academicYear = _userData['academicYear'] ?? "";
    final String major = _userData['major'] ?? "";
    final double dailyGoal = ((_userData['dailyStudyGoalHours'] ?? 2.0) as num).toDouble();
    final int totalTasksDone = (_userData['totalTasksDone'] ?? 0) as int;
    final int streak = (_userData['streak'] ?? 0) as int;
    final int totalXP = (_userData['totalXP'] ?? 0) as int;
    final String? photoUrl = _userData['photoUrl'] as String?;

    ImageProvider? avatarImage;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarImage = photoUrl.startsWith('http')
          ? NetworkImage(photoUrl)
          : FileImage(File(photoUrl)) as ImageProvider;
    }

    final level = GamificationService.getLevel(totalXP);
    final progress = GamificationService.getLevelProgress(totalXP);
    final levelTitle = GamificationService.getLevelTitle(level);
    final xpNext = GamificationService.xpForNextLevel(totalXP);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('$name\'s Profile'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            // Institution / Year / Major
            if (institution.isNotEmpty || academicYear.isNotEmpty || major.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${institution.isNotEmpty ? institution : "StudyMate"}'
                '${academicYear.isNotEmpty ? " • $academicYear" : ""}'
                '${major.isNotEmpty ? " • $major" : ""}',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
            // Bio
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                bio,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // Stat Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(context, totalTasksDone.toString(), 'Tasks Done', Icons.check_circle_rounded, Colors.green),
                _buildStatCard(context, '${dailyGoal.toInt()}h', 'Goal/Day', Icons.access_time_filled_rounded, Colors.blue),
                _buildStatCard(context, streak.toString(), 'Day Streak', Icons.local_fire_department_rounded, Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            // Level Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            levelTitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalXP XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$xpNext XP to next level',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            // Unfriend Button
            ElevatedButton.icon(
              onPressed: () => _showUnfriendConfirmation(context),
              icon: const Icon(Icons.person_remove_rounded),
              label: Text('Unfriend $name', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.error,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.26,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}
