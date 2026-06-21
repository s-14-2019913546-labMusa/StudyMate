import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Gamification Service — XP, Levels, Badges, and Streak tracking
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  // XP reward values
  static const int xpTaskComplete = 10;
  static const int xpStreakBonusPerDay = 5;
  static const int xpFlashcardDeck = 15;
  static const int xpPomodoroSession = 8;

  // Level calculation: Level = totalXP / 100
  static int getLevel(int totalXP) => (totalXP / 100).floor() + 1;
  static double getLevelProgress(int totalXP) => (totalXP % 100) / 100.0;
  static int xpForNextLevel(int totalXP) => 100 - (totalXP % 100);

  // Level titles
  static String getLevelTitle(int level) {
    if (level <= 2) return 'Beginner';
    if (level <= 5) return 'Learner';
    if (level <= 10) return 'Scholar';
    if (level <= 20) return 'Expert';
    if (level <= 50) return 'Master';
    return 'Legend';
  }

  // Badge definitions
  static final List<Map<String, dynamic>> allBadges = [
    {
      'id': 'starter',
      'name': '🌱 Starter',
      'description': 'প্রথম task complete করুন',
      'icon': Icons.eco_rounded,
      'color': Colors.green,
      'condition': 'first_task',
    },
    {
      'id': 'on_fire',
      'name': '🔥 On Fire',
      'description': '৩ দিন ধারাবাহিক streak',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.orange,
      'condition': 'streak_3',
    },
    {
      'id': 'unstoppable',
      'name': '⚡ Unstoppable',
      'description': '৭ দিন ধারাবাহিক streak',
      'icon': Icons.bolt_rounded,
      'color': Colors.amber,
      'condition': 'streak_7',
    },
    {
      'id': 'diamond',
      'name': '💎 Diamond',
      'description': '৩০ দিন ধারাবাহিক streak',
      'icon': Icons.diamond_rounded,
      'color': Colors.cyanAccent,
      'condition': 'streak_30',
    },
    {
      'id': 'bookworm',
      'name': '📚 Bookworm',
      'description': '৫০টি task complete করুন',
      'icon': Icons.menu_book_rounded,
      'color': Colors.deepPurple,
      'condition': 'tasks_50',
    },
    {
      'id': 'champion',
      'name': '🏆 Champion',
      'description': '১০০টি task complete করুন',
      'icon': Icons.emoji_events_rounded,
      'color': Colors.amber.shade700,
      'condition': 'tasks_100',
    },
    {
      'id': 'scholar',
      'name': '🧠 Scholar',
      'description': '১০টি flashcard deck complete করুন',
      'icon': Icons.psychology_rounded,
      'color': Colors.indigo,
      'condition': 'decks_10',
    },
  ];

  /// Get or create gamification data for the current user
  static Future<Map<String, dynamic>> getUserGamificationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'totalXP': 0, 'badges': <String>[], 'totalTasksDone': 0};

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'totalXP': (data['totalXP'] as num?)?.toInt() ?? 0,
          'badges': List<String>.from(data['unlockedBadges'] ?? []),
          'totalTasksDone': (data['totalTasksDone'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error loading gamification data: $e');
    }
    return {'totalXP': 0, 'badges': <String>[], 'totalTasksDone': 0};
  }

  /// Award XP and check for new badges
  static Future<Map<String, dynamic>> awardXP(int xpAmount, {String? reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Increment XP atomically
      await docRef.set({
        'totalXP': FieldValue.increment(xpAmount),
        if (reason == 'task_complete') 'totalTasksDone': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Fetch updated data
      final updatedDoc = await docRef.get();
      final data = updatedDoc.data() ?? {};
      final totalXP = (data['totalXP'] as num?)?.toInt() ?? 0;
      final totalTasks = (data['totalTasksDone'] as num?)?.toInt() ?? 0;
      final currentBadges = List<String>.from(data['unlockedBadges'] ?? []);

      // Check for new badges
      final newBadges = await _checkAndAwardBadges(
        docRef, totalTasks, currentBadges,
      );

      return {
        'totalXP': totalXP,
        'xpAwarded': xpAmount,
        'newBadges': newBadges,
        'level': getLevel(totalXP),
      };
    } catch (e) {
      debugPrint('Error awarding XP: $e');
      return {};
    }
  }

  /// Check badge conditions and unlock new ones
  static Future<List<String>> _checkAndAwardBadges(
    DocumentReference docRef,
    int totalTasks,
    List<String> currentBadges,
  ) async {
    List<String> newBadges = [];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return newBadges;

    // Calculate streak
    final streak = await calculateStreak();

    // Check each badge
    for (final badge in allBadges) {
      final badgeId = badge['id'] as String;
      if (currentBadges.contains(badgeId)) continue;

      bool unlocked = false;
      final condition = badge['condition'] as String;

      switch (condition) {
        case 'first_task':
          unlocked = totalTasks >= 1;
          break;
        case 'streak_3':
          unlocked = streak >= 3;
          break;
        case 'streak_7':
          unlocked = streak >= 7;
          break;
        case 'streak_30':
          unlocked = streak >= 30;
          break;
        case 'tasks_50':
          unlocked = totalTasks >= 50;
          break;
        case 'tasks_100':
          unlocked = totalTasks >= 100;
          break;
        case 'decks_10':
          // Check flashcard decks count
          try {
            final decksSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('flashcard_decks')
                .get();
            unlocked = decksSnapshot.docs.length >= 10;
          } catch (_) {}
          break;
      }

      if (unlocked) {
        newBadges.add(badgeId);
        currentBadges.add(badgeId);
      }
    }

    // Save updated badges
    if (newBadges.isNotEmpty) {
      await docRef.set({
        'unlockedBadges': currentBadges,
      }, SetOptions(merge: true));
    }

    return newBadges;
  }

  /// Calculate current study streak (consecutive days with at least 1 completed task)
  static Future<int> calculateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      int streak = 0;
      DateTime checkDate = DateTime.now();

      // Check up to 365 days back
      for (int i = 0; i < 365; i++) {
        final dateId = DateFormat('yyyy-MM-dd').format(checkDate);
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dailyRoutines')
            .doc(dateId)
            .get();

        if (doc.exists && doc.data() != null) {
          final tasks = doc.data()!['tasks'] as List<dynamic>? ?? [];
          final hasCompletedTask = tasks.any((t) =>
              (t as Map<String, dynamic>)['status'] == 'completed' ||
              (t as Map<String, dynamic>)['isCompleted'] == true);

          if (hasCompletedTask) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            // If today has no completed tasks but we haven't started counting yet, skip today
            if (i == 0) {
              checkDate = checkDate.subtract(const Duration(days: 1));
              continue;
            }
            break;
          }
        } else {
          if (i == 0) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  /// Count total completed tasks across all routines
  static Future<int> countTotalCompletedTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      // First check if we have a cached count
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()?['totalTasksDone'] != null) {
        return (userDoc.data()!['totalTasksDone'] as num).toInt();
      }

      // Fallback: count from routines (expensive, only runs once)
      final routinesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyRoutines')
          .get();

      int total = 0;
      for (final doc in routinesSnapshot.docs) {
        final tasks = doc.data()['tasks'] as List<dynamic>? ?? [];
        for (final task in tasks) {
          final t = task as Map<String, dynamic>;
          if (t['status'] == 'completed' || t['isCompleted'] == true) {
            total++;
          }
        }
      }

      // Cache the count
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'totalTasksDone': total}, SetOptions(merge: true));

      return total;
    } catch (e) {
      debugPrint('Error counting tasks: $e');
      return 0;
    }
  }
}
