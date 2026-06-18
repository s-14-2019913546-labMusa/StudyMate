import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'daily_routine.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: 'Find Friends'),
            Tab(text: 'My Friends'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
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
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Group feature is coming soon!')));
            },
            icon: const Icon(Icons.add),
            label: const Text('Create New Group'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Friend's Profile & Today's Tasks Screen
// ==========================================
class FriendProfileScreen extends StatelessWidget {
  final String friendId;
  final String friendName;

  const FriendProfileScreen({super.key, required this.friendId, required this.friendName});

  @override
  Widget build(BuildContext context) {
    final String todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('$friendName\'s Profile'),
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
                Text(friendName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Text('Study Buddy', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Today's Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          // Friend's Tasks for Today
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(friendId).collection('dailyRoutines').doc(todayDocId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text('$friendName hasn\'t set any tasks for today yet.'));
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
                    // যদি টাস্ক প্রাইভেট হয়, তবে নাম হাইড করা হবে
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