import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // List of subcollections to backup
  final List<String> _collections = [
    'dailyDiary',
    'dailyRoutines',
    'weeklyRoutines',
    'studyFolders',
    'tasks',
    'sleep_history',
    'notes',
    // আগে এগুলো ব্যাকআপে বাদ পড়ত
    'flashcard_decks',
    'favorite_words',
    'countdownFolders',
    'bookmarks',
    'moods',
    'pdfBookmarks',
    'custom_news_feeds',
    'pomodoroForest',
  ];

  // যেসব কালেকশনের ভেতরে আরেকটা সাব-কালেকশন আছে
  final Map<String, List<String>> _subCollections = {
    'countdownFolders': ['entries'],
    'pomodoroForest': ['list'],
  };

  dynamic _encodeData(dynamic data) {
    if (data is Timestamp) {
      return {
        '_type': 'Timestamp',
        'seconds': data.seconds,
        'nanoseconds': data.nanoseconds,
      };
    } else if (data is DateTime) {
      return {
        '_type': 'DateTime',
        'iso': data.toIso8601String(),
      };
    } else if (data is Map) {
      return data.map((key, value) => MapEntry(key, _encodeData(value)));
    } else if (data is List) {
      return data.map((value) => _encodeData(value)).toList();
    }
    return data;
  }

  dynamic _decodeData(dynamic data) {
    if (data is Map) {
      if (data['_type'] == 'Timestamp') {
        return Timestamp(data['seconds'], data['nanoseconds']);
      } else if (data['_type'] == 'DateTime') {
        return DateTime.parse(data['iso']);
      }
      return data.map((key, value) => MapEntry(key, _decodeData(value)));
    } else if (data is List) {
      return data.map((value) => _decodeData(value)).toList();
    }
    return data;
  }

  Future<DateTime?> getLastBackupTime() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      final ref = _storage.ref().child('backups/${user.uid}/backup.json');
      final metadata = await ref.getMetadata();
      return metadata.updated;
    } catch (e) {
      return null;
    }
  }

  Future<String> generateBackupJsonString() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    Map<String, dynamic> backupData = {
      'timestamp': DateTime.now().toIso8601String(),
      'uid': user.uid,
    };

    for (String collectionName in _collections) {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .get();

      List<Map<String, dynamic>> collectionData = [];
      for (var doc in snapshot.docs) {
        final item = <String, dynamic>{
          'id': doc.id,
          'data': _encodeData(doc.data()),
        };
        final subs = _subCollections[collectionName];
        if (subs != null) {
          final subData = <String, dynamic>{};
          for (final sub in subs) {
            final subSnap = await doc.reference.collection(sub).get();
            subData[sub] = subSnap.docs
                .map((d) => {'id': d.id, 'data': _encodeData(d.data())})
                .toList();
          }
          item['sub'] = subData;
        }
        collectionData.add(item);
      }
      backupData[collectionName] = collectionData;
    }

    return jsonEncode(backupData);
  }

  Future<void> createBackup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final jsonString = await generateBackupJsonString();
    final backupDataBytes = utf8.encode(jsonString);

    // Upload to Firebase Storage
    final ref = _storage.ref().child('backups/${user.uid}/backup.json');
    await ref.putData(
      Uint8List.fromList(backupDataBytes),
      SettableMetadata(contentType: 'application/json'),
    );
  }

  Future<void> restoreFromJsonString(String jsonString) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      if (backupData['uid'] != user.uid) {
        throw Exception("Backup belongs to a different user");
      }

      // Firestore একবারে সর্বোচ্চ ৫০০টা লেখা নেয়, তাই ৪০০ করে ভাগ করে লেখা হয়
      WriteBatch batch = _firestore.batch();
      int ops = 0;
      Future<void> addWrite(DocumentReference ref, Map<String, dynamic> data) async {
        batch.set(ref, data, SetOptions(merge: true));
        ops++;
        if (ops >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }

      for (String collectionName in _collections) {
        if (!backupData.containsKey(collectionName)) continue;
        final List<dynamic> collectionDataList = backupData[collectionName];
        for (var item in collectionDataList) {
          final String docId = item['id'];
          final Map<String, dynamic> docData = Map<String, dynamic>.from(_decodeData(item['data']));
          final docRef = _firestore
              .collection('users')
              .doc(user.uid)
              .collection(collectionName)
              .doc(docId);
          await addWrite(docRef, docData);

          final sub = item['sub'];
          if (sub is Map) {
            for (final entry in sub.entries) {
              for (final subItem in (entry.value as List)) {
                await addWrite(
                  docRef.collection(entry.key as String).doc(subItem['id'] as String),
                  Map<String, dynamic>.from(_decodeData(subItem['data'])),
                );
              }
            }
          }
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      debugPrint("Error parsing or restoring from JSON: $e");
      rethrow;
    }
  }

  Future<void> restoreBackup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final ref = _storage.ref().child('backups/${user.uid}/backup.json');
    
    try {
      final data = await ref.getData(50 * 1024 * 1024);
      if (data == null) throw Exception("No backup data found");

      final jsonString = utf8.decode(data);
      await restoreFromJsonString(jsonString);
    } catch (e) {
      debugPrint("Error restoring backup from Firebase: $e");
      rethrow;
    }
  }
}
