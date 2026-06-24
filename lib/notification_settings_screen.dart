import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notification_service.dart';

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
  String _selectedSound = 'Beep';

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
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
            _selectedSound = settings['selectedSound'] as String? ?? 'Beep';
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
      if (key == 'selectedSound') _selectedSound = value as String;
    });

    if (key == 'soundEnabled' || key == 'vibrationEnabled' || key == 'volumeLevel' || key == 'selectedSound') {
      _playPreview();
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
        'selectedSound': _selectedSound,
      };

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

  void _playPreview() {
    LocalNotificationService.playNotificationSoundAndVibration(
      soundName: _selectedSound,
      volume: _volumeLevel,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
    );
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
                                  'নোটিফিকেশন টিউন', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
                                ),
                                TextButton.icon(
                                  onPressed: _globalNotifications ? _playPreview : null,
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
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSound,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(color: onSurface),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: ['Beep', 'Chime', 'Marimba', 'Bell', 'Digital']
                                  .map((sound) => DropdownMenuItem(
                                        value: sound,
                                        child: Text(sound),
                                      ))
                                  .toList(),
                              onChanged: _globalNotifications
                                  ? (val) {
                                      if (val != null) _saveSettings('selectedSound', val);
                                    }
                                  : null,
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
