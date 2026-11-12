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
// 1. Mood Tracker Bottom Sheet
// ==========================================
class MoodTrackerBottomSheet extends StatefulWidget {
  const MoodTrackerBottomSheet({super.key});
  @override
  State<MoodTrackerBottomSheet> createState() => _MoodTrackerBottomSheetState();
}

class _MoodTrackerBottomSheetState extends State<MoodTrackerBottomSheet> {
  final List<Map<String, String>> moods = [
    {'emoji': '😁', 'label': 'Great'},
    {'emoji': '😊', 'label': 'Good'},
    {'emoji': '😐', 'label': 'Okay'},
    {'emoji': '😔', 'label': 'Sad'},
    {'emoji': '😫', 'label': 'Stressed'},
  ];
  int _selectedMoodIndex = -1;
  final TextEditingController _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How are you feeling?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(moods.length, (index) {
              final isSelected = _selectedMoodIndex == index;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedMoodIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(moods[index]['emoji']!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(moods[index]['label']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Add a quick note (Optional)', prefixIcon: Icon(Icons.edit_note_rounded)),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context); // বর্তমান শিট বন্ধ করে হিস্ট্রি শিট ওপেন করবে
              showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => const MoodHistoryBottomSheet());
            },
            icon: const Icon(Icons.history_rounded),
            label: const Text('View Mood History'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (_selectedMoodIndex == -1) {
                ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please select a mood!'.tr())));
                return;
              }
              
              final User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('moods').add({
                    'emoji': moods[_selectedMoodIndex]['emoji'],
                    'label': moods[_selectedMoodIndex]['label'],
                    'note': _noteController.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Mood saved successfully!'.tr())));
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error saving mood. Please check Firebase rules!'.tr())));
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please log in first.'.tr())));
              }
            },
            child: const Text('Save Mood'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1.A Mood History Bottom Sheet
// ==========================================
class MoodHistoryBottomSheet extends StatelessWidget {
  const MoodHistoryBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mood History', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: user == null
                ? const Center(child: Text("Please log in to view history"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('moods')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No mood history yet.", style: TextStyle(color: Colors.grey)));
                      }

                      // ডাটা গ্রুপিং লজিক (Today, Yesterday, বা Month অনুযায়ী)
                      Map<String, List<Map<String, dynamic>>> historyData = {};
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final yesterday = today.subtract(const Duration(days: 1));

                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['timestamp'] as Timestamp?;
                        final date = timestamp != null ? timestamp.toDate() : DateTime.now();
                        final dateOnly = DateTime(date.year, date.month, date.day);

                        String groupKey;
                        if (dateOnly == today) {
                          groupKey = 'Today';
                        } else if (dateOnly == yesterday) {
                          groupKey = 'Yesterday';
                        } else {
                          groupKey = DateFormat('MMMM yyyy').format(date); // e.g. October 2023
                        }

                        if (!historyData.containsKey(groupKey)) {
                          historyData[groupKey] = [];
                        }
                        
                        historyData[groupKey]!.add({
                          'date': DateFormat('MMM d, h:mm a').format(date),
                          'emoji': data['emoji'] ?? '',
                          'note': data['note'] ?? '',
                        });
                      }

                      return ListView.builder(
                        itemCount: historyData.keys.length,
                        itemBuilder: (context, index) {
                          String section = historyData.keys.elementAt(index);
                          List<Map<String, dynamic>> items = historyData[section]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(section, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              ...items.map((item) => Card(
                                    child: ListTile(
                                      leading: Text(item['emoji'], style: const TextStyle(fontSize: 28)),
                                      title: Text(item['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      subtitle: item['note'].toString().isNotEmpty
                                          ? Text(item['note'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87))
                                          : null,
                                    ),
                                  )),
                              const SizedBox(height: 16),
                            ],
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

