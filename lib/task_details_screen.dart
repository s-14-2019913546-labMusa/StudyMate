import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'daily_routine.dart';

// ==========================================
// Task Details Screen (টাস্ক ডিটেইলস স্ক্রিন)
// ==========================================
class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  final Function(Task)? onUpdate;
  final bool isFriendView;
  const TaskDetailsScreen({
    super.key, 
    required this.task, 
    this.onUpdate,
    this.isFriendView = false,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late List<String> _comments; 
  final TextEditingController _commentController = TextEditingController();

  final List<String> _quickComments = [
    'Come on, do it!',
    'Great job!',
    'Keep it up!',
    "You're almost there!",
    "Don't give up!",
    'Stay focused!',
    'You’ve got this!',
  ];

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.task.comments); // ডাটাবেজ থেকে পূর্বের কমেন্টগুলো লোড করা
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment(String comment) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final senderName = currentUser?.displayName ?? 'Study Buddy';
    final formattedComment = "$senderName: $comment";

    setState(() {
      _comments.insert(0, formattedComment); // নতুন কমেন্টটি লিস্টের শুরুতে যুক্ত হবে
    });
    if (widget.onUpdate != null) {
      // আপডেট হওয়া টাস্কটি ফায়ারবেসে সেভ করার জন্য কলব্যাক
      widget.onUpdate!(widget.task.copyWith(comments: _comments));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Comment added: $comment')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // প্রগ্রেস ক্যালকুলেশন
    int totalTargetSeconds = widget.task.totalDurationMinutes * 60;
    int elapsedSeconds = widget.task.elapsedSeconds;
    double progress = totalTargetSeconds > 0 ? (elapsedSeconds / totalTargetSeconds) : 0.0;
    if (progress > 1.0) progress = 1.0;

    // প্রাইভেসি চেক (টাস্ক প্রাইভেট হলে এবং অন্য বন্ধু দেখলে ডাটা হাইড করবে কিন্তু প্রগ্রেস বার দেখা যাবে)
    bool shouldMaskDetails = widget.isFriendView && widget.task.isPrivate;
    String displayTitle = widget.task.title;
    if (widget.task.isPrivate) {
      displayTitle = '🔒 $displayTitle';
    }
    String displayNotes = widget.task.notes?.isNotEmpty == true ? widget.task.notes! : 'No notes available.';
    
    String category = widget.task.category ?? 'Uncategorized';

    String startTime = widget.task.startTime != null ? DateFormat('MMM d, yyyy - h:mm a').format(widget.task.startTime!) : 'Not Set';
    String endTime = widget.task.endTime != null ? DateFormat('MMM d, yyyy - h:mm a').format(widget.task.endTime!) : 'Not Set';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: shouldMaskDetails 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    displayTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time: $startTime - $endTime',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'This task is private.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            )
          : Column(
              children: [
                // ১. প্রগ্রেস বার (সবার জন্য সর্বদা দৃশ্যমান)
                Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Task Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ২. টাস্কের বিস্তারিত তথ্য কার্ড
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: widget.task.isPrivate ? Colors.grey.shade700 : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(context, Icons.access_time_rounded, 'Planned Duration', '${widget.task.totalDurationMinutes} mins'),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            Icons.timer_outlined,
                            'Time Spent',
                            '${widget.task.completedDurationMinutes} mins',
                          ),
                          if (!shouldMaskDetails) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(context, Icons.category_rounded, 'Category', category),
                            const SizedBox(height: 12),
                            _buildInfoRow(context, Icons.access_time_rounded, 'Start Time', startTime),
                            const SizedBox(height: 12),
                            _buildInfoRow(context, Icons.access_time_filled_rounded, 'End Time', endTime),
                            const Divider(height: 32),
                            Text(
                              'Goal / Notes',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              displayNotes,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: widget.task.isPrivate ? FontStyle.italic : FontStyle.normal,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ৩. কমেন্ট সেকশন
                  Text(
                    'Encouragements & Comments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'No comments yet. Be the first to cheer!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        String author = 'Study Buddy';
                        String commentText = _comments[index];
                        if (_comments[index].contains(': ')) {
                          int splitIndex = _comments[index].indexOf(': ');
                          author = _comments[index].substring(0, splitIndex);
                          commentText = _comments[index].substring(splitIndex + 2);
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(commentText, style: const TextStyle(fontSize: 14)),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // ৪. কুইক কমেন্ট চিপস এবং কাস্টম কমেন্ট ফিল্ড (নিচের দিকে)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Send an encouragement:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _quickComments.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(_quickComments[index]),
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onPressed: () => _addComment(_quickComments[index]),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 12, thickness: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Type a comment...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final text = _commentController.text.trim();
                          if (text.isNotEmpty) {
                            _addComment(text);
                            _commentController.clear();
                          }
                        },
                        icon: const Icon(Icons.send_rounded),
                        color: Theme.of(context).colorScheme.primary,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
              Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}