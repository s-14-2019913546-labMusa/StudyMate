import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../language_manager.dart';

/// Study Room-এ সবার জন্য একটাই Pomodoro টাইমার।
/// রুমের ডকুমেন্টে 'liveTimer' = {startedAt, minutes, startedBy, startedByName, joined: [uid]}
/// সবার ফোনে একই সময় দেখায় (সার্ভারের সময় ধরে), কে এখন পড়ছে তাও দেখা যায়।
class LiveRoomTimer extends StatefulWidget {
  final String roomCode;
  final Map<String, dynamic> roomData;
  final Map<String, dynamic> participantNames;

  const LiveRoomTimer({
    super.key,
    required this.roomCode,
    required this.roomData,
    required this.participantNames,
  });

  @override
  State<LiveRoomTimer> createState() => _LiveRoomTimerState();
}

class _LiveRoomTimerState extends State<LiveRoomTimer> {
  Timer? _tick;
  String? _creditedSession; // কোন সেশনের জন্য গাছ লাগানো হয়ে গেছে

  DocumentReference<Map<String, dynamic>> get _room =>
      FirebaseFirestore.instance.collection('study_rooms').doc(widget.roomCode);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _timer {
    final t = widget.roomData['liveTimer'];
    return t is Map ? Map<String, dynamic>.from(t) : null;
  }

  Future<void> _start(int minutes) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await _room.update({
      'liveTimer': {
        'startedAt': FieldValue.serverTimestamp(),
        'minutes': minutes,
        'startedBy': u.uid,
        'startedByName': u.displayName ?? 'Study Buddy',
        'joined': [u.uid],
      },
    });
  }

  Future<void> _join() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await _room.update({'liveTimer.joined': FieldValue.arrayUnion([u.uid])});
  }

  Future<void> _leave() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await _room.update({'liveTimer.joined': FieldValue.arrayRemove([u.uid])});
  }

  Future<void> _stop() async {
    await _room.update({'liveTimer': FieldValue.delete()});
  }

  /// সেশন শেষ হলে যারা যোগ দিয়েছিলেন তাঁদের নিজের "বন"-এ একটা গাছ (পড়ার সময়ে গোনা হয়)
  Future<void> _creditIfDone(String sessionKey, int minutes, bool joined) async {
    if (!joined || _creditedSession == sessionKey) return;
    _creditedSession = sessionKey;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .collection('pomodoroForest')
          .doc('trees')
          .collection('list')
          .doc('room_$sessionKey')
          .set({'plantedAt': FieldValue.serverTimestamp(), 'type': '🌳', 'sessionMinutes': minutes, 'room': widget.roomCode});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trx('Group session done! $minutes min added to your study time 🌳', 'গ্রুপ সেশন শেষ! আপনার পড়ার সময়ে $minutes মিনিট যোগ হলো 🌳')),
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = FirebaseAuth.instance.currentUser?.uid;
    final t = _timer;
    final startedAt = (t?['startedAt'] as Timestamp?)?.toDate();
    final minutes = (t?['minutes'] as num?)?.toInt() ?? 25;
    final joined = List<String>.from(t?['joined'] ?? []);
    final iJoined = joined.contains(me);

    Widget body;
    if (t == null || startedAt == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trx('No group session running', 'এখন কোনো গ্রুপ সেশন চলছে না'),
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _start(25),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(trx('Start 25 min', '২৫ মিনিট শুরু')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _start(50),
                  child: Text(trx('50 min', '৫০ মিনিট')),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      final end = startedAt.add(Duration(minutes: minutes));
      final left = end.difference(DateTime.now());
      final done = left.isNegative;
      if (done) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _creditIfDone('${startedAt.millisecondsSinceEpoch}', minutes, iJoined));
      }
      final secs = done ? 0 : left.inSeconds;
      final mm = (secs ~/ 60).toString().padLeft(2, '0');
      final ss = (secs % 60).toString().padLeft(2, '0');
      final progress = done ? 1.0 : 1 - secs / (minutes * 60);
      final names = joined.map((u) => (widget.participantNames[u] ?? 'Study Buddy').toString()).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(done ? trx('Done!', 'শেষ!') : '$mm:$ss',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: done ? Colors.green : scheme.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trx('Started by ${t['startedByName']} · $minutes min', '${t['startedByName']} শুরু করেছেন · $minutes মিনিট'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          const SizedBox(height: 10),
          Text(trx('Studying now (${names.length}):', 'এখন পড়ছেন (${names.length} জন):'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final n in names)
                Chip(
                  avatar: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text(n, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!done && !iJoined)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _join,
                    icon: const Icon(Icons.group_add_rounded),
                    label: Text(trx('Join', 'যোগ দিন')),
                  ),
                ),
              if (!done && iJoined)
                Expanded(
                  child: OutlinedButton(onPressed: _leave, child: Text(trx('Leave session', 'সেশন ছাড়ুন'))),
                ),
              if (done || t['startedBy'] == me || widget.roomData['creatorId'] == me) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: _stop, child: Text(done ? trx('Clear', 'মুছুন') : trx('Stop for all', 'সবার জন্য থামান'))),
              ],
            ],
          ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded),
                const SizedBox(width: 8),
                Text(trx('Live group Pomodoro', 'লাইভ গ্রুপ Pomodoro'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }
}
