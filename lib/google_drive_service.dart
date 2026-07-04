import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'cloud_sync_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  final CloudSyncService _cloudSyncService = CloudSyncService();

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      var account = await _googleSignIn.signIn();
      if (account == null) return null; // User aborted

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      return drive.DriveApi(authenticateClient);
    } catch (e) {
      debugPrint("Error signing in to Google: $e");
      return null;
    }
  }

  Future<void> backupToDrive() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception("Could not connect to Google Drive");

    // Get the JSON string
    final jsonString = await _cloudSyncService.generateBackupJsonString();
    final bytes = utf8.encode(jsonString);

    // Look for existing backup file to update, or create a new one
    final fileList = await driveApi.files.list(
      q: "name = 'studymate_backup.json' and trashed = false",
      spaces: 'appDataFolder',
    );

    final driveFile = drive.File()
      ..name = 'studymate_backup.json'
      ..parents = ['appDataFolder'];

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      // Update existing file
      final fileId = fileList.files!.first.id!;
      await driveApi.files.update(
        driveFile,
        fileId,
        uploadMedia: media,
      );
    } else {
      // Create new file
      await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );
    }
  }

  Future<void> restoreFromDrive() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception("Could not connect to Google Drive");

    final fileList = await driveApi.files.list(
      q: "name = 'studymate_backup.json' and trashed = false",
      spaces: 'appDataFolder',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception("No backup file found in Google Drive");
    }

    final fileId = fileList.files!.first.id!;
    final drive.Media fileMedia = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    List<int> bytes = [];
    await for (var b in fileMedia.stream) {
      bytes.addAll(b);
    }

    final jsonString = utf8.decode(bytes);
    await _cloudSyncService.restoreFromJsonString(jsonString);
  }

  Future<DateTime?> getLastDriveBackupTime() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final fileList = await driveApi.files.list(
        q: "name = 'studymate_backup.json' and trashed = false",
        spaces: 'appDataFolder',
        $fields: "files(id, name, modifiedTime)",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }
    } catch (e) {
      debugPrint("Error fetching drive backup time: $e");
    }
    return null;
  }
}
