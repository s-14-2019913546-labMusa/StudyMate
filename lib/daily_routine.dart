import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For UniqueKey

// ==========================================
// Data Models for Routine and Tasks
// ==========================================

// For a single task within a daily routine
class Task {
  final String id;
  final String title;
  bool isCompleted;
  final int totalDurationMinutes; // Total planned duration for the task
  int completedDurationMinutes; // How much time has been spent on this task

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.totalDurationMinutes = 0,
    this.completedDurationMinutes = 0,
  });

  factory Task.fromMap(Map<String, dynamic> data, String id) {
    return Task(
      id: id,
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      totalDurationMinutes: data['totalDurationMinutes'] ?? 0,
      completedDurationMinutes: data['completedDurationMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Include ID for easier updates if needed
      'title': title,
      'isCompleted': isCompleted,
      'totalDurationMinutes': totalDurationMinutes,
      'completedDurationMinutes': completedDurationMinutes,
    };
  }

  // Method to create a copy of the Task with updated values
  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? totalDurationMinutes,
    int? completedDurationMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      completedDurationMinutes: completedDurationMinutes ?? this.completedDurationMinutes,
    );
  }
}

// For a daily routine document
class DailyRoutine {
  final String id; // This will be the date string (YYYY-MM-DD)
  final String userId;
  final DateTime date;
  final List<Task> tasks;

  DailyRoutine({
    required this.id,
    required this.userId,
    required this.date,
    required this.tasks,
  });

  factory DailyRoutine.fromMap(Map<String, dynamic> data, String id) {
    List<Task> tasksList = [];
    if (data['tasks'] != null) {
      for (var taskMap in data['tasks']) {
        tasksList.add(Task.fromMap(taskMap, taskMap['id'] ?? UniqueKey().toString()));
      }
    }
    return DailyRoutine(
      id: id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      tasks: tasksList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'tasks': tasks.map((task) => task.toMap()).toList(),
    };
  }

  // Helper to calculate total planned duration for the day
  int get totalPlannedDuration => tasks.fold(0, (total, task) => total + task.totalDurationMinutes);

  // Helper to calculate total completed duration for the day
  int get totalCompletedDuration => tasks.fold(0, (total, task) => total + task.completedDurationMinutes);

  // Helper to calculate overall progress percentage
  double get progress {
    if (totalPlannedDuration == 0) return 0.0;
    return totalCompletedDuration / totalPlannedDuration;
  }
}