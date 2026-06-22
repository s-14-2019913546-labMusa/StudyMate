import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';
import 'chat_screen.dart';

// ==========================================
// Social Hub Screen
// ==========================================
class SocialHubScreen extends StatefulWidget {
  const SocialHubScreen({super.key});

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
    _tabController = TabController(length: 4, vsync: this);
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
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(userData['displayName'] ?? 'Study Buddy', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Tap to view profile & tasks'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chat_bubble_outline_rounded, color: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                              friendId: friendId,
                              friendName: userData['displayName'] ?? 'Study Buddy',
                            )));
                          },
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
                          builder: (_) => ChatScreen(
                            isGroup: true,
                            groupId: groupId,
                            groupName: groupName,
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
            builder: (_) => ChatScreen(
              isGroup: true,
              groupId: groupId,
              groupName: name,
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
          Navigator.of(context).pop(); // Go back from profile screen
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
          Container(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
                const SizedBox(height: 12),
                Text(widget.friendName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Text('Study Buddy', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                          friendId: widget.friendId,
                          friendName: widget.friendName,
                        )));
                      },
                      icon: const Icon(Icons.message_rounded),
                      label: const Text('Send Message'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showUnfriendConfirmation(context),
                      icon: const Icon(Icons.person_remove_rounded),
                      label: const Text('Unfriend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                    String displayTitle = task.isPrivate ? '🔒 Private Task' : task.title;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Icon(
                          task.isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                          color: task.isCompleted ? Colors.green : Colors.orange,
                        ),
                        title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${task.completedDurationMinutes} / ${task.totalDurationMinutes} mins completed'),
                        trailing: Text('${(task.totalDurationMinutes > 0 ? (task.completedDurationMinutes / task.totalDurationMinutes * 100).toInt() : 0)}%'),
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
