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

// ==========================================
// 8. Partner Tasks Screen (পার্টনার অপশন)
// ==========================================
class PartnerTasksScreen extends StatefulWidget {
  const PartnerTasksScreen({super.key});

  @override
  State<PartnerTasksScreen> createState() => _PartnerTasksScreenState();
}

class _PartnerTasksScreenState extends State<PartnerTasksScreen> {
  bool _inRoom = false;
  String _roomCode = '';
  String? _selectedPartnerId;
  final TextEditingController _joinCodeCtrl = TextEditingController();
  final TextEditingController _roomNameCtrl = TextEditingController();

  bool _isWarningDialogShowing = false;

  void _checkAnalyticsAndWarnings(User user, List<QueryDocumentSnapshot> taskDocs, Map<String, dynamic> roomData) {
    if (taskDocs.isEmpty) {
      final warningsMap = roomData['warnings'] as Map<String, dynamic>? ?? {};
      if (warningsMap[user.uid] != null) {
        _resetWarningCount(user.uid);
      }
      return;
    }

    // 1. Check who has completed >= 80% of ALL tasks in the room
    final participants = List<String>.from(roomData['participants'] ?? []);
    int helpersWith80Percent = 0;
    
    for (final pId in participants) {
      final completed = taskDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final completedUsers = List<String>.from(data['completedUsers'] ?? []);
        final oldIsCompleted = data['isCompleted'] ?? false;
        final oldCompletedBy = data['completedBy'];
        return completedUsers.contains(pId) || (oldIsCompleted && oldCompletedBy == pId);
      }).length;
      
