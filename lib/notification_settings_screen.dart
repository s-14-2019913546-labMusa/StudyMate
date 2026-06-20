import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _saveSettings(String key, bool value) async {
    if (_currentUser == null) return;

    setState(() {
      _isSaving = true;
      if (key == 'globalNotifications') _globalNotifications = value;
      if (key == 'studyGoalReminders') _studyGoalReminders = value;
      if (key == 'taskDueWarnings') _taskDueWarnings = value;
      if (key == 'spacedRevisionAlerts') _spacedRevisionAlerts = value;
      if (key == 'socialHubNotifications') _socialHubNotifications = value;
      if (key == 'motivationalPush') _motivationalPush = value;
    });

    try {
      final settingsMap = {
        'globalNotifications': _globalNotifications,
        'studyGoalReminders': _studyGoalReminders,
        'taskDueWarnings': _taskDueWarnings,
        'spacedRevisionAlerts': _spacedRevisionAlerts,
        'socialHubNotifications': _socialHubNotifications,
        'motivationalPush': _motivationalPush,
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

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0F3625);
    const accentGreen = Color(0xFF1D5C42);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, accentGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
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
                              color: accentGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_active_outlined, color: accentGreen, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'নোটিফিকেশন কনফিগারেশন',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryGreen),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'আপনার পড়াশোনার তাগিদ ও রিমাইন্ডার কাস্টমাইজ করুন।',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
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

                  const SizedBox(height: 32),

                  // Important Note Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.amber.shade300, width: 1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'বিশেষ দ্রষ্টব্য: ইসলামিক লাইফ ফিচারের নামাজের ওয়াক্ত ও আযানের অ্যালার্মগুলো এই গ্লোবাল সেটিং এর আওতামুক্ত। নামাজের নোটিফিকেশনগুলো সম্পূর্ণভাবে নিয়ন্ত্রণ করতে দয়া করে "Islamic Life" অপশনে যান।',
                            style: TextStyle(
                              color: Colors.amber.shade900,
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentGreen))),
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
    const primaryGreen = Color(0xFF0F3625);
    const accentGreen = Color(0xFF1D5C42);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isHeader ? accentGreen.withValues(alpha: 0.05) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isHeader ? accentGreen.withValues(alpha: 0.2) : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHeader ? accentGreen.withValues(alpha: 0.15) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isHeader ? accentGreen : Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isHeader ? primaryGreen : Colors.black87,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: accentGreen,
          activeTrackColor: accentGreen.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
