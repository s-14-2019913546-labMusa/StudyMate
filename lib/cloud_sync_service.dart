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
    'notes'
  ];

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
        final data = doc.data();
        final encodedData = _encodeData(data);
        collectionData.add({
          'id': doc.id,
          'data': encodedData,
        });
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

      final batch = _firestore.batch();

      for (String collectionName in _collections) {
        if (backupData.containsKey(collectionName)) {
          final List<dynamic> collectionDataList = backupData[collectionName];
          
          for (var item in collectionDataList) {
            final String docId = item['id'];
            final Map<String, dynamic> docData = _decodeData(item['data']);

            final docRef = _firestore
                .collection('users')
                .doc(user.uid)
                .collection(collectionName)
                .doc(docId);
            
            // Overwrite existing data with backup
            batch.set(docRef, docData, SetOptions(merge: true));
          }
        }
      }

      await batch.commit();
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
      final data = await ref.getData();
      if (data == null) throw Exception("No backup data found");

      final jsonString = utf8.decode(data);
      await restoreFromJsonString(jsonString);
    } catch (e) {
      debugPrint("Error restoring backup from Firebase: $e");
      rethrow;
    }
  }
}
