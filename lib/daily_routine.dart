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
  
  // New Fields
  final String? subject;
  final String? notes;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isPrivate;
  final String? category;
  final String status; // 'pending', 'running', 'paused', 'completed'
  final bool hasBeenEdited;
  final int elapsedSeconds;
  final String? completionNote;
  final List<String> comments;
  final String? topic;
  final String? challenges;
  final bool alarmEnabled;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.totalDurationMinutes = 0,
    this.completedDurationMinutes = 0,
    this.subject,
    this.notes,
    this.startTime,
    this.endTime,
    this.isPrivate = false,
    this.category,
    this.status = 'pending',
    this.hasBeenEdited = false,
    this.elapsedSeconds = 0,
    this.completionNote,
    this.comments = const [],
    this.topic,
    this.challenges,
    this.alarmEnabled = false,
  });

  factory Task.fromMap(Map<String, dynamic> data, String id) {
    return Task(
      id: id,
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      totalDurationMinutes: data['totalDurationMinutes'] ?? 0,
      completedDurationMinutes: data['completedDurationMinutes'] ?? 0,
      subject: data['subject'],
      notes: data['notes'],
      startTime: data['startTime'] != null ? (data['startTime'] as Timestamp).toDate() : null,
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      isPrivate: data['isPrivate'] ?? false,
      category: data['category'],
      status: data['status'] ?? 'pending',
      hasBeenEdited: data['hasBeenEdited'] ?? false,
      elapsedSeconds: data['elapsedSeconds'] ?? 0,
      completionNote: data['completionNote'],
      comments: List<String>.from(data['comments'] ?? []),
      topic: data['topic'],
      challenges: data['challenges'],
      alarmEnabled: data['alarmEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'totalDurationMinutes': totalDurationMinutes,
      'completedDurationMinutes': completedDurationMinutes,
      'subject': subject,
      'notes': notes,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isPrivate': isPrivate,
      'category': category,
      'status': status,
      'hasBeenEdited': hasBeenEdited,
      'elapsedSeconds': elapsedSeconds,
      'completionNote': completionNote,
      'comments': comments,
      'topic': topic,
      'challenges': challenges,
      'alarmEnabled': alarmEnabled,
    };
  }

  // Method to create a copy of the Task with updated values
  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? totalDurationMinutes,
    int? completedDurationMinutes,
    String? subject,
    String? notes,
    DateTime? startTime,
    DateTime? endTime,
    bool? isPrivate,
    String? category,
    String? status,
    bool? hasBeenEdited,
    int? elapsedSeconds,
    String? completionNote,
    List<String>? comments,
    String? topic,
    String? challenges,
    bool? alarmEnabled,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      completedDurationMinutes: completedDurationMinutes ?? this.completedDurationMinutes,
      subject: subject ?? this.subject,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isPrivate: isPrivate ?? this.isPrivate,
      category: category ?? this.category,
      status: status ?? this.status,
      hasBeenEdited: hasBeenEdited ?? this.hasBeenEdited,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      completionNote: completionNote ?? this.completionNote,
      comments: comments ?? this.comments,
      topic: topic ?? this.topic,
      challenges: challenges ?? this.challenges,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
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
    if (tasks.isEmpty) return 0.0;
    double totalTaskProgress = 0.0;
    for (var task in tasks) {
      double taskProgress = 0.0;
      double fromElapsed = task.totalDurationMinutes > 0 ? (task.elapsedSeconds / (task.totalDurationMinutes * 60)) : 0.0;
      double fromMinutes = task.totalDurationMinutes > 0 ? (task.completedDurationMinutes / task.totalDurationMinutes) : 0.0;
      double actualProgress = (fromElapsed > fromMinutes ? fromElapsed : fromMinutes).clamp(0.0, 1.0);

      if (task.isCompleted || task.status == 'completed') {
        // Only count as 1.0 (successful completion) if progress is >= 70%
        taskProgress = actualProgress >= 0.70 ? 1.0 : actualProgress;
      } else {
        taskProgress = actualProgress;
      }
      totalTaskProgress += taskProgress;
    }
    return totalTaskProgress / tasks.length;
  }
}