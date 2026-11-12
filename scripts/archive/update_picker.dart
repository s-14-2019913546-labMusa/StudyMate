import 'dart:io';

void main() {
  final file = File('lib/notification_settings_screen.dart');
  var content = file.readAsStringSync();

  // Find _pickRingtone
  // We need to modify the block where it saves the file.
  
  // Existing code:
  // if (result != null && result.files.single.path != null) {
  //   final file = result.files.single;
  //   final soundUri = 'file://\${file.path}'; // URI format for sounds
  
  var newCode = '''
    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      String finalSoundUri = 'file://\${pickedFile.path}';
      
      // Try to copy to external storage so NotificationManager can read it
      try {
        if (Platform.isAndroid) {
          final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.alarms);
          if (externalDirs != null && externalDirs.isNotEmpty) {
            final targetDir = externalDirs.first;
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }
            // Create a safe file name
            final safeName = result.files.single.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
            final targetFile = File('\${targetDir.path}/\$safeName');
            await pickedFile.copy(targetFile.path);
            finalSoundUri = 'file://\${targetFile.path}';
          }
        }
      } catch (e) {
        debugPrint('Failed to copy to external directory: \$e');
      }

      setState(() {
        if (isAlarm) {
          _customAlarmSounds[finalSoundUri] = result.files.single.name;
          _selectedAlarmSound = finalSoundUri;
          _selectedAlarmSoundName = result.files.single.name;
          _saveSettings('selectedAlarmSound', finalSoundUri);
          _saveSettings('selectedAlarmSoundName', result.files.single.name);
        } else {
          _customPushSounds[finalSoundUri] = result.files.single.name;
          _selectedPushSound = finalSoundUri;
          _selectedPushSoundName = result.files.single.name;
          _saveSettings('selectedPushSound', finalSoundUri);
          _saveSettings('selectedPushSoundName', result.files.single.name);
        }
      });
      await _saveCustomSounds();
    }
''';

  content = content.replaceFirst(RegExp(r'''if \(result != null && result\.files\.single\.path != null\) \{
\s*final file = result\.files\.single;
\s*final soundUri = 'file://\$\{file\.path\}';.*?await _saveCustomSounds\(\);
\s*\}''', dotAll: true), newCode.trim());

  file.writeAsStringSync(content);
  print('Updated notification_settings_screen.dart');
}
