import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'islamic_service.dart';
import 'quran_reader_screen.dart';
import 'qibla_compass_screen.dart';
import 'tasbeeh_counter_screen.dart';

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
  // Keys: prayerStart, prayerWarning, jummaReminder
  Map<String, bool> _islamicNotifSettings = {
    'prayerStart': true,
    'prayerWarning': true,
    'jummaReminder': true,
  };
  static const String _islamicNotifFile = 'islamic_notif_settings.json';

  // Friday Special Checklist States
  final List<Map<String, dynamic>> _jummaSunnahs = [
    {'title': 'গোসল করা', 'done': false},
    {'title': 'পরিষ্কার পোশাক পরা ও সুগন্ধি লাগানো', 'done': false},
    {'title': 'সূরা আল-কাহাফ তেলাওয়াত করা', 'done': false},
    {'title': 'রাসূলুল্লাহ (সা.) এর ওপর দরুদ পাঠ করা', 'done': false},
    {'title': 'জুমার সালাতে আগে যাওয়া', 'done': false},
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
      locName = "ডিভাইস লোকেশন (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})";
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
        final decoded = json.decode(await file.readAsString()) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _islamicNotifSettings = {
              'prayerStart':    decoded['prayerStart']    as bool? ?? true,
              'prayerWarning':  decoded['prayerWarning']  as bool? ?? true,
              'jummaReminder':  decoded['jummaReminder']  as bool? ?? true,
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
        return StatefulBuilder(builder: (ctx, setModal) {
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
                      width: 40, height: 4,
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
                        child: const Icon(Icons.notifications_active_rounded, color: goldAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ইসলামিক নোটিফিকেশন',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('শুধুমাত্র এখান থেকে নিয়ন্ত্রণ করা যাবে',
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  _buildNotifTile(
                    ctx, setModal,
                    icon: Icons.alarm_rounded,
                    title: 'নামাজ শুরুর নোটিফিকেশন',
                    subtitle: 'ওয়াক্ত শুরুর ৫ মিনিট পর অনুস্মারক',
                    key: 'prayerStart',
                    goldAccent: goldAccent,
                  ),
                  _buildNotifTile(
                    ctx, setModal,
                    icon: Icons.timer_off_rounded,
                    title: 'ওয়াক্ত শেষের সতর্কতা',
                    subtitle: 'ওয়াক্ত শেষ হওয়ার ২০ মিনিট আগে সতর্কতা',
                    key: 'prayerWarning',
                    goldAccent: goldAccent,
                  ),
                  _buildNotifTile(
                    ctx, setModal,
                    icon: Icons.mosque_rounded,
                    title: 'জুমার অনুস্মারক',
                    subtitle: 'প্রতি শুক্রবার বিশেষ জুমার নোটিফিকেশন',
                    key: 'jummaReminder',
                    goldAccent: goldAccent,
                  ),
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
                        const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'এই সেটিংসগুলো গলোবাল অ্যাপ সেটিংস থেকে আলাদা এবং শুধুমাত্র ইসলামিক লাইফ সেকশন থেকেই নিয়ন্ত্রণ করা যাবে।',
                            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
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
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isOn
                ? goldAccent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: isOn ? goldAccent : Colors.white38, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
              color: isOn ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            )),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
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

  void _playNotificationSound() async {
    try {
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-600.wav'),
      );
    } catch (e) {
      SystemSound.play(SystemSoundType.click);
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
          );
        }
      }

      // 2. 20 minutes before end
      final diffUntilEnd = end.difference(now);
      if (diffUntilEnd.inMinutes == 20 &&
          diffUntilEnd.inSeconds >= 0 &&
          diffUntilEnd.inSeconds < 3) {
        final eventId = "${todayKey}_${pKey}_end_20m";
        if (!_notifiedEvents.contains(eventId)) {
          _notifiedEvents.add(eventId);
          _triggerNotification(
            "তাড়াতাড়ি করুন!",
            "সতর্কতা: $pName নামাজের ওয়াক্ত শেষ হতে আর মাত্র ২০ মিনিট বাকি আছে! দ্রুত সালাত আদায় করে নিন।",
            true,
          );
        }
      }
    }
  }

  void _triggerNotification(String title, String body, bool isWarning) {
    _playNotificationSound();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        const goldAccent = Color(0xFFE5B842);
        const cardBg = Color(0xFF162D24);
        final accentColor = isWarning ? Colors.redAccent : goldAccent;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 1.5),
          ),
          title: Row(
            children: [
              Icon(
                isWarning ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            body,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "ঠিক আছে",
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
              ),
            )
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
        return "আজ (Today)";
      } else if (dateKey == DateFormat('yyyy-MM-dd').format(yesterday)) {
        return "গতকাল (Yesterday)";
      } else {
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
          12: 'ডিসেম্বর'
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
      {'name': 'ফজর (Fajr)', 'start': fajrTime, 'end': sunriseTime},
      {'name': DateTime.now().weekday == DateTime.friday ? 'জুমা (Jumma)' : 'যোহর (Dhuhr)', 'start': dhuhrTime, 'end': asrTime},
      {'name': 'আসর (Asr)', 'start': asrTime, 'end': maghribTime},
      {'name': 'মাগরিব (Maghrib)', 'start': maghribTime, 'end': ishaTime},
      {'name': 'এশা (Isha)', 'start': ishaTime, 'end': _parseTime(_prayerTimes!['Fajr']!, tomorrow: true)},
    ];

    // Special check for Isha before midnight vs after midnight
    if (now.hour < 12 && now.isBefore(fajrTime)) {
      prayers[4] = {
        'name': 'এশা (Isha)',
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
          warningName = "${prayer['name']} ওয়াক্ত শেষ হতে বাকি";
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
        standardNextName = DateTime.now().weekday == DateTime.friday ? "জুমা (Jumma)" : "যোহর (Dhuhr)";
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
        content: Text('$label কপি করা হয়েছে!'),
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
        title: const Text('Islamic Life & Prayer Times', style: TextStyle(fontWeight: FontWeight.bold, color: textLight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textLight),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded, color: goldAccent),
            tooltip: 'নোটিফিকেশন সেটিংস',
            onPressed: _showIslamicNotificationSettings,
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: goldAccent),
            tooltip: 'জিপিএস লোকেশন আপডেট',
            onPressed: _loadLocationAndPrayerTimes,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.map_rounded, color: goldAccent),
            tooltip: 'বিভাগ নির্বাচন করুন',
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
                    style: const TextStyle(color: textLight, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Current Prayer Timer & Countdown Hero Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _isCloseToEnd
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : goldAccent.withValues(alpha: 0.15),
                          cardBg
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
                        )
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
                              color: _isCloseToEnd ? Colors.redAccent : goldAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCloseToEnd
                                  ? 'জরুরী ওয়াক্ত শেষ হওয়ার কাউন্টডাউন'
                                  : (isFriday ? 'জুম্মাবার মোবারক' : 'নামাজের কাউন্টডাউন'),
                              style: TextStyle(
                                color: _isCloseToEnd ? Colors.redAccent : goldAccent,
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
                          style: const TextStyle(color: textLight, fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isCloseToEnd ? 'ওয়াক্ত শেষ হতে বাকি সময়' : 'শুরু হতে বাকি সময়',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatDuration(_nextPrayerRemaining),
                          style: TextStyle(
                            color: _isCloseToEnd ? Colors.redAccent : goldAccent,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: _isCloseToEnd ? Colors.redAccent : goldAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _locationName,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Friday Special (Jumma Special Checklist) - Dynamically visible
                  if (isFriday) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3625), // Glowing green card for Friday
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.tealAccent.shade400.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withValues(alpha: 0.1),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
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
                                  color: Colors.tealAccent.shade400.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.wb_sunny_rounded, color: Colors.tealAccent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'জুম্মাবারের বিশেষ আমলসমূহ',
                                    style: TextStyle(color: textLight, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'আজকের দিনের সুন্নত আমলগুলো সম্পন্ন করুন',
                                    style: TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.white12),
                          Column(
                            children: List.generate(_jummaSunnahs.length, (index) {
                              final item = _jummaSunnahs[index];
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: Colors.tealAccent.shade400,
                                checkColor: Colors.black,
                                title: Text(
                                  item['title'],
                                  style: TextStyle(
                                    color: item['done'] ? Colors.white54 : textLight,
                                    fontSize: 14,
                                    decoration: item['done'] ? TextDecoration.lineThrough : null,
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('আজকের আয়াত', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
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
                          style: TextStyle(color: goldAccent.withValues(alpha: 0.9), fontSize: 16, height: 1.6, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _dailyVerse?['translation'] ?? '',
                          style: const TextStyle(color: textLight, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _dailyVerse?['reference'] ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('আজকের হাদিস', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () => _copyToClipboard(
                                "হাদিস: ${_dailyHadith?['text']} (বর্ণনায়: ${_dailyHadith?['narrator']}) - ${_dailyHadith?['reference']}",
                                "আজকের হাদিস",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _dailyHadith?['text'] ?? '',
                          style: const TextStyle(color: textLight, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "বর্ণনায়: ${_dailyHadith?['narrator'] ?? ''}",
                          style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dailyHadith?['reference'] ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
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
                          )
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
                            child: const Center(
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
                                const Text(
                                  'পবিত্র কুরআন শরীফ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'সুরা-ভিত্তিক পাঠ • হাফেজি কুরআন (৬০৪ পৃষ্ঠা) • অফলাইন সাপোর্ট',
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
                                builder: (context) => const QiblaCompassScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.explore_rounded, color: goldAccent, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'কিবলা কম্পাস',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Qibla Direction',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
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
                                builder: (context) => const TasbeehCounterScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.radar_rounded, color: goldAccent, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'তাসবীহ কাউন্টার',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Tasbeeh Counter',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. Prayer Times List
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
                    child: Text(
                      'নামাজের সময়সূচী',
                      style: TextStyle(color: textLight, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  _buildPrayerTile(
                    'ফজর (Fajr)',
                    _prayerTimes?['Fajr'] ?? '03:52',
                    _prayerTimes?['Sunrise'] ?? '05:15',
                    'Fajr',
                    _prayerTimes?['Sunrise'] ?? '05:15',
                  ),
                  _buildPrayerTile(
                    isFriday ? 'জুমা (Jumma)' : 'যোহর (Dhuhr)',
                    _prayerTimes?['Dhuhr'] ?? '12:03',
                    _prayerTimes?['Asr'] ?? '04:34',
                    'Dhuhr',
                    _prayerTimes?['Asr'] ?? '04:34',
                  ),
                  _buildPrayerTile(
                    'আসর (Asr)',
                    _prayerTimes?['Asr'] ?? '04:34',
                    _prayerTimes?['Maghrib'] ?? '06:48',
                    'Asr',
                    _prayerTimes?['Maghrib'] ?? '06:48',
                  ),
                  _buildPrayerTile(
                    'মাগরিব (Maghrib)',
                    _prayerTimes?['Maghrib'] ?? '06:48',
                    _prayerTimes?['Isha'] ?? '08:15',
                    'Maghrib',
                    _prayerTimes?['Isha'] ?? '08:15',
                  ),
                  _buildPrayerTile(
                    'এশা (Isha)',
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wb_sunny_rounded, color: Colors.orangeAccent, size: 20),
                                SizedBox(width: 8),
                                Text('সূর্যোদয় (Sunrise)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTo12Hour(_prayerTimes?['Sunrise'] ?? '05:15'),
                              style: const TextStyle(color: textLight, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.white10),
                        Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wb_twilight_rounded, color: Colors.redAccent, size: 20),
                                SizedBox(width: 8),
                                Text('সূর্যাস্ত (Sunset)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTo12Hour(_prayerTimes?['Maghrib'] ?? '06:48'),
                              style: const TextStyle(color: textLight, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 5. Prayer History Section
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
                    child: Text(
                      'নামাজের ইতিহাস',
                      style: TextStyle(color: textLight, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  
                  // Sort history dates descending
                  if (_historyData.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: const Center(
                        child: Text(
                          'এখনো নামাজের কোনো রেকর্ড নেই। ওয়াক্ত আদায় করে টিক দিন!',
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatHistoryDate(dateKey),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [
                                      _buildHistoryBadge('ফ', dayData['Fajr'] ?? false),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge('য', dayData['Dhuhr'] ?? false),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge('আ', dayData['Asr'] ?? false),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge('মা', dayData['Maghrib'] ?? false),
                                      const SizedBox(width: 6),
                                      _buildHistoryBadge('এ', dayData['Isha'] ?? false),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }
                    ),
                  const SizedBox(height: 16),
                ],
              ),
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
          color: isActive ? goldAccent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.05),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: goldAccent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
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
                        )
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
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "শুরু: ${_formatTo12Hour(start24h)}  •  শেষ: ${_formatTo12Hour(endLabel24h)}",
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
                child: const Text(
                  'চলমান',
                  style: TextStyle(color: goldAccent, fontSize: 10, fontWeight: FontWeight.bold),
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
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 18)
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
          color: isCompleted ? goldAccent.withValues(alpha: 0.6) : Colors.white24,
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
}
