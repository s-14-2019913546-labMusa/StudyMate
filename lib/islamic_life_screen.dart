import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:url_launcher/url_launcher.dart';
import 'islamic_service.dart';
import 'islamic_daily_service.dart';
import 'local_notification_service.dart';
import 'quran_reader_screen.dart';
import 'qibla_compass_screen.dart';
import 'tasbeeh_counter_screen.dart';
import 'prayer_history_screen.dart';
import 'language_manager.dart';
import 'widgets/sound_picker_widget.dart';

class IslamicLifeScreen extends StatefulWidget {
  const IslamicLifeScreen({super.key});

  @override
  State<IslamicLifeScreen> createState() => _IslamicLifeScreenState();
}

class _IslamicLifeScreenState extends State<IslamicLifeScreen> {
  bool _isLoading = true;
  String _locationName = "Dhaka (Fallback)";
  Map<String, String>? _prayerTimes;
  Map<String, String>? _dailyVerse;
  Map<String, String>? _dailyHadith;

  Timer? _countdownTimer;
  String _nextPrayerName = "";
  Duration _nextPrayerRemaining = Duration.zero;

  // Custom states
  bool _isCloseToEnd = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _notifiedEvents = {};
  Map<String, Map<String, bool>> _historyData = {};

  // ── Islamic Notification Settings (independent from global settings) ──────
  // Keys: prayerStart, prayerWarning, jummaReminder, prayerAlarmEnabled, selectedPrayerAlarmSound, selectedPrayerAlarmSoundName
  Map<String, dynamic> _islamicNotifSettings = {
    'prayerStart': true,
    'prayerWarning': true,
    'jummaReminder': true,
    'prayerAlarmEnabled': false,
    'selectedPrayerAlarmSound': 'makkah_adhan',
    'selectedPrayerAlarmSoundName': 'মক্কার আজান (Makkah Adhan)',
  };
  final Map<String, String> _builtInSounds = {
    'makkah_adhan': 'মক্কার আজান (Makkah Adhan)',
    'madinah_adhan': 'মদিনার আজান (Madinah Adhan)',
  };
  final Map<String, String> _systemAlarmSounds = {
    'Alarm': 'System Default Alarm',
    'Ringtone': 'System Default Ringtone',
  };
  static const String _islamicNotifFile = 'islamic_notif_settings.json';

  // Friday Special Checklist States
  final List<Map<String, dynamic>> _jummaSunnahs = [
    {
      'title': LanguageManager().isBengali
          ? 'গোসল করা'
          : 'Perform Ghusl (Bath)',
      'done': false,
    },
    {
      'title': LanguageManager().isBengali
          ? 'পরিষ্কার পোশাক পরা ও সুগন্ধি লাগানো'
          : 'Wear Clean Clothes & Apply Attar',
      'done': false,
    },
    {
      'title': LanguageManager().isBengali
          ? 'সূরা আল-কাহাফ তেলাওয়াত করা'
          : 'Recite Surah Al-Kahf',
      'done': false,
    },
    {
      'title': LanguageManager().isBengali
          ? 'রাসূলুল্লাহ (সা.) এর ওপর দরুদ পাঠ করা'
          : 'Send Salawat / Durood upon Prophet (pbuh)',
      'done': false,
    },
    {
      'title': LanguageManager().isBengali
          ? 'জুমার সালাতে আগে যাওয়া'
          : 'Go Early to Mosque for Jummah',
      'done': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyContent();
    _loadHistoryData();
    _loadIslamicNotifSettings();
    _loadLocationAndPrayerTimes();

    // Periodically update the countdown timer and check notifications every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prayerTimes != null) {
        _updateCountdown();
        _checkNotifications();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadDailyContent() {
    setState(() {
      _dailyVerse = IslamicService.getVerseOfTheDay();
      _dailyHadith = IslamicService.getHadithOfTheDay();
    });
  }

  Future<void> _loadLocationAndPrayerTimes() async {
    setState(() => _isLoading = true);

    // 1. Get position
    final position = await IslamicService.determinePosition();

    double lat = 23.8103; // Dhaka default
    double lng = 90.4125;
    String locName = "ঢাকা বিভাগ (ডিফল্ট)";

    if (position != null) {
      lat = position.latitude;
      lng = position.longitude;
      locName =
          "ডিভাইস লোকেশন (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})";
    }

    // 2. Fetch timings
    final timings = await IslamicService.fetchPrayerTimes(lat, lng);

    if (mounted) {
      setState(() {
        _prayerTimes = timings;
        _locationName = locName;
        _isLoading = false;
      });
      _updateCountdown();
      LocalNotificationService.schedulePrayerNotifications(
        timings,
        _islamicNotifSettings,
      );
    }
  }

  Future<void> _loadPrayerTimesForDivision(String divisionKey) async {
    setState(() => _isLoading = true);

    final division = IslamicService.divisionData[divisionKey];
    if (division == null) return;

    double lat = division['lat'] as double;
    double lng = division['lng'] as double;
    String nameBangla = division['name'] as String;

    final timings = await IslamicService.fetchPrayerTimes(lat, lng);

    if (mounted) {
      setState(() {
        _prayerTimes = timings;
        _locationName = "$nameBangla বিভাগ";
        _isLoading = false;
      });
      _updateCountdown();
      LocalNotificationService.schedulePrayerNotifications(
        timings,
        _islamicNotifSettings,
      );
    }
  }

  Future<void> _loadHistoryData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_history_data.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = json.decode(content) as Map<String, dynamic>;
        final Map<String, Map<String, bool>> temp = {};
        decoded.forEach((dateKey, value) {
          if (value is Map) {
            temp[dateKey] = Map<String, bool>.from(
              value.map((k, v) => MapEntry(k as String, v as bool)),
            );
          }
        });
        setState(() {
          _historyData = temp;
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  Future<void> _saveHistoryData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prayer_history_data.json');
      await file.writeAsString(json.encode(_historyData));
    } catch (e) {
      debugPrint("Error saving history: $e");
    }
  }

  // ── Islamic Notification Settings persistence ─────────────────────────────
  Future<void> _loadIslamicNotifSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_islamicNotifFile');

      if (await file.exists()) {
        final decoded =
            json.decode(await file.readAsString()) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _islamicNotifSettings = {
              'prayerStart': decoded['prayerStart'] as bool? ?? true,
              'prayerWarning': decoded['prayerWarning'] as bool? ?? true,
              'jummaReminder': decoded['jummaReminder'] as bool? ?? true,
              'prayerAlarmEnabled':
                  decoded['prayerAlarmEnabled'] as bool? ?? false,
              'selectedPrayerAlarmSound':
                  decoded['selectedPrayerAlarmSound'] as String? ?? 'makkah_adhan',
              'selectedPrayerAlarmSoundName':
                  decoded['selectedPrayerAlarmSoundName'] as String? ??
                  'মক্কার আজান (Makkah Adhan)',
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading Islamic notif settings: $e');
    }
  }

  Future<void> _saveIslamicNotifSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_islamicNotifFile');
      await file.writeAsString(json.encode(_islamicNotifSettings));
      if (_prayerTimes != null) {
        await LocalNotificationService.schedulePrayerNotifications(
          _prayerTimes!,
          _islamicNotifSettings,
        );
      }
    } catch (e) {
      debugPrint('Error saving Islamic notif settings: $e');
    }
  }



