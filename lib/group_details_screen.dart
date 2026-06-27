import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'social_hub_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _changeGroupPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref('group_photos')
          .child('${widget.groupId}.jpg');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.groupId);
      await chatRef.update({'groupPhotoUrl': downloadUrl});

      await chatRef.collection('messages').add({
        'senderId': 'system',
        'content': '${currentUser!.displayName ?? 'Someone'} changed the group photo.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group photo updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // গ্রুপের নাম পরিবর্তন করার ডায়ালগ
  Future<void> _renameGroup(String currentName) async {
    _nameController.text = currentName;
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Group'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Enter group name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = _nameController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName != currentName && currentUser != null) {
      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.groupId);
        
        await chatRef.update({
          'groupName': newName,
        });

        await chatRef.collection('messages').add({
          'senderId': 'system',
          'content': '${currentUser!.displayName ?? 'Someone'} renamed the group to "$newName"',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group renamed successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error renaming group: $e')),
          );
        }
      }
    }
  }

  // নতুন মেম্বার অ্যাড করার অপশন (অ্যাডমিনদের জন্য)
  Future<void> _addMembers(List<String> currentParticipants) async {
    if (currentUser == null) return;

    // ইউজারের অ্যাকসেপ্টেড ফ্রেন্ড লিস্ট নিয়ে আসা
    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .get();

    final List<String> friendIds = friendsSnap.docs.map((d) => d.id).toList();
    // যারা অলরেডি গ্রুপে নাই তাদের ফিল্টার করা
    final List<String> nonMembers = friendIds.where((id) => !currentParticipants.contains(id)).toList();

    if (nonMembers.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add Members'),
            content: const Text('All your friends are already in this group!'),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Friends to Group',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: nonMembers.length,
                        itemBuilder: (context, index) {
                          final friendId = nonMembers[index];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) return const SizedBox.shrink();
                              final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                              final name = userData['displayName'] ?? 'Study Buddy';
                              final email = userData['email'] ?? '';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'B'),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(email),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _executeAddMember(friendId, name);
                                  },
                                  child: const Text('Add'),
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
            },
          );
        },
      );
    }
  }

  Future<void> _executeAddMember(String friendId, String friendName) async {
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.groupId);
      
      // Add to participants list
      await chatRef.update({
        'participants': FieldValue.arrayUnion([friendId]),
        'unreadCount.$friendId': 0, // Set initial unread count
      });

      // Post system message
      await chatRef.collection('messages').add({
        'senderId': 'system',
        'content': '${currentUser!.displayName ?? 'Someone'} added $friendName to the group',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $friendName successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    }
  }

  // মেম্বারকে অ্যাডমিন হিসেবে প্রমোট করা
  Future<void> _makeAdmin(String memberId, String memberName) async {
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.groupId);

      await chatRef.update({
        'admins': FieldValue.arrayUnion([memberId]),
      });

      await chatRef.collection('messages').add({
        'senderId': 'system',
        'content': '${currentUser!.displayName ?? 'Someone'} made $memberName an Admin',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$memberName is now an Admin!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making admin: $e')),
        );
      }
    }
  }

  // গ্রুপ থেকে মেম্বারকে বের করে দেওয়া
  Future<void> _removeMember(String memberId, String memberName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $memberName?'),
        content: Text('Are you sure you want to remove $memberName from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.groupId);

        await chatRef.update({
          'participants': FieldValue.arrayRemove([memberId]),
          'admins': FieldValue.arrayRemove([memberId]),
          'unreadCount.$memberId': FieldValue.delete(),
        });

        await chatRef.collection('messages').add({
          'senderId': 'system',
          'content': '${currentUser!.displayName ?? 'Someone'} removed $memberName from the group',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed $memberName from the group.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing member: $e')),
          );
        }
      }
    }
  }

  // গ্রুপ থেকে লিভ নেওয়া
  Future<void> _leaveGroup(List<String> participants, List<String> admins) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('Are you sure you want to leave this group? You will no longer receive messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && currentUser != null) {
      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.groupId);

        // যদি এই ইউজার লিভ নেওয়ার পর মেম্বার সংখ্যা ০ হয়ে যায়, তবে পুরো চ্যাট ডিলিট করা হবে
        if (participants.length <= 1) {
          await chatRef.delete();
          if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You left and the group was deleted.')),
            );
          }
          return;
        }

        // যদি লিভ নেওয়া ইউজারটি একমাত্র অ্যাডমিন হয়, তবে অন্য কাউকে প্রমোট করা
        bool isLeavingAdmin = admins.contains(currentUser!.uid);
        if (isLeavingAdmin && admins.length == 1) {
          // প্রথম নন-লিভিং মেম্বারকে অ্যাডমিন হিসেবে সিলেক্ট করা
          final nextAdminId = participants.firstWhere((id) => id != currentUser!.uid);
          
          // মেম্বারের নাম বের করা নোটিফিকেশনের জন্য
          final userSnap = await FirebaseFirestore.instance.collection('users').doc(nextAdminId).get();
          final nextAdminName = (userSnap.data() as Map<String, dynamic>?)?['displayName'] ?? 'Study Buddy';

          await chatRef.update({
            'admins': FieldValue.arrayUnion([nextAdminId]),
          });

          await chatRef.collection('messages').add({
            'senderId': 'system',
            'content': '$nextAdminName was promoted to Admin (Auto-promotion)',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // এবার নিজের ডাটা সরানো
        await chatRef.update({
          'participants': FieldValue.arrayRemove([currentUser!.uid]),
          'admins': FieldValue.arrayRemove([currentUser!.uid]),
          'unreadCount.${currentUser!.uid}': FieldValue.delete(),
        });

        // সিস্টেমে চ্যাট মেসেজ দেওয়া
        await chatRef.collection('messages').add({
          'senderId': 'system',
          'content': '${currentUser!.displayName ?? 'Someone'} left the group',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You left the group.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving group: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    final theme = Theme.of(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.groupId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Group does not exist or has been deleted.')));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String groupName = data['groupName'] ?? widget.groupName;
        final List<String> participants = List<String>.from(data['participants'] ?? []);
        final List<String> admins = List<String>.from(data['admins'] ?? []);
        final bool isAdmin = admins.contains(currentUser!.uid);

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            title: const Text('Group Options', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Group Header (Name & Edit option)
                Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Column(
                    children: [
                      AbsorbPointer( // This widget absorbs pointer events
                        absorbing: _isUploading,
                        child: Stack( // The Stack should be a child of AbsorbPointer
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              backgroundImage: data['groupPhotoUrl'] != null ? NetworkImage(data['groupPhotoUrl']) : null,
                              child: _isUploading
                                  ? const CircularProgressIndicator()
                                  : (data['groupPhotoUrl'] == null
                                      ? Text(
                                          groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: theme.colorScheme.primary),
                                        )
                                      : null),
                            ),
                            if (isAdmin)
                              GestureDetector(
                                onTap: _changeGroupPhoto,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.secondary,
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              groupName,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _renameGroup(groupName),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${participants.length} Members',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ), // AbsorbPointer and Column closed here
                ),

                const SizedBox(height: 8),

                // Admin Action Menu
                if (isAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Admin Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary)),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person_add_rounded, color: theme.colorScheme.primary),
                    ),
                    title: const Text('Add Members', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Invite your friends to this group'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _addMembers(participants),
                  ),
                  const Divider(height: 16, thickness: 0.5),
                ],

                // Members List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Group Members',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${participants.length} total',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Members list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final memberId = participants[index];
                    final isMemberAdmin = admins.contains(memberId);
                    final isMe = memberId == currentUser!.uid;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                      builder: (ctx, userSnap) {
                        if (!userSnap.hasData) return const SizedBox.shrink();
                        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                        final name = userData['displayName'] ?? 'Study Buddy';
                        final lastSeen = (userData['lastSeen'] as Timestamp?)?.toDate();
                        final isOnline = lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 2;

                        return ListTile(
                          onTap: isMe
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FriendProfileScreen(
                                        friendId: memberId,
                                        friendName: name,
                                      ),
                                    ),
                                  );
                                },
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'B'),
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
                                      border: Border.all(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            isMe ? '$name (You)' : name,
                            style: TextStyle(
                              fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(color: isOnline ? Colors.green : Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMemberAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isAdmin && !isMe)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onSelected: (value) {
                                    if (value == 'make_admin') {
                                      _makeAdmin(memberId, name);
                                    } else if (value == 'remove') {
                                      _removeMember(memberId, name);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (!isMemberAdmin)
                                      const PopupMenuItem(
                                        value: 'make_admin',
                                        child: Text('Make Admin'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove from Group', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const Divider(height: 32, thickness: 0.5),

                // Leave group button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _leaveGroup(participants, admins),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}
