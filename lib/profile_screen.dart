import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // ক্লিপবোর্ডে কপি করার জন্য
import 'login_screen.dart'; // লগইন স্ক্রিন ইমপোর্ট করা হলো
import 'social_hub_screen.dart'; // সোশ্যাল হাব স্ক্রিন ইমপোর্ট করা হলো
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'about_us_screen.dart';
import 'theme_manager.dart';
import 'gamification_service.dart';
import 'language_manager.dart';
import 'app_lock_service.dart';
import 'app_lock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_backup_screen.dart';
import 'notifications_hub_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user = FirebaseAuth.instance.currentUser;
  String? _photoUrl;
  bool _autoLoginEnabled = true;
  bool _monthlyLoginEnabled = false;
  
  String _bio = "Let's study hard together!";
  String _institution = "No Institution Set";
  String _academicYear = "";
  String _major = "";
  double _dailyGoal = 2.0;
  int _totalTasksDone = 0;
  int _currentStreak = 0;
  int _totalXP = 0;
  List<String> _unlockedBadges = [];

  @override
  void initState() {
    super.initState();
    _loadProfileDetails();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoLoginEnabled = prefs.getBool('auto_login_enabled') ?? true;
        _monthlyLoginEnabled = prefs.getBool('monthly_password_login_enabled') ?? false;
      });
    }
  }

  Future<void> _loadProfileDetails() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Reload user to get latest displayName/photoURL from Firebase Auth
    try {
      await currentUser.reload();
    } catch (e) {
      debugPrint("Error reloading user auth: $e");
    }
    
    final updatedUser = FirebaseAuth.instance.currentUser;
    
    setState(() {
      _user = updatedUser;
    });
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(updatedUser?.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _bio = data['bio'] as String? ?? "Let's study hard together!";
            _institution = data['institution'] as String? ?? "No Institution Set";
            _academicYear = data['academicYear'] as String? ?? "";
            _major = data['major'] as String? ?? "";
            _dailyGoal = (data['dailyStudyGoalHours'] ?? 2.0) as double;
            _photoUrl = data['photoUrl'] as String? ?? updatedUser?.photoURL;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _photoUrl = updatedUser?.photoURL;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile details: $e");
    }

    try {
      final gData = await GamificationService.getUserGamificationData();
      final streak = await GamificationService.calculateStreak();
      if (mounted) {
        setState(() {
          _totalTasksDone = gData['totalTasksDone'] ?? 0;
          _totalXP = gData['totalXP'] ?? 0;
          _unlockedBadges = List<String>.from(gData['badges'] ?? []);
          _currentStreak = streak;
        });
      }
    } catch (e) {
      debugPrint("Error loading gamification details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ১. ইউজারের ছবি ও নাম
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                        ? (_photoUrl!.startsWith('http') ? NetworkImage(_photoUrl!) : FileImage(File(_photoUrl!)) as ImageProvider)
                        : null,
                    child: (_photoUrl == null || _photoUrl!.isEmpty)
                        ? Text(
                            _user?.displayName?.isNotEmpty == true
                                ? _user!.displayName!.substring(0, 1).toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user?.displayName ?? 'StudyMate User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_user?.email != null && _user!.email!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _user!.email!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                  
                  // Institution / Year / Major
                  if (_institution.isNotEmpty || _academicYear.isNotEmpty || _major.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_institution.isNotEmpty ? _institution : "StudyMate"}'
                      '${_academicYear.isNotEmpty ? " • $_academicYear" : ""}'
                      '${_major.isNotEmpty ? " • $_major" : ""}',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Bio / Motto
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _bio,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ৫. ইউনিক আইডি কপি করার অপশন
                  InkWell(
                    onTap: () async {
                      if (_user?.uid != null) {
                        await Clipboard.setData(ClipboardData(text: _user!.uid));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ID copied to clipboard!'.tr())));
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${_user?.uid ?? 'Unknown'.tr()}',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ২. স্টাডি স্ট্যাটিসটিক্স
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(context, _totalTasksDone.toString(), 'Tasks Done'.tr(), Icons.check_circle_rounded, Colors.green),
                      _buildStatCard(context, '${_dailyGoal.toInt()}h', 'Goal/Day'.tr(), Icons.access_time_filled_rounded, Colors.blue),
                      _buildStatCard(context, _currentStreak.toString(), 'Day Streak'.tr(), Icons.local_fire_department_rounded, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Gamification Level and XP Card
                  _buildLevelProgressCard(),
                  const SizedBox(height: 24),
                  
                  // Badges Section
                  _buildBadgesSection(),
                  const SizedBox(height: 32),

                  // ৩. অ্যাপ সেটিংস লিস্ট
                  _buildListTile(context, Icons.person_outline_rounded, 'Edit Profile', onTap: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    if (updated == true) {
                      _loadProfileDetails();
                    }
                  }),
                  _buildListTile(
                    context,
                    Icons.security_rounded,
                    'Security Settings',
                    onTap: () => _showSecuritySettingsBottomSheet(context),
                  ),
                  _buildListTile(
                    context,
                    Icons.cloud_sync_rounded,
                    'Cloud Backup & Sync',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CloudBackupScreen()),
                      );
                    },
                  ),
                  _buildListTile(context, Icons.dark_mode_outlined, 'Dark Mode', isToggle: true),

                  _buildListTile(
                    context,
                    Icons.language_rounded,
                    'Language (ভাষা)',
                    onTap: () => _showLanguageDialog(context),
                  ),
                   _buildListTile(
                    context,
                    Icons.info_outline_rounded,
                    'About Us',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // ৪. লগআউট বাটন
                  ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false, // লগআউট হওয়ার পর আগের সব স্ক্রিন (হিস্ট্রি) মুছে ফেলবে
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Log Out'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showSecuritySettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Security Settings'.tr(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Change Password Button
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text('Change Password'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(context); // Close Security Settings sheet
                        _showChangePasswordBottomSheet(context); // Open Change Password sheet
                      },
                    ),
                  ),

                  // Auto Login Switch
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.login_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text('Auto Login'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Remembers you on this device'.tr(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Switch(
                        value: _autoLoginEnabled,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('auto_login_enabled', val);
                          setModalState(() {
                            _autoLoginEnabled = val;
                          });
                          setState(() {
                            _autoLoginEnabled = val;
                          });
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  // Monthly Password Verification Switch
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_autoLoginEnabled ? Theme.of(context).colorScheme.primary : Colors.grey).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: _autoLoginEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                      ),
                      title: Text('Monthly Password Check'.tr(), style: TextStyle(fontWeight: FontWeight.w600, color: _autoLoginEnabled ? null : Colors.grey)),
                      subtitle: Text('Force login once a month so you do not forget your password'.tr(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Switch(
                        value: _autoLoginEnabled && _monthlyLoginEnabled,
                        onChanged: _autoLoginEnabled
                            ? (val) async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('monthly_password_login_enabled', val);
                                setModalState(() {
                                  _monthlyLoginEnabled = val;
                                });
                                setState(() {
                                  _monthlyLoginEnabled = val;
                                });
                              }
                            : null,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  // App Lock Switch
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.security_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text('App Lock'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Switch(
                        value: AppLockService().isAppLockEnabled(),
                        onChanged: (val) async {
                          Navigator.pop(context); // Close Security Settings sheet
                          await _handleAppLockToggle(val); // Open App Lock sheet
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAppLockToggle(bool enable) async {
    if (enable) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppLockScreen(mode: AppLockMode.setup),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppLockScreen(mode: AppLockMode.disable),
        ),
      );
    }
    setState(() {});
  }

  Widget _buildStatCard(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.all(16),
      decoration: ThemeManager.getCardDecoration(context),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, {bool isToggle = false, VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: isToggle
            ? ListenableBuilder(
                listenable: ThemeManager(),
                builder: (context, _) {
                  return Switch(
                    value: ThemeManager().isDarkMode,
                    onChanged: (val) {
                      ThemeManager().toggleTheme(val);
                    },
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  );
                },
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: isToggle ? null : onTap,
      ),
    );
  }

  Widget _buildLevelProgressCard() {
    final level = GamificationService.getLevel(_totalXP);
    final progress = GamificationService.getLevelProgress(_totalXP);
    final title = GamificationService.getLevelTitle(level);
    final xpNext = GamificationService.xpForNextLevel(_totalXP);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'Level '.tr()}$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalXP${' XP'.tr()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$xpNext${' XP to next level'.tr()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Unlocked Badges'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: GamificationService.allBadges.length,
            itemBuilder: (context, index) {
              final badge = GamificationService.allBadges[index];
              final isUnlocked = _unlockedBadges.contains(badge['id']);
              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Opacity(
                  opacity: isUnlocked ? 1.0 : 0.4,
                  child: Tooltip(
                    message: badge['description'],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          badge['icon'] as IconData,
                          color: isUnlocked ? (badge['color'] as Color) : Colors.grey,
                          size: 36,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge['name'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Language'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.abc_rounded),
                title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: LanguageManager().currentLanguage == 'en'
                    ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  LanguageManager().changeLanguage('en');
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('বাংলা', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: LanguageManager().currentLanguage == 'bn'
                    ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  LanguageManager().changeLanguage('bn');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordBottomSheet(BuildContext context) {
    if (_user == null) return;

    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_reset_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Change Password'.tr(),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Current Password
                      TextField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscureCurrent = !obscureCurrent;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // New Password
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password'.tr(),
                          prefixIcon: const Icon(Icons.lock_open_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscureNew = !obscureNew;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm New Password
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: () async {
                            final currentPassword = currentPasswordController.text;
                            final newPassword = newPasswordController.text;
                            final confirmPassword = confirmPasswordController.text;

                            if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Please fill all fields'.tr())),
                              );
                              return;
                            }

                            if (_user!.email == null || _user!.email!.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Email not found. Cannot change password.'.tr())),
                              );
                              return;
                            }

                            if (newPassword.length < 6) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Password must be at least 6 characters'.tr())),
                              );
                              return;
                            }

                            if (newPassword != confirmPassword) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Passwords do not match'.tr())),
                              );
                              return;
                            }

                            setModalState(() {
                              isLoading = true;
                            });

                            try {
                              // Reauthenticate user
                              final AuthCredential credential = EmailAuthProvider.credential(
                                email: _user!.email!,
                                password: currentPassword,
                              );
                              await _user!.reauthenticateWithCredential(credential);

                              // Update password
                              await _user!.updatePassword(newPassword);

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Password changed successfully!'.tr()),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              String errorMessage = 'Error updating password'.tr();
                              if (e.code == 'wrong-password') {
                                errorMessage = 'Incorrect current password'.tr();
                              } else if (e.code == 'weak-password') {
                                errorMessage = 'The password is too weak'.tr();
                              } else if (e.code == 'requires-recent-login') {
                                errorMessage = 'Please log out and log in again'.tr();
                              }
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('An error occurred: $e'.tr()),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            } finally {
                              setModalState(() {
                                isLoading = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text('Update Password'.tr()),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}