  void _showIslamicNotificationSettings() {
    const goldAccent = Color(0xFFE5B842);
    const cardBg = Color(0xFF162D24);
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: goldAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: goldAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ইসলামিক নোটিফিকেশন',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'শুধুমাত্র এখান থেকে নিয়ন্ত্রণ করা যাবে',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    _buildNotifTile(
                      ctx,
                      setModal,
                      icon: Icons.alarm_rounded,
                      title: 'নামাজ শুরুর নোটিফিকেশন',
                      subtitle: 'ওয়াক্ত শুরুর ৫ মিনিট পর অনুস্মারক',
                      key: 'prayerStart',
                      goldAccent: goldAccent,
                    ),
                    _buildNotifTile(
                      ctx,
                      setModal,
                      icon: Icons.timer_off_rounded,
                      title: 'ওয়াক্ত শেষের সতর্কতা',
                      subtitle: 'ওয়াক্ত শেষ হওয়ার ২০ মিনিট আগে সতর্কতা',
                      key: 'prayerWarning',
                      goldAccent: goldAccent,
                    ),
                    _buildNotifTile(
                      ctx,
                      setModal,
                      icon: Icons.mosque_rounded,
                      title: 'জুমার অনুস্মারক',
                      subtitle: 'প্রতি শুক্রবার বিশেষ জুমার নোটিফিকেশন',
                      key: 'jummaReminder',
                      goldAccent: goldAccent,
                    ),
                    _buildNotifTile(
                      ctx,
                      setModal,
                      icon: Icons.notifications_active_rounded,
                      title: 'সালাতের ওয়াক্তে আযান/অ্যালার্ম বাজবে',
                      subtitle:
                          'ওয়াক্ত শুরু হলে নোটিফিকেশনের সাথে আযান/অ্যালার্ম বাজবে',
                      key: 'prayerAlarmEnabled',
                      goldAccent: goldAccent,
                    ),
                    if (_islamicNotifSettings['prayerAlarmEnabled'] ??
                        false) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8.0,
                          right: 8.0,
                          bottom: 8.0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'সালাত অ্যালার্ম সাউন্ড',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                                Expanded(
                                  child: SoundPickerWidget(
                                    selectedSoundKey: _islamicNotifSettings['selectedPrayerAlarmSound'] ?? 'makkah_adhan',
                                    selectedSoundName: _islamicNotifSettings['selectedPrayerAlarmSoundName'] ?? 'মক্কার আজান (Makkah Adhan)',
                                    systemSounds: _systemAlarmSounds,
                                    favoriteSounds: _builtInSounds,
                                    isAlarm: true,
                                    primaryColor: goldAccent,
                                    onSoundSelected: (value) async {
                                      final selectedName = _systemAlarmSounds[value] ?? _builtInSounds[value] ?? value;
                                      setModal(() {
                                        _islamicNotifSettings['selectedPrayerAlarmSound'] = value;
                                        _islamicNotifSettings['selectedPrayerAlarmSoundName'] = selectedName;
                                      });
                                      setState(() {
                                        _islamicNotifSettings['selectedPrayerAlarmSound'] = value;
                                        _islamicNotifSettings['selectedPrayerAlarmSoundName'] = selectedName;
                                      });
                                      await _saveIslamicNotifSettings();
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white38,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'এই সেটিংসগুলো গলোবাল অ্যাপ সেটিংস থেকে আলাদা এবং শুধুমাত্র ইসলামিক লাইফ সেকশন থেকেই নিয়ন্ত্রণ করা যাবে।',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotifTile(
    BuildContext ctx,
    StateSetter setModal, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String key,
    required Color goldAccent,
  }) {
    final bool isOn = _islamicNotifSettings[key] ?? true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isOn
                ? goldAccent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isOn ? goldAccent : Colors.white38,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isOn ? Colors.white : Colors.white54,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: Switch(
          value: isOn,
          activeTrackColor: goldAccent.withValues(alpha: 0.5),
          activeThumbColor: goldAccent,
          onChanged: (val) {
            setModal(() => _islamicNotifSettings[key] = val);
            setState(() => _islamicNotifSettings[key] = val);
            _saveIslamicNotifSettings();
          },
        ),
      ),
    );
  }