      final rate = completed / taskDocs.length;
      if (rate >= 0.8) {
        helpersWith80Percent++;
      }
    }

    final completedCount = taskDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final completedUsers = List<String>.from(data['completedUsers'] ?? []);
      final oldIsCompleted = data['isCompleted'] ?? false;
      final oldCompletedBy = data['completedBy'];
      return completedUsers.contains(user.uid) || (oldIsCompleted && oldCompletedBy == user.uid);
    }).length;

    final completionRate = completedCount / taskDocs.length;

    final warningsMap = roomData['warnings'] as Map<String, dynamic>? ?? {};
    final userWarningData = warningsMap[user.uid] as Map<String, dynamic>?;

    if (completionRate >= 0.8) {
      if (userWarningData != null && (userWarningData['count'] ?? 0) > 0) {
        _resetWarningCount(user.uid);
      }
      return;
    }

    // 2. Check if warning system should be active (at least 2 people completed >= 80%)
    if (helpersWith80Percent < 2) {
      // Warning system is inactive because less than 2 people reached 80%
      if (userWarningData != null && (userWarningData['count'] ?? 0) > 0) {
        _resetWarningCount(user.uid);
      }
      return;
    }

    // Otherwise, completion rate is < 80% and warning system is active!
    int warningCount = userWarningData?['count'] ?? 0;
    DateTime? lastWarningTime;
    if (userWarningData?['lastWarningTime'] != null) {
      lastWarningTime = DateTime.tryParse(userWarningData!['lastWarningTime']);
    }

    final now = DateTime.now();

    if (warningCount == 0) {
      _showWarningPopup(user.uid, 1, now);
    } else if (warningCount < 3) {
      if (lastWarningTime != null && now.difference(lastWarningTime).inHours >= 3) {
        _showWarningPopup(user.uid, warningCount + 1, now);
      }
    } else {
      if (lastWarningTime != null && now.difference(lastWarningTime).inHours >= 3) {
        _kickOutUser(user.uid, user.displayName ?? 'Anonymous');
      }
    }
  }

  void _showWarningPopup(String userId, int count, DateTime now) async {
    if (_isWarningDialogShowing) return;
    _isWarningDialogShowing = true;

    await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
      'warnings.$userId.count': count,
      'warnings.$userId.lastWarningTime': now.toIso8601String(),
    });

    if (!mounted) {
      _isWarningDialogShowing = false;
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            '${'Warning'.tr()} ($count/3)',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have not completed 80% of your shared tasks. Please complete them. If you still do not complete them after being warned 3 times every 3 hours, you will be removed from this partner space.'.tr()
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _isWarningDialogShowing = false;
              },
              child: Text('OK'.tr()),
            ),
          ],
        );
      }
    ).then((_) {
      _isWarningDialogShowing = false;
    });
  }

  void _resetWarningCount(String userId) async {
    await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
      'warnings.$userId': FieldValue.delete(),
    });
  }

  void _kickOutUser(String userId, String userName) async {
    await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
      'participants': FieldValue.arrayRemove([userId]),
      'participantNames.$userId': FieldValue.delete(),
      'warnings.$userId': FieldValue.delete(),
    });
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _createSpace() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String name = _roomNameCtrl.text.trim();
    if (name.isEmpty) {
      name = '${user.displayName ?? 'Student'}\'s Partner Space';
    }

    final code = 'PR-${_generateRoomCode()}';

    try {
      await FirebaseFirestore.instance.collection('partner_rooms').doc(code).set({
        'roomId': code,
        'name': name,
        'creatorId': user.uid,
        'creatorName': user.displayName ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [user.uid],
        'participantNames': {user.uid: user.displayName ?? 'Anonymous'},
      });

      setState(() {
        _roomCode = code;
        _inRoom = true;
        _roomNameCtrl.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Space $code created!', '$code স্পেস তৈরি হয়েছে!'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error: $e', 'সমস্যা: $e'))));
      }
    }
  }

  Future<void> _joinSpace() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('partner_rooms').doc(code).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Partner Space not found!'.tr())));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('partner_rooms').doc(code).update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'participantNames.${user.uid}': user.displayName ?? 'Anonymous',
      });

      setState(() {
        _roomCode = code;
        _inRoom = true;
        _joinCodeCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error: $e', 'সমস্যা: $e'))));
      }
    }
  }

  Future<void> _leaveSpace() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _cleanupLocalHistoryForRoom(_roomCode, user.uid);
      await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
        'participants': FieldValue.arrayRemove([user.uid]),
      });
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
    } catch (e) {
      setState(() {
        _inRoom = false;
        _roomCode = '';
      });
    }
  }

  Future<void> _confirmAddPartner(String friendId, String friendName, bool isAdmin, List<String> currentParticipants) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (currentParticipants.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partner Space is full (Maximum 4 partners).'.tr())),
        );
      }
      return;
    }

    final title = isAdmin ? 'Add Partner (পার্টনার যুক্ত করুন)'.tr() : 'Request Partner (পার্টনার রিকোয়েস্ট)'.tr();
    final message = isAdmin
        ? 'Do you want to add $friendName directly as a partner in this space?'.tr()
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: Text('Yes'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isAdmin) {
        await _addPartnerDirectly(friendId, friendName);
      } else {
        // Send request to Admin
        try {
          await FirebaseFirestore.instance
              .collection('partner_rooms')
              .doc(_roomCode)
              .collection('member_requests')
              .add({
            'invitedId': friendId,
            'invitedName': friendName,
            'requesterId': user.uid,
            'requesterName': user.displayName ?? 'Anonymous',
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Request sent to Admin to add $friendName.'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send request: $e'.tr())),
            );
          }
        }
      }
    }
  }

  Future<void> _addPartnerDirectly(String friendId, String friendName) async {
    try {
      await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
        'participants': FieldValue.arrayUnion([friendId]),
        'participantNames.$friendId': friendName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Added $friendName as partner!', '$friendName-কে পার্টনার হিসেবে যোগ করা হয়েছে!'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error: $e', 'সমস্যা: $e'))));
      }
    }
  }

  void _showAddPartnerSheet(List<String> currentParticipants, String creatorId) {
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
                  Text('Add a Partner'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
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
                              return const ListTile(
                                leading: CircleAvatar(child: Icon(Icons.person)),
                                title: Text('Loading Buddy...'),
                              );
                            }

                            final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final fName = userData['displayName'] ?? 'Study Buddy';
                            final photoUrl = userData['photoUrl'] as String?;
                            ImageProvider? avatarImage;
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              avatarImage = photoUrl.startsWith('http')
                                  ? NetworkImage(photoUrl)
                                  : FileImage(File(photoUrl)) as ImageProvider;
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatarImage,
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: avatarImage == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
                              ),
                              title: Text(fName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add_rounded, color: Colors.green),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmAddPartner(fId, fName, user.uid == creatorId, currentParticipants);
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

  Future<List<Task>> _fetchUserRoutineTasks(String userId) async {
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayOfWeek = DateFormat('EEEE').format(DateTime.now());

    List<Task> dailyTasks = [];
    try {
      final dailyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dailyRoutines')
          .doc(todayDate)
          .get();

      if (dailyDoc.exists) {
        final data = dailyDoc.data() as Map<String, dynamic>;
        if (data['tasks'] != null) {
          for (var taskMap in data['tasks']) {
            dailyTasks.add(Task.fromMap(taskMap, taskMap['id'] ?? UniqueKey().toString()));
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching daily routine tasks: $e");
    }

    List<Task> weeklyTasks = [];
    try {
      final weeklySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('weeklyRoutines')
          .doc(dayOfWeek)
          .collection('tasks')
          .get();

      for (var doc in weeklySnap.docs) {
        weeklyTasks.add(Task.fromMap(doc.data(), doc.id));
      }
    } catch (e) {
      debugPrint("Error fetching weekly tasks: $e");
    }

    return [...dailyTasks, ...weeklyTasks];
  }

  Future<void> _showPartnersTasksSheet(List<String> participants, Map<String, dynamic> participantNames) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final otherPartners = participants.where((id) => id != user.uid).toList();
    if (otherPartners.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No other partners in this space yet.'.tr())),
        );
      }
      return;
    }

    // Default select first partner if not set
    if (_selectedPartnerId == null || !otherPartners.contains(_selectedPartnerId)) {
      _selectedPartnerId = otherPartners.first;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Partners' Tasks (পার্টনারদের টাস্ক)".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Select Partner list
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: otherPartners.length,
                      itemBuilder: (ctx, idx) {
                        final pId = otherPartners[idx];
                        final pName = participantNames[pId] ?? 'Partner';
                        final isSelected = _selectedPartnerId == pId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(pName),
                            selected: isSelected,
                            onSelected: (val) {
                              setModalState(() {
                                _selectedPartnerId = pId;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _selectedPartnerId == null
                        ? Center(child: Text('Select a partner to view tasks.'.tr(), style: const TextStyle(color: Colors.grey)))
                        : FutureBuilder<List<Task>>(
                            future: _fetchUserRoutineTasks(_selectedPartnerId!),
                            builder: (ctx, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final tasks = snap.data ?? [];
                              if (tasks.isEmpty) {
                                return Center(
                                  child: Text('No routine tasks found for this partner today.'.tr(), style: const TextStyle(color: Colors.grey)),
                                );
                              }

                              return ListView.builder(
                                itemCount: tasks.length,
                                itemBuilder: (ctx, idx) {
                                  final t = tasks[idx];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('${t.totalDurationMinutes} ${'mins'.tr()}'),
                                      trailing: ElevatedButton.icon(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('partner_rooms')
                                              .doc(_roomCode)
                                              .collection('tasks')
                                              .add({
                                            'title': t.title,
                                            'totalDurationMinutes': t.totalDurationMinutes,
                                            'isCompleted': false,
                                            'createdBy': user.uid,
                                            'createdByName': user.displayName ?? 'Anonymous',
                                            'timestamp': FieldValue.serverTimestamp(),
                                            'subject': t.subject,
                                            'notes': t.notes,
                                            'topic': t.topic,
                                            'challenges': t.challenges,
                                            'category': t.category,
                                            'startTime': t.startTime != null ? Timestamp.fromDate(t.startTime!) : null,
                                            'endTime': t.endTime != null ? Timestamp.fromDate(t.endTime!) : null,
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Added to space: ${t.title}'.tr())),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.add, size: 14),
                                        label: Text('Add'.tr()),
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
          },
        );
      },
    );
  }

  void _showAddTaskOptions(Map<String, dynamic> participantNames) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Shared Task'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add_task_rounded, color: Colors.green),
                title: Text('Create New Task'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateTaskDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_export_rounded, color: Colors.blue),
                title: Text('Import Tasks'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportTasksSheet(participantNames);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateTaskDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTaskBottomSheet(
        title: 'Add Shared Task'.tr(),
        submitButtonText: 'Save'.tr(),
        onTaskAdded: (newTask) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          
          await FirebaseFirestore.instance
              .collection('partner_rooms')
              .doc(_roomCode)
              .collection('tasks')
              .add({
            'title': newTask.title,
            'subject': newTask.subject,
            'topic': newTask.topic,
            'challenges': newTask.challenges,
            'notes': newTask.notes,
            'startTime': newTask.startTime != null ? Timestamp.fromDate(newTask.startTime!) : null,
            'endTime': newTask.endTime != null ? Timestamp.fromDate(newTask.endTime!) : null,
            'isPrivate': newTask.isPrivate,
            'category': newTask.category,
            'totalDurationMinutes': newTask.totalDurationMinutes,
            'isCompleted': false,
            'createdBy': user.uid,
            'createdByName': user.displayName ?? 'Anonymous',
            'timestamp': FieldValue.serverTimestamp(),
          });
        },
      ),
    );
  }

  void _showImportTasksSheet(Map<String, dynamic> participantNames) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => MultiTaskImportSheet(
        roomCode: _roomCode,
        participantNames: participantNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partner Tasks')),
        body: const Center(child: Text('Please log in to use Partner Tasks.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_inRoom ? 'Partner Tasks Space: $_roomCode' : 'Partner Tasks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _inRoom
            ? [
                IconButton(
                  tooltip: 'Leave Space',
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  onPressed: _leaveSpace,
                )
              ]
            : null,
      ),
      body: _inRoom ? _buildSpaceUI(user) : _buildJoinCreateUI(user),
      floatingActionButton: null,
    );
  }

  Widget _buildJoinCreateUI(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(Icons.group_add_rounded, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Study Partner Space'.tr(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Join or create a space to share tasks and study with your partners.'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),

          // Create Space Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Partner Space'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter Space name (optional)'.tr(),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _createSpace,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text('Create Partner Space'.tr()),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Join Space Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Partner Space'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _joinCodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter Space Code (e.g. PR-XXXXXX)'.tr(),
                      prefixIcon: const Icon(Icons.meeting_room_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _joinSpace,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                    child: Text('Join Space'.tr()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Your Spaces Section
          Text('Your Spaces'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('partner_rooms')
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
                      'You are not in any spaces yet.'.tr(),
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
                  final name = roomData['name'] ?? 'Partner Space';
                  final code = roomData['roomId'] ?? '';
                  final participants = List<String>.from(roomData['participants'] ?? []);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.group_work_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${'Code:'.tr()} $code • ${participants.length} ${'partners'.tr()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Space code copied!'.tr())));
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

  Widget _buildSpaceUI(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).snapshots(),
      builder: (context, roomSnap) {
        if (roomSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!roomSnap.hasData || !roomSnap.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Space not found or has been deleted.'.tr()),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _inRoom = false;
                    _roomCode = '';
                  }),
                  child: Text('Go Back'.tr()),
                )
              ],
            ),
          );
        }

        final roomData = roomSnap.data!.data() as Map<String, dynamic>;
        final creatorId = roomData['creatorId'] ?? '';
        final participants = List<String>.from(roomData['participants'] ?? []);
        final participantNames = Map<String, dynamic>.from(roomData['participantNames'] ?? {});
        final isCreator = user.uid == creatorId;

        if (!participants.contains(user.uid)) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && _inRoom) {
              await _cleanupLocalHistoryForRoom(_roomCode, user.uid);
              setState(() {
                _inRoom = false;
                _roomCode = '';
              });
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: Text('Removed'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: Text('You have been removed from this partner space for not completing 80% of your tasks on time. To enter again, you must obtain the code and join again.'.tr()),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('OK'.tr()),
                    ),
                  ],
                ),
              );
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('partner_rooms')
              .doc(_roomCode)
              .collection('tasks')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, tasksSnap) {
            if (tasksSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final taskDocs = tasksSnap.data?.docs ?? [];
            final pendingTaskDocs = <QueryDocumentSnapshot>[];
            final completedTaskDocs = <QueryDocumentSnapshot>[];

            for (final doc in taskDocs) {
              final tData = doc.data() as Map<String, dynamic>;
              final completedUsers = List<String>.from(tData['completedUsers'] ?? []);
              final oldIsCompleted = tData['isCompleted'] ?? false;
              final oldCompletedBy = tData['completedBy'];
              
              final isCompletedByMe = completedUsers.contains(user.uid) || 
                  (oldIsCompleted && oldCompletedBy == user.uid);

              if (isCompletedByMe) {
                completedTaskDocs.add(doc);
              } else {
                pendingTaskDocs.add(doc);
              }
            }

            // Trigger analytic check for 80% completion warnings / kick-out
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkAnalyticsAndWarnings(user, taskDocs, roomData);
              }
            });

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pending Requests Card (Admin only)
                if (isCreator)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('partner_rooms')
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
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                                  Expanded(
                                    child: Text(
                                    'New Partner Requests (নতুন পার্টনার রিকোয়েস্ট)'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
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
                                  final requesterName = reqData['requesterName'] ?? 'Partner';

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
                                                if (participants.length >= 4) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Cannot accept. Partner Space is full (Maximum 4 partners).'.tr())),
                                                  );
                                                  return;
                                                }
                                                await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
                                                  'participants': FieldValue.arrayUnion([invitedId]),
                                                  'participantNames.$invitedId': invitedName,
                                                });
                                                await FirebaseFirestore.instance
                                                    .collection('partner_rooms')
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
                                                    .collection('partner_rooms')
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

                // Partners Header Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${'Space Code:'.tr()} $_roomCode', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${'Study Partners'.tr()} (${participants.length}/4)', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton.filled(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _roomCode));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Space code copied!'.tr())));
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                              ),
                              if (participants.length < 4)
                                TextButton.icon(
                                  onPressed: () => _showAddPartnerSheet(participants, creatorId),
                                  icon: const Icon(Icons.person_add_rounded, size: 18),
                                  label: Text('Add'.tr()),
                                )
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: participants.map((mId) {
                          final mName = participantNames[mId] ?? 'Partner';
                          final isMe = mId == user.uid;

                          // Calculate percentage for this member (out of all tasks)
                          String percentStr = '0%';
                          if (taskDocs.isNotEmpty) {
                            final completed = taskDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final completedUsers = List<String>.from(data['completedUsers'] ?? []);
                              final oldIsCompleted = data['isCompleted'] ?? false;
                              final oldCompletedBy = data['completedBy'];
                              return completedUsers.contains(mId) || (oldIsCompleted && oldCompletedBy == mId);
                            }).length;
                            final percent = (completed / taskDocs.length * 100).toStringAsFixed(0);
                            percentStr = '$percent%';
                          }

                          final displayNameWithPercent = isMe
                              ? '$mName (${'You'.tr()}) - $percentStr'
                              : '$mName - $percentStr';

                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Chip(
                              avatar: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary)),
                              label: Text(displayNameWithPercent, overflow: TextOverflow.ellipsis, maxLines: 1),
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              side: BorderSide.none,
                              onDeleted: (isCreator && !isMe)
                                  ? () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Remove Partner (পার্টনার রিমুভ করুন)'.tr()),
                                          content: Text('Are you sure you want to remove $mName from this space?'.tr()),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No'.tr())),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: Text('Yes'.tr()),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await FirebaseFirestore.instance.collection('partner_rooms').doc(_roomCode).update({
                                          'participants': FieldValue.arrayRemove([mId]),
                                          'participantNames.$mId': FieldValue.delete(),
                                        });
                                      }
                                    }
                                  : null,
                              deleteIcon: (isCreator && !isMe) ? const Icon(Icons.cancel, size: 16, color: Colors.red) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Shared Tasks Heading
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Shared Tasks for the Room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (isCreator)
                        TextButton.icon(
                          onPressed: () => _showPartnersTasksSheet(participants, participantNames),
                          icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                          label: Text("Partners' Tasks".tr()),
                        ),
                    ],
                  ),
                ),

                // Tasks List
                Expanded(
                  child: taskDocs.isEmpty
                      ? Center(child: Text('No shared tasks yet. Add one!'.tr(), style: const TextStyle(color: Colors.grey)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            if (pendingTaskDocs.isNotEmpty) ...[
                              Text('Active Tasks'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.primary)),
                              const SizedBox(height: 8),
                              ...pendingTaskDocs.map((doc) => _buildSpaceTaskItem(doc, participants, participantNames, user, isCreator)),
                            ] else if (completedTaskDocs.isNotEmpty) ...[
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.stars_rounded, size: 48, color: Colors.green.shade400),
                                      const SizedBox(height: 8),
                                      Text(
                                        'All tasks completed!'.tr(),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            if (completedTaskDocs.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  title: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${'Done Tasks'.tr()} (${completedTaskDocs.length})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 14, 
                                            color: Colors.green.shade700
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  childrenPadding: EdgeInsets.zero,
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                                  children: completedTaskDocs.map((doc) => _buildSpaceTaskItem(doc, participants, participantNames, user, isCreator)).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
              floatingActionButton: isCreator
                  ? FloatingActionButton.extended(
                      onPressed: () => _showAddTaskOptions(participantNames),
                      icon: const Icon(Icons.add),
                      label: Text('Add Task'.tr()),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildSpaceTaskItem(
    QueryDocumentSnapshot doc, 
    List<String> participants, 
    Map<String, dynamic> participantNames,
    User user,
    bool isCreator
  ) {
    final tData = doc.data() as Map<String, dynamic>;
    final completedUsers = List<String>.from(tData['completedUsers'] ?? []);
    final oldIsCompleted = tData['isCompleted'] ?? false;
    final oldCompletedBy = tData['completedBy'];
    
    final isCompletedByMe = completedUsers.contains(user.uid) || 
        (oldIsCompleted && oldCompletedBy == user.uid);
        
    final completedOtherNames = <String>[];
    for (final mId in participants) {
      if (mId == user.uid) continue;
      final isCompletedByOther = completedUsers.contains(mId) || 
          (oldIsCompleted && oldCompletedBy == mId);
      if (isCompletedByOther) {
        completedOtherNames.add(participantNames[mId] ?? 'Partner');
      }
    }

    final baseTask = Task.fromMap(tData, 'partner_${_roomCode}_${isCreator ? 'admin' : 'member'}_${doc.id}');
    final resolvedStatus = isCompletedByMe 
        ? 'completed' 
        : (baseTask.status == 'completed' ? 'pending' : baseTask.status);
    final taskObj = baseTask.copyWith(
      isCompleted: isCompletedByMe,
      status: resolvedStatus,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActiveTaskCard(
              task: taskObj,
              onUpdate: (updatedTask) async {
                final Map<String, dynamic> updateData = updatedTask.toMap();
                updateData['id'] = doc.id;
                
                String cleanTitle = updatedTask.title;
                final suffix = ' (${'P Task'.tr()})';
                if (cleanTitle.endsWith(suffix)) {
                  cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length);
                }
                updateData['title'] = cleanTitle;

                updateData['completedUsers'] = completedUsers;
                if (updatedTask.isCompleted || updatedTask.status == 'completed') {
                  if (!completedUsers.contains(user.uid)) {
                    completedUsers.add(user.uid);
                  }
                  updateData['completedUsers'] = completedUsers;
                  updateData['isCompleted'] = false;
                  updateData['status'] = 'completed';
                  await _addPartnerTaskToLocalHistory(user.uid, updatedTask, isCompleted: true);
                } else {
                  if (completedUsers.contains(user.uid)) {
                    completedUsers.remove(user.uid);
                  }
                  updateData['completedUsers'] = completedUsers;
                  updateData['isCompleted'] = false;
                  updateData['status'] = updatedTask.status == 'completed' ? 'pending' : updatedTask.status;
                  await _addPartnerTaskToLocalHistory(user.uid, updatedTask, isCompleted: false);
                }
                await doc.reference.update(updateData);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, right: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompletedByMe)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'You have done this task'.tr(),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (completedOtherNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${completedOtherNames.join(', ')} ${'done this task'.tr()}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPartnerTaskToLocalHistory(String userId, Task task, {required bool isCompleted}) async {
    final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('dailyRoutines')
        .doc(todayDocId);

    final suffix = ' (${'P Task'.tr()})';
    String cleanTitle = task.title;
    if (cleanTitle.endsWith(suffix)) {
      cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length);
    }
    final historyTitle = '$cleanTitle$suffix';
    
    final localTask = task.copyWith(
      title: historyTitle,
      subject: task.subject != null ? '${task.subject}$suffix' : null,
      isCompleted: isCompleted,
      status: isCompleted ? 'completed' : 'pending',
    );

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final routine = DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
      int index = routine.tasks.indexWhere((t) => t.id == localTask.id);
      if (index != -1) {
        routine.tasks[index] = localTask;
      } else {
        routine.tasks.add(localTask);
      }
      await docRef.update({'tasks': routine.tasks.map((t) => t.toMap()).toList()});
    } else {
      final newRoutine = DailyRoutine(
        id: todayDocId,
        userId: userId,
        date: DateTime.now(),
        tasks: [localTask],
      );
      await docRef.set(newRoutine.toMap());
    }
  }

  Future<void> _cleanupLocalHistoryForRoom(String roomCode, String userId) async {
    try {
      final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dailyRoutines')
          .doc(todayDocId);

      final snapshot = await docRef.get();
      if (snapshot.exists) {
        DailyRoutine routine = DailyRoutine.fromMap(snapshot.data()!, snapshot.id);
        final prefix = 'partner_${roomCode}_';
        routine.tasks.removeWhere((t) => t.id.startsWith(prefix));
        await docRef.update({'tasks': routine.tasks.map((t) => t.toMap()).toList()});
      }
    } catch (e) {
      debugPrint("Error cleaning up local history for room $roomCode: $e");
    }
  }
}

