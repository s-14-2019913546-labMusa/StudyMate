import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'bengali_date_helper.dart';
import 'language_manager.dart';

class PrayerHistoryScreen extends StatefulWidget {
  const PrayerHistoryScreen({super.key});

  @override
  State<PrayerHistoryScreen> createState() => _PrayerHistoryScreenState();
}

class _PrayerHistoryScreenState extends State<PrayerHistoryScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, Map<String, bool>> _historyData = {};
  late TabController _tabController;

  static const List<String> _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  static const Map<String, String> _prayerNamesBn = {
    'Fajr': 'ফজর',
    'Dhuhr': 'যোহর',
    'Asr': 'আসর',
    'Maghrib': 'মাগরিব',
    'Isha': 'এশা'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _isLoading = false;
        });
      } else {
        setState(() {
          _historyData = {};
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
      setState(() => _isLoading = false);
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

  void _togglePrayer(String dateKey, String prayerKey) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateKey != todayStr) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Past prayer history is locked and cannot be edited.'.tr()),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.redAccent.shade700,
          ),
        );
      }
      return;
    }
    setState(() {
      if (!_historyData.containsKey(dateKey)) {
        _historyData[dateKey] = {
          'Fajr': false,
          'Dhuhr': false,
          'Asr': false,
          'Maghrib': false,
          'Isha': false,
        };
      }
      final currentVal = _historyData[dateKey]?[prayerKey] ?? false;
      _historyData[dateKey]?[prayerKey] = !currentVal;
    });
    _saveHistoryData();
  }

  DateTime _getTrackingStartDate() {
    if (_historyData.isEmpty) {
      return DateTime.now();
    }
    DateTime earliest = DateTime.now();
    for (final key in _historyData.keys) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(key);
        if (date.isBefore(earliest)) {
          earliest = date;
        }
      } catch (_) {}
    }
    final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
    if (earliest.isBefore(fiveYearsAgo)) {
      return fiveYearsAgo;
    }
    return earliest;
  }

  int _getMissedCountForDay(String dateKey) {
    final dayData = _historyData[dateKey];
    if (dayData == null) return 5;
    int missed = 0;
    for (final p in _prayers) {
      if (!(dayData[p] ?? false)) {
        missed++;
      }
    }
    return missed;
  }

  int _getMissedCountForRange(DateTime start, DateTime end) {
    final trackingStart = _getTrackingStartDate();
    final today = DateTime.now();
    final cleanTrackingStart = DateTime(trackingStart.year, trackingStart.month, trackingStart.day);
    final cleanToday = DateTime(today.year, today.month, today.day);

    DateTime current = DateTime(start.year, start.month, start.day);
    final targetEnd = DateTime(end.year, end.month, end.day);

    int missed = 0;
    while (!current.isAfter(targetEnd)) {
      // Only count days between trackingStart and today
      if (!current.isBefore(cleanTrackingStart) && !current.isAfter(cleanToday)) {
        final dateKey = DateFormat('yyyy-MM-dd').format(current);
        missed += _getMissedCountForDay(dateKey);
      }
      current = current.add(const Duration(days: 1));
    }
    return missed;
  }

  void _showMissedDetailsSheet(String title, DateTime start, DateTime end) {
    final trackingStart = _getTrackingStartDate();
    final today = DateTime.now();
    final cleanTrackingStart = DateTime(trackingStart.year, trackingStart.month, trackingStart.day);
    final cleanToday = DateTime(today.year, today.month, today.day);

    DateTime current = DateTime(start.year, start.month, start.day);
    final targetEnd = DateTime(end.year, end.month, end.day);

    final List<Map<String, dynamic>> missedDaysList = [];

    while (!current.isAfter(targetEnd)) {
      if (!current.isBefore(cleanTrackingStart) && !current.isAfter(cleanToday)) {
        final dateKey = DateFormat('yyyy-MM-dd').format(current);
        final dayData = _historyData[dateKey] ?? {};
        final List<String> missedPrayers = [];
        for (final p in _prayers) {
          if (!(dayData[p] ?? false)) {
            missedPrayers.add(p);
          }
        }
        if (missedPrayers.isNotEmpty) {
          missedDaysList.add({
            'date': current,
            'prayers': missedPrayers,
          });
        }
      }
      current = current.add(const Duration(days: 1));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${'Missed Prayer Details'.tr()} - $title',
                      style: const TextStyle(color: Color(0xFFE5B842), fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              if (missedDaysList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No missed prayers found for this period!'.tr(),
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: missedDaysList.length,
                    itemBuilder: (context, index) {
                      final item = missedDaysList[index];
                      final date = item['date'] as DateTime;
                      final prayers = item['prayers'] as List<String>;
                      final prayerNames = prayers.map((p) => _prayerNamesBn[p]!.tr()).join(', ');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatBnDate(date),
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                prayerNames,
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
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
  }

  String _formatBnDate(DateTime date) {
    final isBn = LanguageManager().isBengali;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (dateStr == DateFormat('yyyy-MM-dd').format(today)) {
      return isBn ? "আজ (Today)" : "Today";
    } else if (dateStr == DateFormat('yyyy-MM-dd').format(yesterday)) {
      return isBn ? "গতকাল (Yesterday)" : "Yesterday";
    }

    if (!isBn) {
      return DateFormat('d MMM, yyyy').format(date);
    }

    final monthBangla = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    final bnDay = BengaliDateHelper.toBengaliDigits(date.day.toString());
    final bnYear = BengaliDateHelper.toBengaliDigits(date.year.toString());
    final bnMonth = monthBangla[date.month - 1];
    return "$bnDay $bnMonth, $bnYear";
  }

  String _formatBnWeekRange(DateTime start, DateTime end) {
    final isBn = LanguageManager().isBengali;
    if (!isBn) {
      final startFmt = DateFormat('d MMM').format(start);
      final endFmt = DateFormat('d MMM, yyyy').format(end);
      return "$startFmt - $endFmt";
    }
    final monthBangla = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    final bnStartDay = BengaliDateHelper.toBengaliDigits(start.day.toString());
    final bnStartMonth = monthBangla[start.month - 1];
    
    final bnEndDay = BengaliDateHelper.toBengaliDigits(end.day.toString());
    final bnEndMonth = monthBangla[end.month - 1];
    final bnEndYear = BengaliDateHelper.toBengaliDigits(end.year.toString());
    
    if (start.month == end.month) {
      return "$bnStartDay - $bnEndDay $bnStartMonth, $bnEndYear";
    } else {
      return "$bnStartDay $bnStartMonth - $bnEndDay $bnEndMonth, $bnEndYear";
    }
  }

  String _formatBnMonthYear(DateTime date) {
    final isBn = LanguageManager().isBengali;
    if (!isBn) {
      return DateFormat('MMMM yyyy').format(date);
    }
    final monthBangla = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    final bnMonth = monthBangla[date.month - 1];
    final bnYear = BengaliDateHelper.toBengaliDigits(date.year.toString());
    return "$bnMonth $bnYear";
  }

  String _formatBnYear(int year) {
    final isBn = LanguageManager().isBengali;
    if (!isBn) {
      return year.toString();
    }
    return "${BengaliDateHelper.toBengaliDigits(year.toString())} সাল";
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Friday as start of week (DateTime.friday = 5)
    int daysToSubtract = (date.weekday - DateTime.friday + 7) % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF0F1E19);
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);
    const textLight = Colors.white;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayMissed = _getMissedCountForDay(todayStr);

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: Text('Prayer History & Report'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: textLight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textLight),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: goldAccent,
          labelColor: goldAccent,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Daily'.tr()),
            Tab(text: 'Weekly'.tr()),
            Tab(text: 'Monthly'.tr()),
            Tab(text: 'Yearly'.tr()),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Today status card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          todayMissed > 0
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : goldAccent.withValues(alpha: 0.15),
                          cardBg
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: todayMissed > 0
                            ? Colors.redAccent.withValues(alpha: 0.4)
                            : goldAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Today\'s Prayer Status'.tr(),
                          style: TextStyle(
                            color: todayMissed > 0 ? Colors.redAccent : goldAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          todayMissed == 0
                              ? 'Alhamdulillah, no prayers were missed today.'.tr()
                              : LanguageManager().isBengali
                                  ? 'আজ আপনার ${BengaliDateHelper.toBengaliDigits(todayMissed.toString())} ওয়াক্ত নামাজ মিস গেছে।'
                                  : '$todayMissed prayers missed today.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDailyTab(cardBg, goldAccent, textLight),
                      _buildWeeklyTab(cardBg, goldAccent, textLight),
                      _buildMonthlyTab(cardBg, goldAccent, textLight),
                      _buildYearlyTab(cardBg, goldAccent, textLight),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDailyTab(Color cardBg, Color goldAccent, Color textLight) {
    final startDate = _getTrackingStartDate();
    final today = DateTime.now();
    final List<DateTime> datesList = [];

    // Generate dates from today backwards to startDate
    DateTime cur = DateTime(today.year, today.month, today.day);
    final targetStart = DateTime(startDate.year, startDate.month, startDate.day);
    while (!cur.isBefore(targetStart)) {
      datesList.add(cur);
      cur = cur.subtract(const Duration(days: 1));
    }

    if (datesList.isEmpty) {
      return Center(
        child: Text('No missed prayers found for this period!'.tr(), style: const TextStyle(color: Colors.white54)),
      );
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: datesList.length,
      itemBuilder: (context, index) {
        final date = datesList[index];
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final dayData = _historyData[dateKey] ?? {};
        final missed = _getMissedCountForDay(dateKey);
        final isToday = (dateKey == todayStr);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isToday ? goldAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _formatBnDate(date),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isToday) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.lock_outline_rounded, size: 13, color: Colors.white38),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: missed == 0
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: missed == 0
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      missed == 0
                          ? 'All Completed'.tr()
                          : LanguageManager().isBengali
                              ? '${BengaliDateHelper.toBengaliDigits(missed.toString())} ওয়াক্ত মিস'
                              : '$missed ${'Waqt Missed'.tr()}',
                      style: TextStyle(
                        color: missed == 0 ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _prayers.map((p) {
                  final isDone = dayData[p] ?? false;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _togglePrayer(dateKey, p),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.white12,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _prayerNamesBn[p]!.tr(),
                              style: TextStyle(
                                color: isDone ? Colors.greenAccent : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              isDone ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                              color: isDone ? Colors.greenAccent : (isToday ? Colors.white24 : Colors.white12),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyTab(Color cardBg, Color goldAccent, Color textLight) {
    final startDate = _getTrackingStartDate();
    final today = DateTime.now();
    final List<Map<String, dynamic>> weeksList = [];

    DateTime curWeekStart = _getStartOfWeek(today);
    final targetStartLimit = _getStartOfWeek(startDate);

    while (!curWeekStart.isBefore(targetStartLimit)) {
      final curWeekEnd = curWeekStart.add(const Duration(days: 6));
      
      final calcStart = curWeekStart.isBefore(startDate) ? startDate : curWeekStart;
      final calcEnd = curWeekEnd.isAfter(today) ? today : curWeekEnd;

      final missed = _getMissedCountForRange(calcStart, calcEnd);
      weeksList.add({
        'start': curWeekStart,
        'end': curWeekEnd,
        'missed': missed,
        'calcStart': calcStart,
        'calcEnd': calcEnd,
      });
      curWeekStart = curWeekStart.subtract(const Duration(days: 7));
    }

    if (weeksList.isEmpty) {
      return Center(
        child: Text('No missed prayers found for this period!'.tr(), style: const TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: weeksList.length,
      itemBuilder: (context, index) {
        final item = weeksList[index];
        final start = item['start'] as DateTime;
        final end = item['end'] as DateTime;
        final calcStart = item['calcStart'] as DateTime;
        final calcEnd = item['calcEnd'] as DateTime;
        final missed = item['missed'] as int;
        final isBn = LanguageManager().isBengali;

        return GestureDetector(
          onTap: () => _showMissedDetailsSheet(_formatBnWeekRange(start, end), calcStart, calcEnd),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatBnWeekRange(start, end),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        missed == 0
                            ? 'Alhamdulillah, no prayers were missed this week.'.tr()
                            : isBn
                                ? 'এই সপ্তাহে ${BengaliDateHelper.toBengaliDigits(missed.toString())} ওয়াক্ত নামাজ মিস গেছে।'
                                : '$missed prayers missed this week.',
                        style: TextStyle(
                          color: missed == 0 ? Colors.greenAccent : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (missed > 0)
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 22),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                    ],
                  )
                else
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 22)
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyTab(Color cardBg, Color goldAccent, Color textLight) {
    final startDate = _getTrackingStartDate();
    final today = DateTime.now();
    final List<Map<String, dynamic>> monthsList = [];

    // Group by months starting from today's month back to start month
    DateTime curMonthStart = DateTime(today.year, today.month, 1);
    final targetStartLimit = DateTime(startDate.year, startDate.month, 1);

    while (!curMonthStart.isBefore(targetStartLimit)) {
      final nextMonth = DateTime(curMonthStart.year, curMonthStart.month + 1, 1);
      final curMonthEnd = nextMonth.subtract(const Duration(days: 1));
      
      final calcStart = curMonthStart.isBefore(startDate) ? startDate : curMonthStart;
      final calcEnd = curMonthEnd.isAfter(today) ? today : curMonthEnd;

      final missed = _getMissedCountForRange(calcStart, calcEnd);
      monthsList.add({
        'monthDate': curMonthStart,
        'missed': missed,
        'calcStart': calcStart,
        'calcEnd': calcEnd,
      });

      curMonthStart = DateTime(curMonthStart.year, curMonthStart.month - 1, 1);
    }

    if (monthsList.isEmpty) {
      return Center(
        child: Text('No missed prayers found for this period!'.tr(), style: const TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: monthsList.length,
      itemBuilder: (context, index) {
        final item = monthsList[index];
        final monthDate = item['monthDate'] as DateTime;
        final calcStart = item['calcStart'] as DateTime;
        final calcEnd = item['calcEnd'] as DateTime;
        final missed = item['missed'] as int;
        final isBn = LanguageManager().isBengali;

        return GestureDetector(
          onTap: () => _showMissedDetailsSheet(_formatBnMonthYear(monthDate), calcStart, calcEnd),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatBnMonthYear(monthDate),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        missed == 0
                            ? 'Alhamdulillah, no prayers were missed this month.'.tr()
                            : isBn
                                ? 'এই মাসে ${BengaliDateHelper.toBengaliDigits(missed.toString())} ওয়াক্ত নামাজ মিস গেছে।'
                                : '$missed prayers missed this month.',
                        style: TextStyle(
                          color: missed == 0 ? Colors.greenAccent : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (missed > 0)
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 22),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                    ],
                  )
                else
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 22)
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearlyTab(Color cardBg, Color goldAccent, Color textLight) {
    final startDate = _getTrackingStartDate();
    final today = DateTime.now();
    final List<Map<String, dynamic>> yearsList = [];

    int curYear = today.year;
    final targetStartLimit = startDate.year;

    while (curYear >= targetStartLimit) {
      final curYearStart = DateTime(curYear, 1, 1);
      final curYearEnd = DateTime(curYear, 12, 31);

      final calcStart = curYearStart.isBefore(startDate) ? startDate : curYearStart;
      final calcEnd = curYearEnd.isAfter(today) ? today : curYearEnd;

      final missed = _getMissedCountForRange(calcStart, calcEnd);
      yearsList.add({
        'year': curYear,
        'missed': missed,
        'calcStart': calcStart,
        'calcEnd': calcEnd,
      });

      curYear--;
    }

    if (yearsList.isEmpty) {
      return Center(
        child: Text('No missed prayers found for this period!'.tr(), style: const TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: yearsList.length,
      itemBuilder: (context, index) {
        final item = yearsList[index];
        final yearVal = item['year'] as int;
        final calcStart = item['calcStart'] as DateTime;
        final calcEnd = item['calcEnd'] as DateTime;
        final missed = item['missed'] as int;
        final isBn = LanguageManager().isBengali;

        return GestureDetector(
          onTap: () => _showMissedDetailsSheet(_formatBnYear(yearVal), calcStart, calcEnd),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatBnYear(yearVal),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        missed == 0
                            ? 'Alhamdulillah, no prayers were missed this year.'.tr()
                            : isBn
                                ? 'এই বছরে ${BengaliDateHelper.toBengaliDigits(missed.toString())} ওয়াক্ত নামাজ মিস গেছে।'
                                : '$missed prayers missed this year.',
                        style: TextStyle(
                          color: missed == 0 ? Colors.greenAccent : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (missed > 0)
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 22),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                    ],
                  )
                else
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 22)
              ],
            ),
          ),
        );
      },
    );
  }
}
