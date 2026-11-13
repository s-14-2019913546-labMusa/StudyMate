import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../daily_routine.dart';
import '../dashboard_screen.dart';
import '../calendar_screen.dart';
import '../focus_music_screen.dart';
import '../flashcards_screen.dart';
import '../dictionary_screen.dart';
import '../ai_service.dart';
import '../revision_147_screen.dart';
import '../islamic_life_screen.dart';
import '../theme_manager.dart';
import '../local_notification_service.dart';
import '../study_analytics_screen.dart';
import '../weekly_overview_screen.dart';
import '../task_history_screen.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import 'live_room_timer.dart';
import '../study_folder_manager_screen.dart';
import '../special_day_countdown_screen.dart';
import '../daily_diary_screen.dart';
import '../bookmarks_screen.dart';
import '../news_reader_screen.dart';
import '../social_hub_screen.dart';
import '../google_sheet_sync_screen.dart';
import '../multi_sheet_manager_screen.dart';
import '../notifications_hub_screen.dart';
import '../widgets/sound_picker_widget.dart';
import '../tools_screen.dart';
import '../widgets/avatar_image.dart';

// ==========================================
// 7. Study Room Screen (একসাথে পড়া)
// ==========================================
class StudyRoomScreen extends StatefulWidget {
  const StudyRoomScreen({super.key});

  @override
  State<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends State<StudyRoomScreen> {
  bool _inRoom = false;
  String _roomCode = '';
  final TextEditingController _joinCodeCtrl = TextEditingController();
  final TextEditingController _roomNameCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingProof = false;

  // Generate 6 character random code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  void _enterRoom(String code) {
    setState(() {
      _roomCode = code;
      _inRoom = true;
    });
    _cleanupExpiredProofs();
  }

  Future<void> _cleanupExpiredProofs() async {
    if (_roomCode.isEmpty) return;
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    try {
      final query = await FirebaseFirestore.instance
          .collection('study_rooms')
          .doc(_roomCode)
          .collection('proofs')
          .where('timestamp', isLessThan: Timestamp.fromDate(twentyFourHoursAgo))
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error cleaning up expired proofs: $e");
    }
  }

