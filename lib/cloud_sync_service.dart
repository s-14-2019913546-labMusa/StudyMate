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

  Future<void> createBackup() async {
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
        // Convert Timestamps to ISO strings for JSON serialization
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = {
              '_type': 'Timestamp',
              'seconds': value.seconds,
              'nanoseconds': value.nanoseconds,
            };
          }
        });
        collectionData.add({
          'id': doc.id,
          'data': data,
        });
      }
      backupData[collectionName] = collectionData;
    }

    final jsonString = jsonEncode(backupData);
    final backupDataBytes = utf8.encode(jsonString);

    // Upload to Firebase Storage
    final ref = _storage.ref().child('backups/${user.uid}/backup.json');
    await ref.putData(
      Uint8List.fromList(backupDataBytes),
      SettableMetadata(contentType: 'application/json'),
    );
  }

  Future<void> restoreBackup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final ref = _storage.ref().child('backups/${user.uid}/backup.json');
    
    try {
      final data = await ref.getData();
      if (data == null) throw Exception("No backup data found");

      final jsonString = utf8.decode(data);
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
            final Map<String, dynamic> docData = item['data'];

            // Convert back to Timestamp
            docData.forEach((key, value) {
              if (value is Map && value['_type'] == 'Timestamp') {
                docData[key] = Timestamp(value['seconds'], value['nanoseconds']);
              }
            });

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
      debugPrint("Error restoring backup: $e");
      rethrow;
    }
  }
}
