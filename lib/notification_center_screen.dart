import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'language_manager.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every 10 seconds so that scheduled notifications appear in real-time
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _getIconLabel(String type) {
    switch (type) {
      case 'revision':
        return '📚';
      case 'routine':
        return '📅';
      case 'streak':
        return '🔥';
      default:
        return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please log in first")));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text("Today's Notifications".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear All',
            onPressed: () {
              NotificationService.clearAll(currentUser!.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications cleared!')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('All caught up!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('No notifications received today.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            
            // Exclude pop-ups from Notification Center
            if (data['type'] == 'popup') return false;

            final Timestamp? scheduledTime = data['scheduledTime'] as Timestamp?;
            if (scheduledTime != null && scheduledTime.toDate().isAfter(now)) {
              return false;
            }
            return true;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('All caught up!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('No notifications received today.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String id = data['id'] ?? '';
              final String title = data['title'] ?? '';
              final String body = data['body'] ?? '';
              final String type = data['type'] ?? 'general';
              final bool isRead = data['isRead'] ?? false;
              final Timestamp? timestamp = data['timestamp'] as Timestamp?;
              final Timestamp? snoozedUntil = data['snoozedUntil'] as Timestamp?;

              String timeStr = 'Just now';
              if (timestamp != null) {
                timeStr = DateFormat('hh:mm a').format(timestamp.toDate());
              }

              // Hide notification if it's currently snoozed until a future time
              if (snoozedUntil != null && snoozedUntil.toDate().isAfter(DateTime.now())) {
                return const SizedBox.shrink();
              }

              final isRevision = type == 'revision';

              return Card(
                color: isRead ? theme.cardColor : theme.colorScheme.primary.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isRead ? BorderSide.none : BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Text(_getIconLabel(type), style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(timeStr, style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11)),
                        ],
                      ),
                      if (isRevision || !isRead) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isRevision) ...[
                              TextButton.icon(
                                onPressed: () {
                                  NotificationService.snoozeNotification(currentUser!.uid, id, 1);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Snoozed for 1 hour!')),
                                  );
                                },
                                icon: const Icon(Icons.snooze_rounded, size: 16),
                                label: const Text('Snooze 1h', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (!isRead)
                              ElevatedButton(
                                onPressed: () => NotificationService.markAsRead(currentUser!.uid, id),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Dismiss', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