  Future<void> _createRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please log in first!'.tr())));
      return;
    }

    String roomName = _roomNameCtrl.text.trim();
    if (roomName.isEmpty) {
      roomName = '${user.displayName ?? 'Student'}\'s Study Room';
    }

    final code = 'RM-${_generateRoomCode()}';

    try {
      await FirebaseFirestore.instance.collection('study_rooms').doc(code).set({
        'roomId': code,
        'name': roomName,
        'creatorId': user.uid,
        'creatorName': user.displayName ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [user.uid],
        'participantNames': {user.uid: user.displayName ?? 'Anonymous'},
        'admins': [user.uid],
      });

      _roomNameCtrl.clear();
      _enterRoom(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Room $code created successfully!', '$code রুম তৈরি হয়েছে!'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error creating room: $e', 'রুম তৈরি করা যায়নি: $e'))));
      }
    }
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please log in first!'.tr())));
      return;
    }

    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please enter a room code!'.tr())));
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('study_rooms').doc(code).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Room not found! Please check the code.'.tr())));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('study_rooms').doc(code).update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'participantNames.${user.uid}': user.displayName ?? 'Anonymous',
      });

      _joinCodeCtrl.clear();
      _enterRoom(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Joined Room $code!', '$code রুমে যোগ দিয়েছেন!'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error joining room: $e', 'রুমে যোগ দেওয়া যায়নি: $e'))));
      }
    }
  }

  Future<void> _leaveRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).update({
        'participants': FieldValue.arrayRemove([user.uid]),
      });
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Left the room.'.tr())));
      }
    } catch (e) {
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
    }
  }

  Future<void> _requestProof(String targetId, String targetName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('study_rooms')
          .doc(_roomCode)
          .collection('proof_requests')
          .add({
        'fromId': user.uid,
        'fromName': user.displayName ?? 'Anonymous',
        'toId': targetId,
        'toName': targetName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'seen': false,
        'seenAt': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trx('Study proof requested from $targetName. Waiting for upload...', '$targetName-এর কাছে পড়ার প্রমাণ চাওয়া হয়েছে। আপলোডের অপেক্ষা...'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error requesting proof: $e', 'প্রমাণ চাওয়া যায়নি: $e'))));
      }
    }
  }

  Future<void> _confirmInviteFriend(String friendId, String friendName, bool isAdmin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = isAdmin ? 'Add Member (মেম্বার যুক্ত করুন)'.tr() : 'Invite Friend (বন্ধু আমন্ত্রণ)'.tr();
    final message = isAdmin
        ? 'Do you want to add $friendName directly to this study room?'.tr()
        : 'Do you want to send a request to add $friendName to the Admin for approval?'.tr();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isAdmin) {
        try {
          await FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).update({
            'participants': FieldValue.arrayUnion([friendId]),
            'participantNames.$friendId': friendName,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$friendName added directly to the room!'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add member: $e'.tr())),
            );
          }
        }
      } else {
        try {
          await FirebaseFirestore.instance
              .collection('study_rooms')
              .doc(_roomCode)
              .collection('member_requests')
              .doc(friendId)
              .set({
            'requesterId': user.uid,
            'requesterName': user.displayName ?? 'Anonymous',
            'invitedId': friendId,
            'invitedName': friendName,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invitation request sent to the Admin!'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send invite request: $e'.tr())),
            );
          }
        }
      }
    }
  }

  void _showAddMemberSheet(List<String> currentParticipants, String creatorId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('friends')
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, friendsSnap) {
            if (friendsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = friendsSnap.data?.docs ?? [];
            final inviteableFriends = docs.where((d) => !currentParticipants.contains(d.id)).toList();

            if (inviteableFriends.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No inviteable friends found.'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Invite Friends to Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: inviteableFriends.length,
                      itemBuilder: (context, index) {
                        final fId = inviteableFriends[index].id;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(fId).get(),
                          builder: (ctx, userSnap) {
                            if (!userSnap.hasData) {
                              return ListTile(
                                leading: CircleAvatar(child: Icon(Icons.person)),
                                title: Text(trx('Loading Buddy...', 'সঙ্গীর তথ্য আসছে...')),
                              );
                            }

                            final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final fName = userData['displayName'] ?? 'Study Buddy';
                            final photoUrl = userData['photoUrl'] as String?;
                            ImageProvider? avatarImage;
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              avatarImage = avatarImageProvider(photoUrl);
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatarImage,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: avatarImage == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
                              ),
                              title: Text(fName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_rounded, color: Colors.green),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmInviteFriend(fId, fName, user.uid == creatorId);
                                },
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

  Future<void> _uploadProofImage(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 30,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingProof = true);

      // Convert image file to Base64 data string
      String base64ImageUrl;
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        base64ImageUrl = 'data:image/jpeg;base64,$base64String';
      } catch (e) {
        throw 'Failed to read and encode image: $e';
      }

      // Write proof document to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('study_rooms')
            .doc(_roomCode)
            .collection('proofs')
            .add({
          'senderId': user.uid,
          'senderName': user.displayName ?? 'Anonymous',
          'imageUrl': base64ImageUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        throw 'Firestore Save Proof Failed: $e';
      }

      // Complete request in Firestore
      if (requestId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('study_rooms')
              .doc(_roomCode)
              .collection('proof_requests')
              .doc(requestId)
              .update({'status': 'completed'});
        } catch (e) {
          throw 'Firestore Update Request Failed: $e';
        }
      }

      setState(() => _isUploadingProof = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Study proof uploaded successfully!'.tr())));
      }
    } catch (e) {
      setState(() => _isUploadingProof = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _uploadProofVoluntarily() async {
    await _uploadProofImage('');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(trx('Study Partner Room', 'স্টাডি রুম'))),
        body: Center(child: Text(trx('Please log in to access Study Partner Rooms.', 'স্টাডি রুমে যেতে লগইন করুন।'))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_inRoom ? 'Study Room: $_roomCode' : 'Study Partner Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _inRoom
            ? [
                IconButton(
                  tooltip: 'Leave Room',
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  onPressed: _leaveRoom,
                )
              ]
            : null,
      ),
      body: _inRoom ? _buildRoomUI(user) : _buildJoinCreateUI(user),
    );
  }

  Widget _buildJoinCreateUI(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(Icons.video_camera_front_rounded, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Study Together'.tr(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Create a room and invite your friends to study together and track progress.'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          
          // Create Room Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a New Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter room name (optional)'.tr(),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _createRoom,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text('Create New Room'.tr()),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Join Room Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _joinCodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter Room Code (e.g. RM-XXXXXX)'.tr(),
                      prefixIcon: const Icon(Icons.meeting_room_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _joinRoom,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                    child: Text('Join Room'.tr()),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // Your Rooms Section
          Text('Your Rooms (তোমার রুমসমূহ)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_rooms')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'You are not in any rooms yet.'.tr(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final roomData = docs[index].data() as Map<String, dynamic>;
                  final name = roomData['name'] ?? 'Study Room';
                  final code = roomData['roomId'] ?? '';
                  final participants = List<String>.from(roomData['participants'] ?? []);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${'Code:'.tr()} $code • ${participants.length} ${'members'.tr()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room code copied!'.tr())));
                            },
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _roomCode = code;
                          _inRoom = true;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomUI(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).snapshots(),
      builder: (context, roomSnap) {
        if (roomSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!roomSnap.hasData || !roomSnap.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Room not found or has been deleted.'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _inRoom = false;
                      _roomCode = '';
                    });
                  },
                  child: Text('Go Back'.tr()),
                ),
              ],
            ),
          );
        }

        final roomData = roomSnap.data!.data() as Map<String, dynamic>;
        final name = roomData['name'] ?? 'Study Room';
        final code = roomData['roomId'] ?? '';
        final participants = List<String>.from(roomData['participants'] ?? []);
        final participantNames = Map<String, dynamic>.from(roomData['participantNames'] ?? {});
        final creatorId = roomData['creatorId'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room Header Summary
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${'Room Code:'.tr()} $code', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room code copied!'.tr())));
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),

            // সবার জন্য একসাথে চলা Pomodoro
            LiveRoomTimer(roomCode: _roomCode, roomData: roomData, participantNames: participantNames),

            // Pending Proof Requests for Me (With 30-Second dismiss countdowns)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('study_rooms')
                  .doc(_roomCode)
                  .collection('proof_requests')
                  .where('toId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, requestsSnap) {
                final requests = requestsSnap.data?.docs ?? [];
                if (requests.isEmpty) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: requests.map((reqDoc) {
                      return ProofRequestBanner(
                        requestDoc: reqDoc,
                        onUpload: _uploadProofImage,
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            // Pending Member Requests (Only for Admin)
            if (user.uid == creatorId)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_rooms')
                    .doc(_roomCode)
                    .collection('member_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, requestsSnap) {
                  if (requestsSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  final requests = requestsSnap.data?.docs ?? [];
                  if (requests.isEmpty) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.amber.shade200, width: 1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group_add_rounded, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text(
                                'New Member Requests (মেম্বার রিকোয়েস্ট)'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.brown),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: requests.length,
                            itemBuilder: (context, idx) {
                              final reqData = requests[idx].data() as Map<String, dynamic>;
                              final reqId = requests[idx].id;
                              final invitedName = reqData['invitedName'] ?? 'Friend';
                              final invitedId = reqData['invitedId'] ?? '';
                              final requesterName = reqData['requesterName'] ?? 'Member';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$invitedName (${'Invited by'.tr()} $requesterName)',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('study_rooms').doc(_roomCode).update({
                                              'participants': FieldValue.arrayUnion([invitedId]),
                                              'participantNames.$invitedId': invitedName,
                                            });
                                            await FirebaseFirestore.instance
                                                .collection('study_rooms')
                                                .doc(_roomCode)
                                                .collection('member_requests')
                                                .doc(reqId)
                                                .update({'status': 'accepted'});
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 24),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('study_rooms')
                                                .doc(_roomCode)
                                                .collection('member_requests')
                                                .doc(reqId)
                                                .update({'status': 'rejected'});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Active Members Heading & Invite/Upload Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Active Members'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showAddMemberSheet(participants, creatorId),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: Text('Invite'.tr()),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _isUploadingProof
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton.icon(
                              onPressed: _uploadProofVoluntarily,
                              icon: const Icon(Icons.upload_file_rounded, size: 18),
                              label: Text('Upload My Proof'.tr()),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),

            // Active Members List
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final mId = participants[index];
                  final mName = participantNames[mId] ?? 'Anonymous';
                  final isMe = mId == user.uid;
                  final isAdmin = mId == creatorId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMe ? Colors.green.shade100 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: isMe ? Colors.green : Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      isMe ? '$mName (${'You'.tr()})' : mName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isAdmin ? 'Admin'.tr() : 'Member'.tr(),
                      style: TextStyle(fontSize: 12, color: isAdmin ? Colors.deepOrange : Colors.grey),
                    ),
                    trailing: isMe
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.deepPurpleAccent),
                            tooltip: 'Request Study Proof'.tr(),
                            onPressed: () => _requestProof(mId, mName),
                          ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Proof Gallery Heading
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('Study Proofs (Last 24h)'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),

            // Proofs Gallery Grid
            Expanded(
              flex: 3,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_rooms')
                    .doc(_roomCode)
                    .collection('proofs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, proofsSnap) {
                  if (proofsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allProofs = proofsSnap.data?.docs ?? [];
                  final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
                  final proofs = allProofs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['timestamp'] as Timestamp?;
                    if (timestamp == null) return true;
                    return timestamp.toDate().isAfter(twentyFourHoursAgo);
                  }).toList();

                  if (proofs.isEmpty) {
                    return Center(
                      child: Text(
                        'No proofs uploaded yet.'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: proofs.length,
                    itemBuilder: (context, index) {
                      final pData = proofs[index].data() as Map<String, dynamic>;
                      final senderName = pData['senderName'] ?? 'Someone';
                      final imageUrl = pData['imageUrl'] ?? '';
                      final timestamp = pData['timestamp'] as Timestamp?;
                      String timeStr = '';
                      if (timestamp != null) {
                        timeStr = DateFormat('hh:mm a').format(timestamp.toDate());
                      }

                      return GestureDetector(
                        onTap: () {
                          // Show enlarged photo dialog
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  imageUrl.startsWith('data:image/')
                                      ? Image.memory(
                                          base64Decode(imageUrl.split(',').last),
                                          fit: BoxFit.contain,
                                        )
                                      : Image.network(imageUrl, fit: BoxFit.contain),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      '${'Uploaded by'.tr()} $senderName ${'at'.tr()} $timeStr',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: _getProofImageProvider(imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  senderName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
        );
      },
    );
  }

  ImageProvider _getProofImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      final base64Str = imageUrl.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(imageUrl);
  }
}

// Stateful helper widget for 30 seconds countdown auto-dismissal
class ProofRequestBanner extends StatefulWidget {
  final DocumentSnapshot requestDoc;
  final Function(String) onUpload;

  const ProofRequestBanner({super.key, required this.requestDoc, required this.onUpload});

  @override
  State<ProofRequestBanner> createState() => _ProofRequestBannerState();
}

class _ProofRequestBannerState extends State<ProofRequestBanner> {
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() async {
    final data = widget.requestDoc.data() as Map<String, dynamic>? ?? {};
    final bool seen = data['seen'] ?? false;
    final Timestamp? seenAt = data['seenAt'] as Timestamp?;

    if (!seen) {
      // Mark as seen and initialize timer locally
      try {
        await widget.requestDoc.reference.update({
          'seen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Error updating seen status: $e");
      }
      _secondsLeft = 30;
    } else if (seenAt != null) {
      final elapsed = DateTime.now().difference(seenAt.toDate()).inSeconds;
      _secondsLeft = 30 - elapsed;
      if (_secondsLeft <= 0) {
        _secondsLeft = 0;
        _expireRequest();
        return;
      }
    } else {
      _secondsLeft = 30;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
          _expireRequest();
        }
      });
    });
  }

  Future<void> _expireRequest() async {
    try {
      await widget.requestDoc.reference.update({'status': 'expired'});
    } catch (e) {
      debugPrint("Error expiring request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) return const SizedBox.shrink();

    final data = widget.requestDoc.data() as Map<String, dynamic>? ?? {};
    final fromName = data['fromName'] ?? 'Someone';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade800.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.add_a_photo_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fromName ${'requested a study proof!'.tr()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'Camera capture only. Autodismiss in'.tr()} ${_secondsLeft}s',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => widget.onUpload(widget.requestDoc.id),
            icon: const Icon(Icons.camera_alt_rounded, size: 14),
            label: Text('Upload'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }
}