  void _togglePrayerTick(String prayerKey) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      if (!_historyData.containsKey(todayKey)) {
        _historyData[todayKey] = {
          'Fajr': false,
          'Dhuhr': false,
          'Asr': false,
          'Maghrib': false,
          'Isha': false,
        };
      }
      final currentVal = _historyData[todayKey]?[prayerKey] ?? false;
      _historyData[todayKey]?[prayerKey] = !currentVal;
    });
    _saveHistoryData();
  }

  void _playNotificationSound({bool isSalatAlarm = false}) async {
    if (isSalatAlarm &&
        (_islamicNotifSettings['prayerAlarmEnabled'] ?? false)) {
      final soundName =
          _islamicNotifSettings['selectedPrayerAlarmSound'] ?? 'makkah_adhan';
      await SoundPlayer.playNotificationSoundAndVibration(
        soundName: soundName,
        volume: 1.0,
        soundEnabled: true,
        vibrationEnabled: true,
        isAlarm: true,
        looping: false, // Salat Alarm plays once fully, no looping.
      );
    } else {
      try {
        await _audioPlayer.play(
          UrlSource(
            'https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav',
          ),
        );
      } catch (e) {
        SystemSound.play(SystemSoundType.click);
      }
    }
  }

  void _checkNotifications() {
    if (_prayerTimes == null) return;
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    final List<Map<String, String>> prayers = [
      {
        'key': 'Fajr',
        'name': 'ফজর',
        'start': _prayerTimes!['Fajr']!,
        'end': _prayerTimes!['Sunrise']!,
      },
      {
        'key': 'Dhuhr',
        'name': now.weekday == DateTime.friday ? 'জুমা' : 'যোহর',
        'start': _prayerTimes!['Dhuhr']!,
        'end': _prayerTimes!['Asr']!,
      },
      {
        'key': 'Asr',
        'name': 'আসর',
        'start': _prayerTimes!['Asr']!,
        'end': _prayerTimes!['Maghrib']!,
      },
      {
        'key': 'Maghrib',
        'name': 'মাগরিব',
        'start': _prayerTimes!['Maghrib']!,
        'end': _prayerTimes!['Isha']!,
      },
      {
        'key': 'Isha',
        'name': 'এশা',
        'start': _prayerTimes!['Isha']!,
        'end': _prayerTimes!['Fajr']!,
      },
    ];

    for (final prayer in prayers) {
      final pKey = prayer['key']!;
      final pName = prayer['name']!;
      final startStr = prayer['start']!;
      final endStr = prayer['end']!;

      var start = _parseTime(startStr);
      var end = _parseTime(endStr);

      if (pKey == 'Isha') {
        end = _parseTime(endStr, tomorrow: true);
        if (now.hour < 12) {
          start = start.subtract(const Duration(days: 1));
          end = end.subtract(const Duration(days: 1));
        }
      }

      // 1. 5 minutes after start → only fire if prayerStart toggle is ON
      final diffFromStart = now.difference(start);
      if ((_islamicNotifSettings['prayerStart'] ?? true) &&
          diffFromStart.inMinutes == 5 &&
          diffFromStart.inSeconds >= 0 &&
          diffFromStart.inSeconds < 3) {
        final eventId = "${todayKey}_${pKey}_start_5m";
        if (!_notifiedEvents.contains(eventId)) {
          _notifiedEvents.add(eventId);
          _triggerNotification(
            "নামাজের সময়",
            "সালাতের ওয়াক্ত শুরু হয়েছে! ৫ মিনিট অতিবাহিত হয়েছে। অনুগ্রহ করে জুমআ/জামায়াতে সালাত আদায়ের প্রস্তুতি নিন।",
            false,
            isSalatAlarm: true,
          );
        }
      }

      // 2. 20 minutes before end → only fire if prayerWarning toggle is ON
      final diffUntilEnd = end.difference(now);
      if ((_islamicNotifSettings['prayerWarning'] ?? true) &&
          diffUntilEnd.inMinutes == 20 &&
          diffUntilEnd.inSeconds >= 0 &&
          diffUntilEnd.inSeconds < 3) {
        final eventId = "${todayKey}_${pKey}_end_20m";
        if (!_notifiedEvents.contains(eventId)) {
          _notifiedEvents.add(eventId);
          _triggerNotification(
            "তাড়াতাড়ি করুন!",
            "সতর্কতা: $pName নামাজের ওয়াক্ত শেষ হতে আর মাত্র ২০ মিনিট বাকি আছে! দ্রুত সালাত আদায় করে নিন।",
            true,
            isSalatAlarm: false,
          );
        }
      }
    }
  }

  void _triggerNotification(
    String title,
    String body,
    bool isWarning, {
    bool isSalatAlarm = false,
  }) {
    _playNotificationSound(isSalatAlarm: isSalatAlarm);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        const goldAccent = Color(0xFFE5B842);
        const cardBg = Color(0xFF162D24);
        final accentColor = isWarning ? Colors.redAccent : goldAccent;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: accentColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Icon(
                isWarning
                    ? Icons.warning_amber_rounded
                    : Icons.notifications_active_rounded,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SoundPlayer.stopAlarm();
                Navigator.of(ctx).pop();
              },
              child: Text(
                "ঠিক আছে",
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatHistoryDate(String dateKey) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateKey);
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      if (dateKey == DateFormat('yyyy-MM-dd').format(today)) {
        return LanguageManager().isBengali ? 'আজ (Today)' : 'Today';
      } else if (dateKey == DateFormat('yyyy-MM-dd').format(yesterday)) {
        return LanguageManager().isBengali ? 'গতকাল (Yesterday)' : 'Yesterday';
      } else {
        if (!LanguageManager().isBengali) {
          return DateFormat('d MMM').format(date);
        }
        final monthBangla = {
          1: 'জানুয়ারি',
          2: 'ফেব্রুয়ারি',
          3: 'মার্চ',
          4: 'এপ্রিল',
          5: 'মে',
          6: 'জুন',
          7: 'জুলাই',
          8: 'আগস্ট',
          9: 'সেপ্টেম্বর',
          10: 'অক্টোবর',
          11: 'নভেম্বর',
          12: 'ডিসেম্বর',
        }[date.month];
        return "${date.day} $monthBangla";
      }
    } catch (_) {
      return dateKey;
    }
  }

  // Parse 24h string e.g. "04:30" to DateTime
  DateTime _parseTime(String timeStr, {bool tomorrow = false}) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    var date = DateTime(now.year, now.month, now.day, hour, minute);
    if (tomorrow) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  String _formatTo12Hour(String time24h) {
    try {
      final parts = time24h.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2026, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return time24h;
    }
  }

  void _updateCountdown() {
    if (_prayerTimes == null) return;

    final now = DateTime.now();

    // Convert all prayer times to DateTimes
    final fajrTime = _parseTime(_prayerTimes!['Fajr']!);
    final sunriseTime = _parseTime(_prayerTimes!['Sunrise']!);
    final dhuhrTime = _parseTime(_prayerTimes!['Dhuhr']!);
    final asrTime = _parseTime(_prayerTimes!['Asr']!);
    final maghribTime = _parseTime(_prayerTimes!['Maghrib']!);
    final ishaTime = _parseTime(_prayerTimes!['Isha']!);

    // We will check if any prayer is currently active and within 20 minutes of ending
    final List<Map<String, dynamic>> prayers = [
      {
        'name': LanguageManager().isBengali ? 'ফজর (Fajr)' : 'Fajr',
        'start': fajrTime,
        'end': sunriseTime,
      },
      {
        'name': DateTime.now().weekday == DateTime.friday
            ? LanguageManager().isBengali
                  ? 'জুমা (Jumma)'
                  : 'Jumma'
            : LanguageManager().isBengali
            ? 'যোহর (Dhuhr)'
            : 'Dhuhr',
        'start': dhuhrTime,
        'end': asrTime,
      },
      {
        'name': LanguageManager().isBengali ? 'আসর (Asr)' : 'Asr',
        'start': asrTime,
        'end': maghribTime,
      },
      {
        'name': LanguageManager().isBengali ? 'মাগরিব (Maghrib)' : 'Maghrib',
        'start': maghribTime,
        'end': ishaTime,
      },
      {
        'name': LanguageManager().isBengali ? 'এশা (Isha)' : 'Isha',
        'start': ishaTime,
        'end': _parseTime(_prayerTimes!['Fajr']!, tomorrow: true),
      },
    ];

    // Special check for Isha before midnight vs after midnight
    if (now.hour < 12 && now.isBefore(fajrTime)) {
      prayers[4] = {
        'name': LanguageManager().isBengali ? 'এশা (Isha)' : 'Isha',
        'start': ishaTime.subtract(const Duration(days: 1)),
        'end': fajrTime,
      };
    }

    bool foundCloseToEnd = false;
    String warningName = "";
    Duration remaining = Duration.zero;

    for (final prayer in prayers) {
      final start = prayer['start'] as DateTime;
      final end = prayer['end'] as DateTime;
      if (now.isAfter(start) && now.isBefore(end)) {
        final diff = end.difference(now);
        if (diff.inMinutes < 20 && diff.inSeconds >= 0) {
          foundCloseToEnd = true;
          warningName = LanguageManager().isBengali
              ? '${prayer['name']} ওয়াক্ত শেষ হতে বাকি'
              : 'Time left for ${prayer['name']}';
          remaining = diff;
          break;
        }
      }
    }

    if (foundCloseToEnd) {
      if (mounted) {
        setState(() {
          _isCloseToEnd = true;
          _nextPrayerName = warningName;
          _nextPrayerRemaining = remaining;
        });
      }
    } else {
      String standardNextName = "";
      DateTime nextTime = now;

      if (now.isBefore(fajrTime)) {
        standardNextName = "ফজর (Fajr)";
        nextTime = fajrTime;
      } else if (now.isBefore(dhuhrTime)) {
        standardNextName = DateTime.now().weekday == DateTime.friday
            ? "জুমা (Jumma)"
            : "যোহর (Dhuhr)";
        nextTime = dhuhrTime;
      } else if (now.isBefore(asrTime)) {
        standardNextName = "আসর (Asr)";
        nextTime = asrTime;
      } else if (now.isBefore(maghribTime)) {
        standardNextName = "মাগরিব (Maghrib)";
        nextTime = maghribTime;
      } else if (now.isBefore(ishaTime)) {
        standardNextName = "এশা (Isha)";
        nextTime = ishaTime;
      } else {
        standardNextName = "ফজর (Fajr - Tomorrow)";
        nextTime = _parseTime(_prayerTimes!['Fajr']!, tomorrow: true);
      }

      if (mounted) {
        setState(() {
          _isCloseToEnd = false;
          _nextPrayerName = standardNextName;
          _nextPrayerRemaining = nextTime.difference(now);
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    String hStr = hours.toString().padLeft(2, '0');
    String mStr = minutes.toString().padLeft(2, '0');
    String sStr = seconds.toString().padLeft(2, '0');

    return "$hStr:$mStr:$sStr";
  }

  // Check if current time is within active range of a prayer
  bool _isPrayerActive(String start24h, String end24h) {
    if (_prayerTimes == null) return false;
    final now = DateTime.now();

    var start = _parseTime(start24h);
    var end = _parseTime(end24h);

    // If Isha end time is next Fajr (which crosses midnight)
    if (end.isBefore(start)) {
      // E.g. Isha at 20:15, Fajr at 03:52 tomorrow
      end = end.add(const Duration(days: 1));
      // If we are currently after midnight, start must be adjusted to yesterday
      if (now.hour < 12) {
        start = start.subtract(const Duration(days: 1));
        end = end.subtract(const Duration(days: 1));
      }
    }

    return now.isAfter(start) && now.isBefore(end);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LanguageManager().isBengali
              ? '$label কপি করা হয়েছে!'
              : '$label copied!',
        ),
        backgroundColor: Colors.teal.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isFriday = now.weekday == DateTime.friday;

    // Modern colors matching the Islamic theme
    const primaryBg = Color(0xFF0F1E19); // Dark Islamic green tint
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842); // Warm Gold
    const textLight = Colors.white;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: const Text(
          'Islamic Life & Prayer Times',
          style: TextStyle(fontWeight: FontWeight.bold, color: textLight),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textLight),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_active_rounded,
              color: goldAccent,
            ),
            tooltip: LanguageManager().isBengali
                ? 'নোটিফিকেশন সেটিংস'
                : 'Notification Settings',
            onPressed: _showIslamicNotificationSettings,
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: goldAccent),
            tooltip: LanguageManager().isBengali
                ? 'জিপিএস লোকেশন আপডেট'
                : 'Update GPS Location',
            onPressed: _loadLocationAndPrayerTimes,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.map_rounded, color: goldAccent),
            tooltip: LanguageManager().isBengali
                ? 'বিভাগ নির্বাচন করুন'
                : 'Select Division',
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: goldAccent.withValues(alpha: 0.2)),
            ),
            onSelected: (String divisionKey) {
              _loadPrayerTimesForDivision(divisionKey);
            },
            itemBuilder: (BuildContext context) {
              return IslamicService.divisionData.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value['name'] as String,
                    style: const TextStyle(
                      color: textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hijri date display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LanguageManager().isBengali
                            ? 'আজকের হিজরি তারিখ:'
                            : 'Today\'s Hijri Date:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        IslamicService.getHijriDateBn(DateTime.now()),
                        style: const TextStyle(
                          color: goldAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Special Islamic Day Info Card
                  _buildSpecialDayCard(context, cardBg, goldAccent),

                  // 1. Current Prayer Timer & Countdown Hero Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _isCloseToEnd
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : goldAccent.withValues(alpha: 0.15),
                          cardBg,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isCloseToEnd
                            ? Colors.redAccent.withValues(alpha: 0.6)
                            : goldAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isCloseToEnd
                              ? Colors.redAccent.withValues(alpha: 0.05)
                              : goldAccent.withValues(alpha: 0.05),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCloseToEnd
                                  ? Icons.warning_amber_rounded
                                  : Icons.star_half_rounded,
                              color: _isCloseToEnd
                                  ? Colors.redAccent
                                  : goldAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCloseToEnd
                                  ? LanguageManager().isBengali
                                        ? 'জরুরী ওয়াক্ত শেষ হওয়ার কাউন্টডাউন'
                                        : 'Countdown to end of urgent prayer time'
                                  : (isFriday
                                        ? LanguageManager().isBengali
                                              ? 'জুম্মাবার মোবারক'
                                              : 'Jumma Mubarak'
                                        : LanguageManager().isBengali
                                        ? 'নামাজের কাউন্টডাউন'
                                        : 'Prayer Countdown'),
                              style: TextStyle(
                                color: _isCloseToEnd
                                    ? Colors.redAccent
                                    : goldAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nextPrayerName,
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isCloseToEnd
                              ? LanguageManager().isBengali
                                    ? 'ওয়াক্ত শেষ হতে বাকি সময়'
                                    : 'Time remaining to end'
                              : LanguageManager().isBengali
                              ? 'শুরু হতে বাকি সময়'
                              : 'Time remaining to start',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatDuration(_nextPrayerRemaining),
                          style: TextStyle(
                            color: _isCloseToEnd
                                ? Colors.redAccent
                                : goldAccent,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: _isCloseToEnd
                                    ? Colors.redAccent
                                    : goldAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _locationName,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Friday Special (Jumma Special Checklist) - Dynamically visible
                  if (isFriday) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF0F3625,
                        ), // Glowing green card for Friday
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.tealAccent.shade400.withValues(
                            alpha: 0.4,
                          ),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withValues(alpha: 0.1),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.shade400.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.wb_sunny_rounded,
                                  color: Colors.tealAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageManager().isBengali
                                        ? 'জুম্মাবারের বিশেষ আমলসমূহ'
                                        : 'Special Jumma Deeds',
                                    style: TextStyle(
                                      color: textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    LanguageManager().isBengali
                                        ? 'আজকের দিনের সুন্নত আমলগুলো সম্পন্ন করুন'
                                        : 'Complete today\'s sunnah deeds',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.white12),
                          Column(
                            children: List.generate(_jummaSunnahs.length, (
                              index,
                            ) {
                              final item = _jummaSunnahs[index];
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: Colors.tealAccent.shade400,
                                checkColor: Colors.black,
                                title: Text(
                                  item['title'],
                                  style: TextStyle(
                                    color: item['done']
                                        ? Colors.white54
                                        : textLight,
                                    fontSize: 14,
                                    decoration: item['done']
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                value: item['done'],
                                onChanged: (val) {
                                  setState(() {
                                    _jummaSunnahs[index]['done'] = val ?? false;
                                  });
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 3. Quran Verse & Hadith Section (Stacked Full Width)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LanguageManager().isBengali
                                  ? 'আজকের আয়াত'
                                  : 'Verse of the Day',
                              style: TextStyle(
                                color: goldAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () => _copyToClipboard(
                                "${_dailyVerse?['translation']} - ${_dailyVerse?['reference']}",
                                "আজকের আয়াত",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _dailyVerse?['arabic'] ?? '',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: goldAccent.withValues(alpha: 0.9),
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _dailyVerse?['translation'] ?? '',
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _dailyVerse?['reference'] ?? '',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LanguageManager().isBengali
                                  ? 'আজকের হাদিস'
                                  : 'Hadith of the Day',
                              style: TextStyle(
                                color: goldAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () => _copyToClipboard(
                                LanguageManager().isBengali
                                    ? 'হাদিস: ${_dailyHadith?['text']} (বর্ণনায়: ${_dailyHadith?['narrator']}) - ${_dailyHadith?['reference']}'
                                    : 'Hadith: ${_dailyHadith?['text']} (Narrated by: ${_dailyHadith?['narrator']}) - ${_dailyHadith?['reference']}',
                                "আজকের হাদিস",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _dailyHadith?['text'] ?? '',
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          LanguageManager().isBengali
                              ? 'বর্ণনায়: ${_dailyHadith?['narrator'] ?? ''}'
                              : 'Narrated by: ${_dailyHadith?['narrator'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dailyHadith?['reference'] ?? '',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3b. Quran Sharif Entry Card
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuranReaderScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A3A2A),
                            const Color(0xFF0F2A20),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: goldAccent.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: goldAccent.withValues(alpha: 0.08),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: goldAccent.withValues(alpha: 0.12),
                              border: Border.all(
                                color: goldAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'القرآن',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: goldAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageManager().isBengali
                                      ? 'পবিত্র কুরআন শরীফ'
                                      : 'Holy Quran',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  LanguageManager().isBengali
                                      ? 'সুরা-ভিত্তিক পাঠ • হাফেজি কুরআন (৬০৪ পৃষ্ঠা) • অফলাইন সাপোর্ট'
                                      : 'Surah-based • Hafezi Quran (604 pages) • Offline Support',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: goldAccent.withValues(alpha: 0.7),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3c. Qibla and Tasbeeh Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const QiblaCompassScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.explore_rounded,
                                  color: goldAccent,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  LanguageManager().isBengali
                                      ? 'কিবলা কম্পাস'
                                      : 'Qibla Compass',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Qibla Direction',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TasbeehCounterScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.radar_rounded,
                                  color: goldAccent,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  LanguageManager().isBengali
                                      ? 'তাসবীহ কাউন্টার'
                                      : 'Tasbeeh Counter',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Tasbeeh Counter',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3d. Study Supplications Entry Card
                  GestureDetector(
                    onTap: () => _showStudyDuasBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF162D24), Color(0xFF0F1E19)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: goldAccent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: goldAccent.withValues(alpha: 0.05),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: goldAccent.withValues(alpha: 0.12),
                              border: Border.all(
                                color: goldAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: goldAccent,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageManager().isBengali
                                      ? 'পড়াশোনার দোয়া ও আমল'
                                      : 'Study Duas & Deeds',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  LanguageManager().isBengali
                                      ? 'স্মৃতিশক্তি বৃদ্ধি • কঠিন বিষয় সহজ হওয়া • পড়াশোনা শুরুর দোয়া'
                                      : 'Memory Boost • Ease Difficulties • Starting Study Dua',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: goldAccent.withValues(alpha: 0.7),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Prayer Times List
                  Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
                    child: Text(
                      LanguageManager().isBengali
                          ? LanguageManager().isBengali
                                ? 'নামাজের সময়সূচী'
                                : 'Prayer Times'
                          : 'Prayer Times',
                      style: const TextStyle(
                        color: textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _buildPrayerTile(
                    LanguageManager().isBengali ? 'ফজর (Fajr)' : 'Fajr',
                    _prayerTimes?['Fajr'] ?? '03:52',
                    _prayerTimes?['Sunrise'] ?? '05:15',
                    'Fajr',
                    _prayerTimes?['Sunrise'] ?? '05:15',
                  ),
                  _buildPrayerTile(
                    isFriday
                        ? LanguageManager().isBengali
                              ? 'জুমা (Jumma)'
                              : 'Jumma'
                        : LanguageManager().isBengali
                        ? 'যোহর (Dhuhr)'
                        : 'Dhuhr',
                    _prayerTimes?['Dhuhr'] ?? '12:03',
                    _prayerTimes?['Asr'] ?? '04:34',
                    'Dhuhr',
                    _prayerTimes?['Asr'] ?? '04:34',
                  ),
                  _buildPrayerTile(
                    LanguageManager().isBengali ? 'আসর (Asr)' : 'Asr',
                    _prayerTimes?['Asr'] ?? '04:34',
                    _prayerTimes?['Maghrib'] ?? '06:48',
                    'Asr',
                    _prayerTimes?['Maghrib'] ?? '06:48',
                  ),
                  _buildPrayerTile(
                    LanguageManager().isBengali
                        ? 'মাগরিব (Maghrib)'
                        : 'Maghrib',
                    _prayerTimes?['Maghrib'] ?? '06:48',
                    _prayerTimes?['Isha'] ?? '08:15',
                    'Maghrib',
                    _prayerTimes?['Isha'] ?? '08:15',
                  ),
                  _buildPrayerTile(
                    LanguageManager().isBengali ? 'এশা (Isha)' : 'Isha',
                    _prayerTimes?['Isha'] ?? '08:15',
                    _prayerTimes?['Fajr'] ?? '03:52',
                    'Isha',
                    _prayerTimes?['Fajr'] ?? '03:52',
                  ),

                  const SizedBox(height: 16),

                  // Sunrise & Sunset Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wb_sunny_rounded,
                                  color: Colors.orangeAccent,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  LanguageManager().isBengali
                                      ? 'সূর্যোদয় (Sunrise)'
                                      : 'Sunrise',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTo12Hour(
                                _prayerTimes?['Sunrise'] ?? '05:15',
                              ),
                              style: const TextStyle(
                                color: textLight,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.white10),
                        Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wb_twilight_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  LanguageManager().isBengali
                                      ? 'সূর্যাস্ত (Sunset)'
                                      : 'Sunset',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTo12Hour(
                                _prayerTimes?['Maghrib'] ?? '06:48',
                              ),
                              style: const TextStyle(
                                color: textLight,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Prayer History Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
                        child: Text(
                          LanguageManager().isBengali
                              ? 'নামাজের ইতিহাস'
                              : 'Prayer History',
                          style: TextStyle(
                            color: textLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: goldAccent,
                        ),
                        icon: const Icon(Icons.analytics_rounded, size: 16),
                        label: Text(
                          LanguageManager().isBengali
                              ? 'বিস্তারিত রিপোর্ট'
                              : 'Detailed Report',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrayerHistoryScreen(),
                            ),
                          ).then((_) => _loadHistoryData());
                        },
                      ),
                    ],
                  ),

                  Builder(
                    builder: (context) {
                      final todayKey = DateFormat(
                        'yyyy-MM-dd',
                      ).format(DateTime.now());
                      final dayData = _historyData[todayKey] ?? {};
                      int todayMissed = 0;
                      for (final p in [
                        'Fajr',
                        'Dhuhr',
                        'Asr',
                        'Maghrib',
                        'Isha',
                      ]) {
                        if (!(dayData[p] ?? false)) {
                          todayMissed++;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: todayMissed > 0
                              ? Colors.redAccent.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: todayMissed > 0
                                ? Colors.redAccent.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              todayMissed > 0
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: todayMissed > 0
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                todayMissed == 0
                                    ? LanguageManager().isBengali
                                          ? 'আলহামদুলিল্লাহ, আজ কোনো ওয়াক্ত নামাজ মিস নাই।'
                                          : 'Alhamdulillah, no prayers were missed today.'
                                    : LanguageManager().isBengali
                                    ? 'আজ আপনার $todayMissed ওয়াক্ত নামাজ মিস গেছে।'
                                    : '$todayMissed prayers missed today.',
                                style: TextStyle(
                                  color: todayMissed > 0
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Sort history dates descending
                  if (_historyData.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          LanguageManager().isBengali
                              ? 'এখনো নামাজের কোনো রেকর্ড নেই। ওয়াক্ত আদায় করে টিক দিন!'
                              : 'No prayer records yet. Pray and check them off!',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final sortedDateKeys = _historyData.keys.toList()
                          ..sort((a, b) => b.compareTo(a));
                        final recentDates = sortedDateKeys.take(7).toList();

                        return Column(
                          children: recentDates.map((dateKey) {
                            final dayData = _historyData[dateKey] ?? {};
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.03),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatHistoryDate(dateKey),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildHistoryBadge(
                                        LanguageManager().isBengali ? 'ফ' : 'F',
                                        dayData['Fajr'] ?? false,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge(
                                        LanguageManager().isBengali ? 'য' : 'D',
                                        dayData['Dhuhr'] ?? false,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge(
                                        LanguageManager().isBengali ? 'আ' : 'A',
                                        dayData['Asr'] ?? false,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge(
                                        LanguageManager().isBengali
                                            ? 'মা'
                                            : 'M',
                                        dayData['Maghrib'] ?? false,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge(
                                        LanguageManager().isBengali ? 'এ' : 'I',
                                        dayData['Isha'] ?? false,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  _buildSpecialDeedsSection(),
                  const SizedBox(height: 16),
                  _buildDailyHistorySection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSpecialDeedsSection() {
    final deeds = IslamicDailyService.getSpecialDeedsForToday();
    const goldAccent = Color(0xFFE5B842);
    const cardBg = Color(0xFF162D24);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: goldAccent),
              const SizedBox(width: 8),
              Text(
                LanguageManager().isBengali ? 'আজকের বিশেষ আমল' : "Today's Special Deeds",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (deeds.isEmpty)
            Text(
              LanguageManager().isBengali ? 'আজকের জন্য বিশেষ কোনো আমল নেই।' : 'No special deeds for today.',
              style: const TextStyle(color: Colors.white70),
            )
          else
            ...deeds.map((deed) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Icon(Icons.circle, size: 8, color: goldAccent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LanguageManager().isBengali ? deed.split(' (').last.replaceAll(')', '') : deed.split(' (').first,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildDailyHistorySection() {
    final event = IslamicDailyService.getTodayHistoryEvent();
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                LanguageManager().isBengali ? 'ইসলামের ইতিহাসে আজকের দিন' : "Today in Islamic History",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            LanguageManager().isBengali ? event.title.split(' (').last.replaceAll(')', '') : event.title.split(' (').first,
            style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageManager().isBengali ? event.summary : event.summary,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF162D24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(
                      LanguageManager().isBengali ? event.title.split(' (').last.replaceAll(')', '') : event.title.split(' (').first,
                      style: const TextStyle(color: Color(0xFFE5B842), fontWeight: FontWeight.bold),
                    ),
                    content: SingleChildScrollView(
                      child: Text(
                        event.summary,
                        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(LanguageManager().isBengali ? 'বন্ধ করুন' : 'Close', style: const TextStyle(color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.chrome_reader_mode_rounded, size: 16, color: Colors.blueAccent),
              label: Text(
                LanguageManager().isBengali ? 'বিস্তারিত পড়ুন' : 'Read More',
                style: const TextStyle(color: Colors.blueAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTile(
    String name,
    String start24h,
    String end24h,
    String prayerKey,
    String endLabel24h,
  ) {
    final bool isActive = _isPrayerActive(start24h, end24h);
    const goldAccent = Color(0xFFE5B842);
    const cardBg = Color(0xFF162D24);

    // Check if completed today
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bool isCompleted = _historyData[todayKey]?[prayerKey] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1D3E32) : cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? goldAccent.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.05),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: goldAccent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Indicator ring
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? goldAccent : Colors.white24,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: goldAccent.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isActive ? goldAccent : Colors.white,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageManager().isBengali
                        ? 'শুরু: ${_formatTo12Hour(start24h)}  •  শেষ: ${_formatTo12Hour(endLabel24h)}'
                        : 'Start: ${_formatTo12Hour(start24h)}  •  End: ${_formatTo12Hour(endLabel24h)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  LanguageManager().isBengali ? 'চলমান' : 'Ongoing',
                  style: TextStyle(
                    color: goldAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Custom Rounded Checkbox
            GestureDetector(
              onTap: () => _togglePrayerTick(prayerKey),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isCompleted ? goldAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted ? goldAccent : Colors.white30,
                    width: 1.5,
                  ),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 18,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryBadge(String label, bool isCompleted) {
    const goldAccent = Color(0xFFE5B842);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? const Color(0xFF0F3625) : Colors.transparent,
        border: Border.all(
          color: isCompleted
              ? goldAccent.withValues(alpha: 0.6)
              : Colors.white24,
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isCompleted ? goldAccent : Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialDayCard(
    BuildContext context,
    Color cardBg,
    Color goldAccent,
  ) {
    final specialDay = IslamicService.getSpecialIslamicDay(DateTime.now());
    if (specialDay == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: goldAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: goldAccent.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.brightness_3_rounded,
                  color: goldAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      specialDay['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      LanguageManager().isBengali
                          ? 'আজকের বিশেষ দিনের গুরুত্ব ও তাৎপর্য'
                          : 'Importance & Significance of Today',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white12),
          Text(
            specialDay['desc']!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showStudyDuasBottomSheet(BuildContext context) {
    const primaryBg = Color(0xFF0F1E19);
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);
    const textLight = Colors.white;

    final List<Map<String, String>> studyDuas = [
      {
        'title': LanguageManager().isBengali
            ? '১. জ্ঞান বৃদ্ধির দোয়া (পড়াশোনা শুরুর আগে)'
            : '1. Dua for Increasing Knowledge (Before Studying)',
        'arabic': 'رَّبِّ زِدْنِي عِلْمًا',
        'pronunciation': LanguageManager().isBengali
            ? 'উচ্চারণ: রাব্বি যিদনি ইলমা।'
            : 'Pronunciation: Rabbi zidni ilma.',
        'translation': LanguageManager().isBengali
            ? 'অর্থ: "হে আমার পালনকর্তা! আমার জ্ঞান বৃদ্ধি করে দিন।" (সূরা তাহা: ১১৪)'
            : 'Meaning: "O my Lord! Increase me in knowledge." (Surah Taha: 114)',
        'note': LanguageManager().isBengali
            ? 'পড়াশোনা শুরু করার আগে এই দোয়াটি বেশি বেশি পড়া উচিত।'
            : 'This dua should be recited frequently before starting to study.',
      },
      {
        'title': LanguageManager().isBengali
            ? '২. কঠিন বিষয় সহজ হওয়া ও জড়তা কাটার দোয়া'
            : '2. Dua for Easing Difficulties and Removing Stutter',
        'arabic':
            'رَبِّ اشْرَحْ لِي صَدْرِي * وَيَسِّرْ لِي أَمْرِي * وَاحْلُلْ عُقْدَةً مِّন لِّسَانِي * يَفْقَهُوا قَوْلِي',
        'pronunciation': LanguageManager().isBengali
            ? 'উচ্চারণ: রাব্বিশ রাহলি সাদরি, ওয়া ইয়াসসিরলি আমরি, ওয়াহলুল উকদাতাম মিল লিসানি, ইয়াফকাহু কাওলি।'
            : 'Pronunciation: Rabbish rahli sadri, wa yassirli amri, wahlul uqdatam mil lisani, yafqahu qawli.',
        'translation': LanguageManager().isBengali
            ? 'অর্থ: "হে আমার পালনকর্তা! আমার বক্ষ প্রশস্ত করে দিন, আমার কাজ সহজ করে দিন এবং আমার জিহ্বার জড়তা দূর করে দিন যাতে তারা আমার কথা বুঝতে পারে।" (সূরা তাহা: ২৫-২৮)'
            : 'Meaning: "O my Lord! Expand for me my breast, ease for me my task, and untie the knot from my tongue that they may understand my speech." (Surah Taha: 25-28)',
        'note': LanguageManager().isBengali
            ? 'পড়াশোনায় মন বসাতে বা কঠিন কোনো অধ্যায় বুঝতে এটি অত্যন্ত কার্যকর।'
            : 'Very effective for focus and understanding difficult topics.',
      },
      {
        'title': LanguageManager().isBengali
            ? '৩. যেকোনো কঠিন কাজ সহজ করার দোয়া'
            : '3. Dua for Making Difficult Tasks Easy',
        'arabic':
            'اللَّهُمَّ لَا سَهْلَ إِلَّا مَا جَعَلْتَهُ سَهْلًا وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلًا',
        'pronunciation': LanguageManager().isBengali
            ? 'উচ্চারণ: আল্লাহুম্মা লা সাহলা ইল্লা মা জা‘আলতাহু সাহলা, ওয়া আনতা তাজ‘আলুল হাযনা ইযা শি’তা সাহলা।'
            : 'Pronunciation: Allahumma la sahla illa ma ja’altahu sahla, wa anta taj’alul hazna iza shi’ta sahla.',
        'translation': LanguageManager().isBengali
            ? 'অর্থ: "হে আল্লাহ! আপনি যা সহজ করেছেন তা ছাড়া কোনো কিছুই সহজ নয়। আর আপনি চাইলে কঠিন কাজকেও সহজ করে দিতে পারেন।" (সহীহ ইবনে হিব্বান)'
            : 'Meaning: "O Allah, nothing is easy except what You have made easy, and You can make difficulty easy if You wish." (Sahih Ibn Hibban)',
        'note': LanguageManager().isBengali
            ? 'পরীক্ষার হলে বা কঠিন প্রশ্ন দেখলে মনে মনে এই দোয়াটি পড়তে পারেন।'
            : 'Recite this silently during exams or when facing difficult questions.',
      },
      {
        'title': LanguageManager().isBengali
            ? '৪. মেধা ও স্মৃতিশক্তি বৃদ্ধির দোয়া'
            : '4. Dua for Memory Retention & Intelligence',
        'arabic':
            'اللَّهُمَّ انْفَعْنِي بِمَا عَلَّمْتَنِي وَعَلِّمْنِي مَا يَنْفَعُنِي وَزِدْنِي عِلْمًا',
        'pronunciation': LanguageManager().isBengali
            ? 'উচ্চারণ: আল্লাহুম্মান ফানি বিমা আল্লামতানি, ওয়া আল্লিমনি মা ইয়ানফাউনি, ওয়া যিদনি ইলমা।'
            : 'Pronunciation: Allahumman fa’ni bima ‘allamtani, wa ‘allimni ma yanfa’uni, wa zidni ‘ilma.',
        'translation': LanguageManager().isBengali
            ? 'অর্থ: "হে আল্লাহ! আপনি আমাকে যা শিখিয়েছেন তা দিয়ে আমাকে উপকৃত করুন, আমার জন্য যা উপকারী তা আমাকে শেখান এবং আমার জ্ঞান বৃদ্ধি করে দিন।" (সুনানে ইবনে মাজাহ)'
            : 'Meaning: "O Allah! Benefit me with what You have taught me, teach me what will benefit me, and increase my knowledge." (Sunan Ibn Majah)',
        'note': LanguageManager().isBengali
            ? 'পড়া মনে রাখার এবং ব্রেইনের কার্যক্ষমতা বৃদ্ধির জন্য এই দোয়াটি পঠিত হয়।'
            : 'Recite this to boost brain power and memory retention.',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: primaryBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: goldAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: goldAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageManager().isBengali
                                    ? 'পড়াশোনার দোয়া ও আমল'
                                    : 'Study Duas & Deeds',
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'পড়াশোনা শুরু ও মেধা বিকাশের দোয়া কালেকশন',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: studyDuas.length,
                      itemBuilder: (context, index) {
                        final dua = studyDuas[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: goldAccent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      dua['title']!,
                                      style: const TextStyle(
                                        color: goldAccent,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      color: Colors.white54,
                                      size: 18,
                                    ),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text:
                                              "${dua['title']}\n${dua['arabic']}\n${dua['pronunciation']}\n${dua['translation']}",
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            LanguageManager().isBengali
                                                ? '${dua["title"]} কপি হয়েছে'
                                                : '${dua["title"]} copied',
                                          ),
                                          backgroundColor: cardBg,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dua['arabic']!,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dua['pronunciation']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dua['translation']!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 20),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: goldAccent,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dua['note']!,
                                      style: const TextStyle(
                                        color: goldAccent,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
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
}
