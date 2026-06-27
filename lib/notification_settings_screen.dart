import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notification_service.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'language_manager.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  // Notification Preferences State
  bool _globalNotifications = true;
  bool _studyGoalReminders = true;
  bool _taskDueWarnings = true;
  bool _spacedRevisionAlerts = true;
  bool _socialHubNotifications = true;
  bool _motivationalPush = true;

  // Sound & Vibration State
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  double _volumeLevel = 0.8;
  String _selectedPushSound = 'Notification';
  String _selectedPushSoundName = 'Notification';
  String _selectedAlarmSound = 'Alarm';
  String _selectedAlarmSoundName = 'Alarm';

  // Default and built-in premium sounds map
  final Map<String, String> _builtInSounds = {
    'Notification': 'System Default Notification',
    'Alarm': 'System Default Alarm',
    'Ringtone': 'System Default Ringtone',
    'lively_chime': 'Lively Chime (ডিজিটাল চাইম)',
    'sweet_melody': 'Sweet Chimes (মিষ্টি সুর)',
    'gentle_buzzer': 'Gentle Buzzer (মৃদু বাজার)',
    'retro_alarm': 'Retro Alarm (রেট্রো এলার্ম)',
    'calm_bell': 'Calm Game Bell (শান্ত ঘণ্টা)',
  };

  final Map<String, String> _builtInSoundUrls = {
    'lively_chime': 'https://assets.mixkit.co/active_storage/sfx/2869/2869-120.wav',
    'sweet_melody': 'https://assets.mixkit.co/active_storage/sfx/2019/2019-120.wav',
    'gentle_buzzer': 'https://assets.mixkit.co/active_storage/sfx/911/911-120.wav',
    'retro_alarm': 'https://assets.mixkit.co/active_storage/sfx/903/903-120.wav',
    'calm_bell': 'https://assets.mixkit.co/active_storage/sfx/1657/1657-120.wav',
  };

  Map<String, bool> _isSoundDownloaded = {};

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _checkDownloadedSounds();
  }

  Future<void> _checkDownloadedSounds() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final Map<String, bool> downloaded = {};
      
      downloaded['Notification'] = true;
      downloaded['Alarm'] = true;
      downloaded['Ringtone'] = true;

      for (final soundKey in _builtInSoundUrls.keys) {
        final file = File('${dir.path}/$soundKey.wav');
        downloaded[soundKey] = await file.exists();
      }

      if (mounted) {
        setState(() {
          _isSoundDownloaded = downloaded;
        });
      }
    } catch (e) {
      debugPrint("Error checking downloaded sounds: $e");
    }
  }

  Future<bool> _downloadAndSaveSound(String soundKey) async {
    if (!_builtInSoundUrls.containsKey(soundKey)) return true;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Downloading sound...'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final url = _builtInSoundUrls[soundKey]!;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$soundKey.wav');
        await file.writeAsBytes(response.bodyBytes);
        
        // Close dialog
        if (mounted) Navigator.pop(context);
        
        setState(() {
          _isSoundDownloaded[soundKey] = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sound downloaded and saved locally!'.tr())),
        );
        return true;
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      // Close dialog
      if (mounted) Navigator.pop(context);
      
      debugPrint("Error downloading sound: $e");
      
      // Show warning/workaround dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Download Failed'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'ডাউনলোড করা যায়নি। আপনি ইন্টারনেট থেকে যেকোনো ওয়েবসাইট (যেমন Mixkit বা Pixabay) থেকে আপনার পছন্দের নোটিফিকেশন সাউন্ড ডাউনলোড করে নিচে থাকা "Choose from phone..." অপশনটি ব্যবহার করে তা সেট করে নিতে পারেন।'.tr(),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK'.tr()),
              ),
            ],
          ),
        );
      }
      return false;
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final settings = data['notificationSettings'] as Map<String, dynamic>?;
        if (settings != null && mounted) {
          setState(() {
            _globalNotifications = settings['globalNotifications'] as bool? ?? true;
            _studyGoalReminders = settings['studyGoalReminders'] as bool? ?? true;
            _taskDueWarnings = settings['taskDueWarnings'] as bool? ?? true;
            _spacedRevisionAlerts = settings['spacedRevisionAlerts'] as bool? ?? true;
            _socialHubNotifications = settings['socialHubNotifications'] as bool? ?? true;
            _motivationalPush = settings['motivationalPush'] as bool? ?? true;

            _soundEnabled = settings['soundEnabled'] as bool? ?? true;
            _vibrationEnabled = settings['vibrationEnabled'] as bool? ?? true;
            _volumeLevel = (settings['volumeLevel'] as num?)?.toDouble() ?? 0.8;
            
            _selectedPushSound = settings['selectedPushSound'] as String? ?? settings['selectedSound'] as String? ?? 'Notification';
            _selectedPushSoundName = settings['selectedPushSoundName'] as String? ?? settings['selectedSoundName'] as String? ?? 'Notification';
            _selectedAlarmSound = settings['selectedAlarmSound'] as String? ?? 'Alarm';
            _selectedAlarmSoundName = settings['selectedAlarmSoundName'] as String? ?? 'Alarm';

            // Validate saved sound
            if (!_selectedPushSound.startsWith('content://') && !_selectedPushSound.startsWith('file://') && !_builtInSounds.containsKey(_selectedPushSound)) {
              _selectedPushSound = 'Notification';
              _selectedPushSoundName = _builtInSounds['Notification']!;
            } else if (_builtInSounds.containsKey(_selectedPushSound)) {
              _selectedPushSoundName = _builtInSounds[_selectedPushSound]!;
            }
            
            if (!_selectedAlarmSound.startsWith('content://') && !_selectedAlarmSound.startsWith('file://') && !_builtInSounds.containsKey(_selectedAlarmSound)) {
              _selectedAlarmSound = 'Alarm';
              _selectedAlarmSoundName = _builtInSounds['Alarm']!;
            } else if (_builtInSounds.containsKey(_selectedAlarmSound)) {
              _selectedAlarmSoundName = _builtInSounds[_selectedAlarmSound]!;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading notification settings: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings(String key, dynamic value) async {
    if (_currentUser == null) return;

    setState(() {
      _isSaving = true;
      if (key == 'globalNotifications') _globalNotifications = value as bool;
      if (key == 'studyGoalReminders') _studyGoalReminders = value as bool;
      if (key == 'taskDueWarnings') _taskDueWarnings = value as bool;
      if (key == 'spacedRevisionAlerts') _spacedRevisionAlerts = value as bool;
      if (key == 'socialHubNotifications') _socialHubNotifications = value as bool;
      if (key == 'motivationalPush') _motivationalPush = value as bool;

      if (key == 'soundEnabled') _soundEnabled = value as bool;
      if (key == 'vibrationEnabled') _vibrationEnabled = value as bool;
      if (key == 'volumeLevel') _volumeLevel = value as double;
      if (key == 'selectedPushSound') _selectedPushSound = value as String;
      if (key == 'selectedPushSoundName') _selectedPushSoundName = value as String;
      if (key == 'selectedAlarmSound') _selectedAlarmSound = value as String;
      if (key == 'selectedAlarmSoundName') _selectedAlarmSoundName = value as String;
    });

    if (key == 'soundEnabled' || key == 'vibrationEnabled' || key == 'volumeLevel') {
      _playPreview(false);
    } else if (key == 'selectedPushSound') {
      _playPreview(false);
    } else if (key == 'selectedAlarmSound') {
      _playPreview(true);
    }

    try {
      final settingsMap = {
        'globalNotifications': _globalNotifications,
        'studyGoalReminders': _studyGoalReminders,
        'taskDueWarnings': _taskDueWarnings,
        'spacedRevisionAlerts': _spacedRevisionAlerts,
        'socialHubNotifications': _socialHubNotifications,
        'motivationalPush': _motivationalPush,
        'soundEnabled': _soundEnabled,
        'vibrationEnabled': _vibrationEnabled,
        'volumeLevel': _volumeLevel,
        'selectedPushSound': _selectedPushSound,
        'selectedPushSoundName': _selectedPushSoundName,
        'selectedAlarmSound': _selectedAlarmSound,
        'selectedAlarmSoundName': _selectedAlarmSoundName,
      };

      // Write to local SharedPreferences for background service sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundEnabled', _soundEnabled);
      await prefs.setBool('vibrationEnabled', _vibrationEnabled);
      await prefs.setDouble('volumeLevel', _volumeLevel);
      await prefs.setString('selectedPushSound', _selectedPushSound);
      await prefs.setString('selectedAlarmSound', _selectedAlarmSound);

      await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).set({
        'notificationSettings': settingsMap,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving notification settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating settings: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _playPreview(bool isAlarm) {
    SoundPlayer.playNotificationSoundAndVibration(
      soundName: isAlarm ? _selectedAlarmSound : _selectedPushSound,
      volume: _volumeLevel,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
    );
  }

  Future<void> _pickRingtone(bool isAlarm) async {
    // This feature is only for Android.
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This feature is available on Android only.')),
      );
      return;
    }

    // Use file_picker to open the system's sound/ringtone picker
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      // On Android, the path is what we need for the notification sound.
      // The name can be used for display.
      final soundUri = 'file://${file.path}'; // URI format for sounds
      if (isAlarm) {
        await _saveSettings('selectedAlarmSound', soundUri);
        await _saveSettings('selectedAlarmSoundName', file.name);
      } else {
        await _saveSettings('selectedPushSound', soundUri);
        await _saveSettings('selectedPushSoundName', file.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final primaryContainer = theme.colorScheme.primaryContainer;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                isDark ? primaryColor.withValues(alpha: 0.6) : primaryColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Banner Card
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notifications_active_outlined, color: primaryColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'নোটিফিকেশন কনফিগারেশন',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16, 
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'আপনার পড়াশোনার তাগিদ ও রিমাইন্ডার কাস্টমাইজ করুন।',
                                  style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Global Notification Switch
                  _buildSwitchTile(
                    title: 'গ্লোবাল নোটিফিকেশন',
                    subtitle: 'অ্যাপের সকল নোটিফিকেশন চালু বা বন্ধ রাখুন',
                    value: _globalNotifications,
                    icon: Icons.power_settings_new_rounded,
                    onChanged: (val) => _saveSettings('globalNotifications', val),
                    isHeader: true,
                  ),
                  const SizedBox(height: 16),

                  // Child Toggles (Only interactable if Global Notifications is active)
                  Opacity(
                    opacity: _globalNotifications ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: !_globalNotifications,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: 'স্টাডি গোল রিমাইন্ডার',
                            subtitle: 'দৈনিক পড়াশোনার লক্ষ্য পূরণ না হলে মনে করিয়ে দেওয়া',
                            value: _studyGoalReminders,
                            icon: Icons.timer_outlined,
                            onChanged: (val) => _saveSettings('studyGoalReminders', val),
                          ),
                          _buildSwitchTile(
                            title: 'টাস্ক সময়সীমা অ্যালার্ট',
                            subtitle: 'কোনো নির্দিষ্ট কাজ শেষ হওয়ার পূর্বে নোটিফিকেশন পাঠানো',
                            value: _taskDueWarnings,
                            icon: Icons.alarm_on_rounded,
                            onChanged: (val) => _saveSettings('taskDueWarnings', val),
                          ),
                          _buildSwitchTile(
                            title: 'রিভিশন রিমাইন্ডার',
                            subtitle: '১-৪-৭ স্পেসড রিভিশন শিডিউলের রিভিশন মনে করিয়ে দেওয়া',
                            value: _spacedRevisionAlerts,
                            icon: Icons.sync_problem_rounded,
                            onChanged: (val) => _saveSettings('spacedRevisionAlerts', val),
                          ),
                          _buildSwitchTile(
                            title: 'সোশ্যাল নোটিফিকেশন',
                            subtitle: 'নতুন ফ্রেন্ড রিকোয়েস্ট বা সোশ্যাল হাবের আপডেট নোটিফিকেশন',
                            value: _socialHubNotifications,
                            icon: Icons.people_outline_rounded,
                            onChanged: (val) => _saveSettings('socialHubNotifications', val),
                          ),
                          _buildSwitchTile(
                            title: 'অনুপ্রেরণামূলক পুশ',
                            subtitle: 'প্রতিদিন পড়াশোনা শুরু করার জন্য মোটিভেশনাল মেসেজ',
                            value: _motivationalPush,
                            icon: Icons.wb_incandescent_outlined,
                            onChanged: (val) => _saveSettings('motivationalPush', val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Sound & Vibration Settings Card
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.volume_up_rounded, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'সাউন্ড ও ভাইব্রেশন সেটিংস',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16, 
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          // Sound Toggle
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'নোটিফিকেশন সাউন্ড', 
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'নোটিফিকেশন আসার সময়ে সাউন্ড প্লে হবে', 
                                        style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 28,
                                      child: Transform.scale(
                                        scale: 0.75,
                                        child: Switch(
                                          value: _soundEnabled,
                                          onChanged: _globalNotifications ? (val) => _saveSettings('soundEnabled', val) : null,
                                          activeThumbColor: primaryColor,
                                          activeTrackColor: primaryColor.withValues(alpha: 0.3),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _soundEnabled ? 'চালু (ON)' : 'বন্ধ (OFF)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: _soundEnabled 
                                            ? (isDark ? Colors.green.shade300 : Colors.green.shade700) 
                                            : onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Vibration Toggle
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ভাইব্রেশন', 
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'নোটিফিকেশন আসার সাথে ডিভাইস ভাইব্রেট করবে', 
                                        style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 28,
                                      child: Transform.scale(
                                        scale: 0.75,
                                        child: Switch(
                                          value: _vibrationEnabled,
                                          onChanged: _globalNotifications ? (val) => _saveSettings('vibrationEnabled', val) : null,
                                          activeThumbColor: primaryColor,
                                          activeTrackColor: primaryColor.withValues(alpha: 0.3),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _vibrationEnabled ? 'চালু (ON)' : 'বন্ধ (OFF)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: _vibrationEnabled 
                                            ? (isDark ? Colors.green.shade300 : Colors.green.shade700) 
                                            : onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          if (_soundEnabled) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'পুশ নোটিফিকেশন সাউন্ড', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
                                ),
                                TextButton.icon(
                                  onPressed: _globalNotifications ? () => _playPreview(false) : null,
                                  icon: Icon(Icons.play_circle_outline_rounded, size: 18, color: primaryColor),
                                  label: Text(
                                    'টেস্ট সাউন্ড',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Push Sound Picker UI
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: onSurfaceVariant.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedPushSoundName,
                                      style: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down_rounded),
                                    onSelected: (String value) async {
                                      if (value == 'pick_custom') {
                                        _pickRingtone(false);
                                      } else {
                                        if (value != 'Notification' && value != 'Alarm' && value != 'Ringtone') {
                                          final isCached = _isSoundDownloaded[value] == true;
                                          if (!isCached) {
                                            final success = await _downloadAndSaveSound(value);
                                            if (!success) return; // Stop if download failed
                                          }
                                        }
                                        _saveSettings('selectedPushSound', value);
                                        _saveSettings('selectedPushSoundName', _builtInSounds[value] ?? value);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return [
                                        ..._builtInSounds.entries.map((entry) {
                                          final isSystem = entry.key == 'Notification' || entry.key == 'Alarm' || entry.key == 'Ringtone';
                                          final isDownloaded = isSystem || (_isSoundDownloaded[entry.key] == true);
                                          return PopupMenuItem<String>(
                                            value: entry.key,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(entry.value)),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  isDownloaded ? Icons.check_circle_rounded : Icons.cloud_download_outlined,
                                                  size: 18,
                                                  color: isDownloaded ? Colors.green : Colors.grey,
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        if (Platform.isAndroid) const PopupMenuDivider(),
                                        if (Platform.isAndroid)
                                          const PopupMenuItem<String>(
                                            value: 'pick_custom',
                                            child: Row(
                                              children: [
                                                Icon(Icons.music_note_rounded, size: 18),
                                                SizedBox(width: 8),
                                                Text('Choose from phone...'),
                                              ],
                                            ),
                                          ),
                                      ];
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'অ্যালার্ম সাউন্ড', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
                                ),
                                TextButton.icon(
                                  onPressed: _globalNotifications ? () => _playPreview(true) : null,
                                  icon: Icon(Icons.play_circle_outline_rounded, size: 18, color: primaryColor),
                                  label: Text(
                                    'টেস্ট সাউন্ড',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Alarm Sound Picker UI
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: onSurfaceVariant.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedAlarmSoundName,
                                      style: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down_rounded),
                                    onSelected: (String value) async {
                                      if (value == 'pick_custom') {
                                        _pickRingtone(true);
                                      } else {
                                        if (value != 'Notification' && value != 'Alarm' && value != 'Ringtone') {
                                          final isCached = _isSoundDownloaded[value] == true;
                                          if (!isCached) {
                                            final success = await _downloadAndSaveSound(value);
                                            if (!success) return; // Stop if download failed
                                          }
                                        }
                                        _saveSettings('selectedAlarmSound', value);
                                        _saveSettings('selectedAlarmSoundName', _builtInSounds[value] ?? value);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return [
                                        ..._builtInSounds.entries.map((entry) {
                                          final isSystem = entry.key == 'Notification' || entry.key == 'Alarm' || entry.key == 'Ringtone';
                                          final isDownloaded = isSystem || (_isSoundDownloaded[entry.key] == true);
                                          return PopupMenuItem<String>(
                                            value: entry.key,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(entry.value)),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  isDownloaded ? Icons.check_circle_rounded : Icons.cloud_download_outlined,
                                                  size: 18,
                                                  color: isDownloaded ? Colors.green : Colors.grey,
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        if (Platform.isAndroid) const PopupMenuDivider(),
                                        if (Platform.isAndroid)
                                          const PopupMenuItem<String>(
                                            value: 'pick_custom',
                                            child: Row(
                                              children: [
                                                Icon(Icons.music_note_rounded, size: 18),
                                                SizedBox(width: 8),
                                                Text('Choose from phone...'),
                                              ],
                                            ),
                                          ),
                                      ];
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'সাউন্ডের মাত্রা', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
                                ),
                                Text(
                                  '${(_volumeLevel * 100).toInt()}%', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                                ),
                              ],
                            ),
                            Slider(
                              value: _volumeLevel,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              activeColor: primaryColor,
                              inactiveColor: primaryColor.withValues(alpha: 0.2),
                              onChanged: _globalNotifications
                                  ? (val) => _saveSettings('volumeLevel', val)
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Important Note Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isDark ? Colors.amber.shade700.withValues(alpha: 0.5) : Colors.amber.shade300, 
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded, 
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade800, 
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'বিশেষ দ্রষ্টব্য: ইসলামিক লাইফ ফিচারের নামাজের ওয়াক্ত ও আযানের অ্যালার্মগুলো এই গ্লোবাল সেটিং এর আওতামুক্ত। নামাজের নোটিফিকেশনগুলো সম্পূর্ণভাবে নিয়ন্ত্রণ করতে দয়া করে "Islamic Life" অপশনে যান।',
                            style: TextStyle(
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Small Loading Indicator for background saves
                  if (_isSaving)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    bool isHeader = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    
    Color cardBgColor = isHeader 
        ? primaryColor.withValues(alpha: 0.08) 
        : theme.cardColor;
        
    Color cardBorderColor = isHeader 
        ? primaryColor.withValues(alpha: 0.25) 
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isHeader ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 28,
                  child: Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: primaryColor,
                      activeTrackColor: primaryColor.withValues(alpha: 0.3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? 'চালু (ON)' : 'বন্ধ (OFF)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: value 
                        ? (isDark ? Colors.green.shade300 : Colors.green.shade700) 
                        : onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
