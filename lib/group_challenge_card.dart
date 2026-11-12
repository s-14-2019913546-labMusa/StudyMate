import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'language_manager.dart';
import 'study_habits_service.dart';

/// স্টাডি গ্রুপ চ্যালেঞ্জ: গ্রুপের সাপ্তাহিক লক্ষ্য (মোট ঘণ্টা) আর সদস্যদের লিডারবোর্ড।
/// প্রত্যেকের এই সপ্তাহের মিনিট users/{uid}.weeklyStudyMinutes থেকে আসে (অ্যাপ খুললে হালনাগাদ হয়)।
class GroupChallengeCard extends StatefulWidget {
  final String groupId;
  final List<String> participants;
  final int? weeklyGoalMinutes;
  final bool isAdmin;

  const GroupChallengeCard({
    super.key,
    required this.groupId,
    required this.participants,
    required this.weeklyGoalMinutes,
    required this.isAdmin,
  });

  @override
  State<GroupChallengeCard> createState() => _GroupChallengeCardState();
}

class _Member {
  final String uid;
  final String name;
  final int minutes;
  _Member(this.uid, this.name, this.minutes);
}

class _GroupChallengeCardState extends State<GroupChallengeCard> {
  List<_Member>? _members;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GroupChallengeCard old) {
    super.didUpdateWidget(old);
    if (old.participants.length != widget.participants.length) _load();
  }

  Future<void> _load() async {
    // নিজের মিনিট আগে হালনাগাদ
    await StudyHabitsService.syncWeeklyMinutes();
    final week = StudyHabitsService.todayId(StudyHabitsService.weekStart(DateTime.now()));
    final list = <_Member>[];
    for (final uid in widget.participants) {
      try {
        final d = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data() ?? {};
        final sameWeek = d['weeklyStudyWeek'] == week;
        list.add(_Member(
          uid,
          (d['displayName'] ?? 'Study Buddy').toString(),
          sameWeek ? ((d['weeklyStudyMinutes'] as num?)?.toInt() ?? 0) : 0,
        ));
      } catch (_) {}
    }
    list.sort((a, b) => b.minutes.compareTo(a.minutes));
    if (mounted) setState(() => _members = list);
  }

  String _hm(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return trx('${h}h ${m}m', '$h ঘ $m মি');
  }

  Future<void> _setGoal() async {
    int hours = ((widget.weeklyGoalMinutes ?? widget.participants.length * 20 * 60) / 60).round();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(trx('Group goal for this week', 'এই সপ্তাহে গ্রুপের লক্ষ্য')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trx('$hours hours together', 'সবাই মিলে $hours ঘণ্টা'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Slider(
                value: hours.toDouble().clamp(5, 500),
                min: 5,
                max: 500,
                divisions: 99,
                onChanged: (v) => setD(() => hours = v.round()),
              ),
              Text(trx('About ${(hours / widget.participants.length).toStringAsFixed(1)} h per member',
                  'প্রতি সদস্য প্রায় ${(hours / widget.participants.length).toStringAsFixed(1)} ঘণ্টা')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel'.tr())),
            FilledButton(onPressed: () => Navigator.pop(ctx, hours), child: Text('Save'.tr())),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.groupId).set(
        {'weeklyGoalMinutes': picked * 60},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not save: $e', 'সেভ হয়নি: $e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members = _members;
    final goal = widget.weeklyGoalMinutes;
    final total = members?.fold<int>(0, (s, m) => s + m.minutes) ?? 0;
    final p = (goal == null || goal == 0) ? 0.0 : (total / goal).clamp(0.0, 1.0);
    final me = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(trx('Weekly challenge', 'সাপ্তাহিক চ্যালেঞ্জ'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (widget.isAdmin)
                  TextButton(onPressed: _setGoal, child: Text(goal == null ? trx('Set goal', 'লক্ষ্য দিন') : trx('Change', 'বদলান'))),
              ],
            ),
            if (goal == null)
              Text(
                widget.isAdmin
                    ? trx('Set a study goal for the whole group this week.', 'এই সপ্তাহে পুরো গ্রুপের পড়ার লক্ষ্য ঠিক করুন।')
                    : trx('The group admin can set a weekly goal.', 'গ্রুপ অ্যাডমিন সাপ্তাহিক লক্ষ্য ঠিক করতে পারবেন।'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              )
            else ...[
              const SizedBox(height: 4),
              Text('${_hm(total)} / ${_hm(goal)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 10,
                  color: p >= 1 ? Colors.green : scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              if (p >= 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(trx('🎉 Goal reached together!', '🎉 সবাই মিলে লক্ষ্য পূরণ!'),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
            ],
            const SizedBox(height: 12),
            Text(trx('Leaderboard (this week)', 'লিডারবোর্ড (এই সপ্তাহ)'),
                style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary, fontSize: 13)),
            const SizedBox(height: 6),
            if (members == null)
              const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
            else
              for (int i = 0; i < members.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}.', style: const TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        child: Text(
                          members[i].uid == me ? '${members[i].name} (${trx('you', 'আপনি')})' : members[i].name,
                          style: TextStyle(fontWeight: members[i].uid == me ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                      Text(_hm(members[i].minutes), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            const SizedBox(height: 4),
            Text(
              trx('Study time updates when each member opens the app.', 'প্রত্যেকে অ্যাপ খুললে তাঁর পড়ার সময় হালনাগাদ হয়।'),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
