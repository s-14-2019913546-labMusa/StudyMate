import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'daily_routine.dart';
import 'language_manager.dart';

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
  late Task _task;
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
    _task = widget.task;
    _comments = List.from(_task.comments); // ডাটাবেজ থেকে পূর্বের কমেন্টগুলো লোড করা
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
      _task = _task.copyWith(comments: _comments);
    });
    if (widget.onUpdate != null) {
      // আপডেট হওয়া টাস্কটি ফায়ারবেসে সেভ করার জন্য কলব্যাক
      widget.onUpdate!(_task);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Comment added: $comment')),
    );
  }

  bool _isMissedTask() {
    final now = DateTime.now();
    final isCompleted = _task.isCompleted || _task.status == 'completed';
    
    final fromElapsed = _task.totalDurationMinutes > 0
        ? (_task.elapsedSeconds / (_task.totalDurationMinutes * 60))
        : 0.0;
    final fromMinutes = _task.totalDurationMinutes > 0
        ? (_task.completedDurationMinutes / _task.totalDurationMinutes)
        : 0.0;
    final actualProgress = fromElapsed > fromMinutes ? fromElapsed : fromMinutes;

    if (isCompleted) {
      // Completed but failed to reach 70% progress
      return actualProgress < 0.70;
    } else {
      // Uncompleted and scheduled end time has passed
      return _task.endTime != null && _task.endTime!.isBefore(now);
    }
  }

  void _showRescheduleBottomSheet(BuildContext context, {required bool keepProgress}) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay? newStartTime = _task.startTime != null ? TimeOfDay.fromDateTime(_task.startTime!) : null;
    TimeOfDay? newEndTime = _task.endTime != null ? TimeOfDay.fromDateTime(_task.endTime!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final onSurfaceColor = colorScheme.onSurface;
            
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(keepProgress ? Icons.play_circle_fill_rounded : Icons.update_rounded, color: colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        (keepProgress ? 'Resume Study Today' : 'Reschedule Task').tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: onSurfaceColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Date Selection (resuming is always for today, so only show if rescheduling)
                  if (!keepProgress) ...[
                    Text('Select Date'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('Today'.tr())),
                            selected: DateUtils.isSameDay(selectedDate, DateTime.now()),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  selectedDate = DateTime.now();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('Tomorrow'.tr())),
                            selected: DateUtils.isSameDay(selectedDate, DateTime.now().add(const Duration(days: 1))),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  selectedDate = DateTime.now().add(const Duration(days: 1));
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Time Pickers
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: newStartTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setModalState(() {
                                newStartTime = picked;
                              });
                            }
                          },
                          icon: Icon(Icons.access_time_rounded, color: newStartTime != null ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                          label: Text(
                            newStartTime == null ? 'Start Time'.tr() : newStartTime!.format(context),
                            style: TextStyle(color: newStartTime != null ? colorScheme.primary : onSurfaceColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: newStartTime != null ? colorScheme.primary : onSurfaceColor.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: newEndTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setModalState(() {
                                newEndTime = picked;
                              });
                            }
                          },
                          icon: Icon(Icons.access_time_rounded, color: newEndTime != null ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                          label: Text(
                            newEndTime == null ? 'End Time'.tr() : newEndTime!.format(context),
                            style: TextStyle(color: newEndTime != null ? colorScheme.primary : onSurfaceColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: newEndTime != null ? colorScheme.primary : onSurfaceColor.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: () async {
                      if (newStartTime == null || newEndTime == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Please select both Start and End Time.'.tr())),
                        );
                        return;
                      }
                      
                      final start = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        newStartTime!.hour,
                        newStartTime!.minute,
                      );
                      var end = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        newEndTime!.hour,
                        newEndTime!.minute,
                      );
                      if (end.isBefore(start)) {
                        end = end.add(const Duration(days: 1));
                      }
                      
                      final String newId = keepProgress
                          ? (_task.id.startsWith('resumed_') ? _task.id : 'resumed_${_task.id}')
                          : (_task.id.startsWith('resumed_') ? _task.id.replaceFirst('resumed_', '') : _task.id);

                      final updatedTask = _task.copyWith(
                        id: newId,
                        startTime: start,
                        endTime: end,
                        status: 'pending',
                        isCompleted: false,
                        elapsedSeconds: keepProgress ? _task.elapsedSeconds : 0,
                        completedDurationMinutes: keepProgress ? _task.completedDurationMinutes : 0,
                        totalDurationMinutes: end.difference(start).inMinutes,
                      );
                      
                      // Trigger Firestore callback
                      if (widget.onUpdate != null) {
                        await widget.onUpdate!(updatedTask);
                      }
                      
                      // Update locally in details screen
                      setState(() {
                        _task = updatedTask;
                      });
                      
                      Navigator.pop(ctx);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text((keepProgress ? 'Resume successful!' : 'Reschedule successful!').tr()),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      (keepProgress ? 'Confirm Resume' : 'Confirm Reschedule').tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    // প্রগ্রেস ক্যালকুলেশন
    int totalTargetSeconds = _task.totalDurationMinutes * 60;
    int elapsedSeconds = _task.elapsedSeconds;
    double progress = totalTargetSeconds > 0 ? (elapsedSeconds / totalTargetSeconds) : 0.0;
    if (progress > 1.0) progress = 1.0;

    // প্রাইভেসি চেক (টাস্ক প্রাইভেট হলে এবং অন্য বন্ধু দেখলে ডাটা হাইড করবে কিন্তু প্রগ্রেস বার দেখা যাবে)
    bool shouldMaskDetails = widget.isFriendView && _task.isPrivate;
    String displayTitle = _task.title;
    if (_task.isPrivate) {
      displayTitle = '🔒 $displayTitle';
    }
    String displayNotes = _task.notes?.isNotEmpty == true ? _task.notes! : 'No notes available.';
    
    String category = _task.category ?? 'Uncategorized';

    String startTime = _task.startTime != null ? DateFormat('MMM d, yyyy - h:mm a').format(_task.startTime!) : 'Not Set';
    String endTime = _task.endTime != null ? DateFormat('MMM d, yyyy - h:mm a').format(_task.endTime!) : 'Not Set';

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
                                        color: _task.isPrivate ? Colors.grey.shade700 : Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(context, Icons.access_time_rounded, 'Planned Duration', '${_task.totalDurationMinutes} mins'),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  context,
                                  Icons.timer_outlined,
                                  'Time Spent',
                                  '${_task.completedDurationMinutes} mins',
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
                                          fontStyle: _task.isPrivate ? FontStyle.italic : FontStyle.normal,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                
                                // Actions for Missed/Incomplete Tasks
                                 if (_isMissedTask() && !widget.isFriendView) ...[
                                   const SizedBox(height: 24),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: ElevatedButton.icon(
                                           onPressed: () => _showRescheduleBottomSheet(context, keepProgress: true),
                                           icon: const Icon(Icons.play_circle_fill_rounded),
                                           label: Text('Resume Study'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                           style: ElevatedButton.styleFrom(
                                             backgroundColor: Theme.of(context).colorScheme.primary,
                                             foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                             padding: const EdgeInsets.symmetric(vertical: 14),
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: OutlinedButton.icon(
                                           onPressed: () => _showRescheduleBottomSheet(context, keepProgress: false),
                                           icon: const Icon(Icons.update_rounded),
                                           label: Text('Reschedule'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                           style: OutlinedButton.styleFrom(
                                             foregroundColor: Theme.of(context).colorScheme.primary,
                                             side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                                             padding: const EdgeInsets.symmetric(vertical: 14),
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                           ),
                                         ),
                                       ),
                                     ],
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