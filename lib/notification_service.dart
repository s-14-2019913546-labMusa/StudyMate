import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationService {
  /// Send a notification and log it in Firestore
  static Future<void> sendNotification(
    String userId,
    String title,
    String body, {
    String type = 'general',
    DateTime? scheduledTime,
  }) async {
    try {
      // Fetch user's notification settings to check toggles
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('notificationSettings')) {
          final settings = data['notificationSettings'] as Map<String, dynamic>?;
          if (settings != null) {
            final bool global = settings['globalNotifications'] as bool? ?? true;
            if (!global) {
              debugPrint('NotificationService: Global notifications are disabled.');
              return;
            }

            if (type == 'routine') {
              final bool studyGoal = settings['studyGoalReminders'] as bool? ?? true;
              if (!studyGoal) {
                debugPrint('NotificationService: Study goal reminders are disabled.');
                return;
              }
            } else if (type == 'task') {
              final bool taskDue = settings['taskDueWarnings'] as bool? ?? true;
              if (!taskDue) {
                debugPrint('NotificationService: Task due warnings are disabled.');
                return;
              }
            } else if (type == 'revision') {
              final bool spacedRevision = settings['spacedRevisionAlerts'] as bool? ?? true;
              if (!spacedRevision) {
                debugPrint('NotificationService: Spaced revision alerts are disabled.');
                return;
              }
            } else if (type == 'social') {
              final bool social = settings['socialHubNotifications'] as bool? ?? true;
              if (!social) {
                debugPrint('NotificationService: Social notifications are disabled.');
                return;
              }
            } else if (type == 'motivational') {
              final bool motivational = settings['motivationalPush'] as bool? ?? true;
              if (!motivational) {
                debugPrint('NotificationService: Motivational push notifications are disabled.');
                return;
              }
            }
          }
        }
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

      await docRef.set({
        'id': docRef.id,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime) : FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  /// Reschedule/Snooze an existing notification
  static Future<void> snoozeNotification(
    String userId,
    String notificationId,
    int hours,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);

      final newTime = DateTime.now().add(Duration(hours: hours));

      // Mark current as read and schedule a new one in the future
      await docRef.update({
        'isRead': true,
        'snoozedUntil': Timestamp.fromDate(newTime),
      });

      // Fetch details of the old one to create the rescheduled warning
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        await sendNotification(
          userId,
          '⏰ Remainder: ${data['title']}',
          'This is your snoozed study alert: ${data['body']}',
          type: data['type'] ?? 'general',
          scheduledTime: newTime,
        );
      }
    } catch (e) {
      debugPrint('Snooze notification error: $e');
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAll(String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Clear all notifications error: $e');
    }
  }
}
