import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'language_manager.dart';
import 'widgets/empty_state.dart';
import 'widgets/skeleton.dart';

/// প্রশ্ন-উত্তর ফোরাম: কঠিন প্রশ্ন পোস্ট করুন, অন্যরা উত্তর দেবেন।
/// forum_posts/{postId} এবং forum_posts/{postId}/answers/{answerId}
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

const _forumSubjects = ['বাংলা', 'English', 'গণিত', 'বাংলাদেশ', 'আন্তর্জাতিক', 'বিজ্ঞান', 'আইসিটি', 'অন্যান্য'];

String _ago(Timestamp? ts) {
  if (ts == null) return '';
  final d = DateTime.now().difference(ts.toDate());
  if (d.inMinutes < 1) return trx('just now', 'এইমাত্র');
  if (d.inHours < 1) return trx('${d.inMinutes} min ago', '${d.inMinutes} মিনিট আগে');
  if (d.inDays < 1) return trx('${d.inHours} h ago', '${d.inHours} ঘণ্টা আগে');
  if (d.inDays < 7) return trx('${d.inDays} d ago', '${d.inDays} দিন আগে');
  return DateFormat('d MMM yyyy').format(ts.toDate());
}

class _ForumScreenState extends State<ForumScreen> {
  String? _subject;
  bool _unansweredOnly = false;
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _query {
    // বিষয় দিয়ে ছাঁকা ফোনেই হয়, যাতে Firestore-এ আলাদা index বানাতে না হয়
    return FirebaseFirestore.instance.collection('forum_posts').orderBy('createdAt', descending: true).limit(200);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(trx('Q&A Forum', 'প্রশ্ন-উত্তর ফোরাম'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _AskSheet(),
        ),
        icon: const Icon(Icons.help_outline_rounded),
        label: Text(trx('Ask', 'প্রশ্ন করুন')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: trx('Search questions', 'প্রশ্ন খুঁজুন'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(trx('Unanswered', 'উত্তর নেই')),
                    selected: _unansweredOnly,
                    onSelected: (v) => setState(() => _unansweredOnly = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(trx('All', 'সব')),
                    selected: _subject == null,
                    onSelected: (_) => setState(() => _subject = null),
                  ),
                ),
                for (final s in _forumSubjects)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(label: Text(s), selected: _subject == s, onSelected: (_) => setState(() => _subject = s)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        trx('The forum could not load. The Firestore rules need the forum_posts block (see docs/firestore-rules-additions.md).\n\n${snap.error}',
                            'ফোরাম লোড হয়নি। Firestore rules-এ forum_posts-এর অংশ যোগ করতে হবে (docs/firestore-rules-additions.md দেখুন)।\n\n${snap.error}'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) return const SkeletonCardList();
                var docs = snap.data!.docs;
                if (_subject != null) docs = docs.where((d) => d.data()['subject'] == _subject).toList();
                if (_unansweredOnly) docs = docs.where((d) => ((d.data()['answerCount'] as num?) ?? 0) == 0).toList();
                if (_q.isNotEmpty) {
                  docs = docs
                      .where((d) => '${d.data()['title']} ${d.data()['body']}'.toLowerCase().contains(_q))
                      .toList();
                }
                if (docs.isEmpty) {
                  return EmptyStateGuide(
                    icon: Icons.forum_rounded,
                    title: trx('No questions here yet', 'এখানে এখনো কোনো প্রশ্ন নেই'),
                    message: trx('Stuck on something? Ask it here and other students can answer.',
                        'কোথাও আটকে গেছেন? এখানে প্রশ্ন করুন, অন্য শিক্ষার্থীরা উত্তর দেবেন।'),
                    actionLabel: trx('Ask the first question', 'প্রথম প্রশ্নটা করুন'),
                    onAction: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const _AskSheet(),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();
                    final answers = (m['answerCount'] as num?)?.toInt() ?? 0;
                    final solved = m['solved'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text((m['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${m['subject'] ?? ''} · ${m['authorName'] ?? ''} · ${_ago(m['createdAt'] as Timestamp?)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(solved ? Icons.check_circle_rounded : Icons.chat_bubble_outline_rounded,
                                color: solved ? Colors.green : (answers == 0 ? Colors.orange : scheme.primary), size: 22),
                            Text('$answers', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ForumPostScreen(postId: d.id))),
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

class _AskSheet extends StatefulWidget {
  const _AskSheet();

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _subject = _forumSubjects.first;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || _title.text.trim().length < 5) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('forum_posts').add({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'subject': _subject,
        'authorId': u.uid,
        'authorName': u.displayName ?? 'Study Buddy',
        'createdAt': FieldValue.serverTimestamp(),
        'answerCount': 0,
        'solved': false,
      });
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(trx('Question posted ✓', 'প্রশ্ন পোস্ট হয়েছে ✓'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(trx('Could not post: $e', 'পোস্ট হয়নি: $e'))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trx('Ask a question', 'প্রশ্ন করুন'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final s in _forumSubjects)
                  ChoiceChip(label: Text(s), selected: _subject == s, onSelected: (_) => setState(() => _subject = s)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 150,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: trx('Your question (short)', 'আপনার প্রশ্ন (সংক্ষেপে)'),
                border: const OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: trx('Details (optional)', 'বিস্তারিত (ঐচ্ছিক)'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            Text(trx('Be kind. No personal information.', 'ভদ্র ভাষা ব্যবহার করুন, ব্যক্তিগত তথ্য দেবেন না।'),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _title.text.trim().length < 5 ? null : _post,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: Text(trx('Post', 'পোস্ট করুন')),
            ),
          ],
        ),
      ),
    );
  }
}

class ForumPostScreen extends StatefulWidget {
  final String postId;
  const ForumPostScreen({super.key, required this.postId});

  @override
  State<ForumPostScreen> createState() => _ForumPostScreenState();
}

class _ForumPostScreenState extends State<ForumPostScreen> {
  final _answer = TextEditingController();
  bool _sending = false;

  DocumentReference<Map<String, dynamic>> get _post =>
      FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId);

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final u = FirebaseAuth.instance.currentUser;
    final text = _answer.text.trim();
    if (u == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _post.collection('answers').add({
        'text': text,
        'authorId': u.uid,
        'authorName': u.displayName ?? 'Study Buddy',
        'createdAt': FieldValue.serverTimestamp(),
        'votes': 0,
        'voters': [],
        'best': false,
      });
      await _post.update({'answerCount': FieldValue.increment(1)});
      _answer.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not send: $e', 'পাঠানো যায়নি: $e'))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _vote(DocumentReference<Map<String, dynamic>> ref, List<String> voters) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final has = voters.contains(u.uid);
    await ref.update({
      'votes': FieldValue.increment(has ? -1 : 1),
      'voters': has ? FieldValue.arrayRemove([u.uid]) : FieldValue.arrayUnion([u.uid]),
    });
  }

  Future<void> _markBest(DocumentReference<Map<String, dynamic>> ref) async {
    await ref.update({'best': true});
    await _post.update({'solved': true});
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trx('Delete this question?', 'প্রশ্নটি মুছবেন?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete'.tr(), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await _post.delete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _post.snapshots(),
      builder: (context, postSnap) {
        final p = postSnap.data?.data();
        final isAuthor = p?['authorId'] == me;
        return Scaffold(
          appBar: AppBar(
            title: Text(trx('Question', 'প্রশ্ন')),
            actions: [
              if (isAuthor) IconButton(onPressed: _deletePost, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          body: p == null
              ? (postSnap.hasData
                  ? Center(child: Text(trx('This question was deleted.', 'প্রশ্নটি মুছে ফেলা হয়েছে।')))
                  : const SkeletonCardList(count: 2))
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _post.collection('answers').orderBy('votes', descending: true).snapshots(),
                        builder: (context, aSnap) {
                          final answers = aSnap.data?.docs ?? [];
                          answers.sort((a, b) => (b.data()['best'] == true ? 1 : 0).compareTo(a.data()['best'] == true ? 1 : 0));
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text((p['title'] ?? '').toString(),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('${p['subject'] ?? ''} · ${p['authorName'] ?? ''} · ${_ago(p['createdAt'] as Timestamp?)}',
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              if ((p['body'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(p['body'].toString(), style: const TextStyle(height: 1.5)),
                              ],
                              const Divider(height: 28),
                              Text(trx('${answers.length} answers', '${answers.length}টি উত্তর'),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (answers.isEmpty)
                                Text(trx('No answers yet. Know it? Write the first one below.', 'এখনো উত্তর নেই। জানলে নিচে প্রথম উত্তরটা লিখুন।'),
                                    style: TextStyle(color: scheme.onSurfaceVariant)),
                              for (final a in answers) _answerCard(a, isAuthor, me, p['solved'] == true),
                            ],
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _answer,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: trx('Write an answer…', 'উত্তর লিখুন…'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _answerCard(QueryDocumentSnapshot<Map<String, dynamic>> a, bool isAuthor, String? me, bool solved) {
    final m = a.data();
    final voters = List<String>.from(m['voters'] ?? []);
    final best = m['best'] == true;
    final iVoted = voters.contains(me);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: best
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.green, width: 1.5))
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (best)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(trx('✓ Best answer', '✓ সেরা উত্তর'),
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            Text((m['text'] ?? '').toString(), style: const TextStyle(height: 1.5)),
            Row(
              children: [
                Text('${m['authorName'] ?? ''} · ${_ago(m['createdAt'] as Timestamp?)}', style: const TextStyle(fontSize: 11)),
                const Spacer(),
                if (isAuthor && !solved && m['authorId'] != me)
                  TextButton(onPressed: () => _markBest(a.reference), child: Text(trx('Best', 'সেরা'))),
                IconButton(
                  onPressed: m['authorId'] == me ? null : () => _vote(a.reference, voters),
                  icon: Icon(iVoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, size: 18),
                ),
                Text('${(m['votes'] as num?) ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
