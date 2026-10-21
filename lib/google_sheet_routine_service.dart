import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_routine.dart';

class GoogleSheetRoutineService {
  static const String _prefKeySheetUrl = 'saved_google_sheet_routine_url';

  // Sample Google Sheet Template link that users can view or copy
  static const String templateSheetUrl = 
      'https://docs.google.com/spreadsheets/d/1U9p2sE6kGZ-SampleTemplateForStudyMate/edit?usp=sharing';

  /// Save the sheet URL for quick 1-tap re-sync
  static Future<void> saveSheetUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySheetUrl, url.trim());
  }

  /// Get the saved sheet URL
  static Future<String?> getSavedSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeySheetUrl);
  }

  /// Convert a normal Google Sheet link to a direct CSV export link
  static String? convertToCsvUrl(String inputUrl) {
    final trimmed = inputUrl.trim();
    if (trimmed.isEmpty) return null;

    // If it's already a direct CSV or gviz link
    if (trimmed.contains('format=csv') || trimmed.contains('tqx=out:csv')) {
      return trimmed;
    }

    // Extract Spreadsheet ID from standard Google Sheet URL
    // e.g. https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit...
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(trimmed);

    if (match != null && match.groupCount >= 1) {
      final sheetId = match.group(1);
      // Check for specific sheet gid (tab)
      final gidRegex = RegExp(r'[#&?]gid=([0-9]+)');
      final gidMatch = gidRegex.firstMatch(trimmed);
      final gidParam = (gidMatch != null && gidMatch.groupCount >= 1) 
          ? '&gid=${gidMatch.group(1)}' 
          : '';

      return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv$gidParam';
    }

    // If already a valid raw HTTP URL, return as-is
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    return null;
  }

  /// Fetch CSV from Google Sheets URL
  static Future<String> fetchCsvContent(String rawUrl) async {
    final csvUrl = convertToCsvUrl(rawUrl);
    if (csvUrl == null) {
      throw Exception('Invalid Google Sheets URL. Please check the link.');
    }

    final response = await http.get(Uri.parse(csvUrl)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Connection timed out. Check your internet connection.'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Could not access Google Sheet (Status: ${response.statusCode}). '
        'Make sure Link Sharing is set to "Anyone with the link can view".',
      );
    }

    final content = utf8.decode(response.bodyBytes);
    if (content.contains('<!DOCTYPE html>') || content.contains('<html')) {
      throw Exception(
        'The Google Sheet is private. In Google Sheets, click "Share" and set '
        'Access to "Anyone with the link can view".',
      );
    }

    return content;
  }

  /// Parse CSV string into structured task rows
  static List<Map<String, String>> parseCsvToRows(String csvContent) {
    final List<Map<String, String>> rows = [];
    final rawLines = const LineSplitter().convert(csvContent);

    if (rawLines.isEmpty) return rows;

    // Filter non-empty lines
    final lines = rawLines.where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return rows; // Need at least header + 1 data row

    // Parse header line
    final headers = _parseCsvLine(lines.first).map((h) => _normalizeHeader(h)).toList();

    for (int i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i]);
      if (values.every((v) => v.trim().isEmpty)) continue;

      final rowMap = <String, String>{};
      for (int h = 0; h < headers.length; h++) {
        final val = h < values.length ? values[h].trim() : '';
        rowMap[headers[h]] = val;
      }
      rows.add(rowMap);
    }

    return rows;
  }

  /// Robust CSV Line Parser handling quotes and commas
  static List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if ((char == ',' || char == '\t') && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  /// Normalize header names to standard keys
  static String _normalizeHeader(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('date') || lower.contains('তারিখ') || lower.contains('day') || lower.contains('বার')) {
      return 'date';
    }
    if (lower.contains('subject') || lower.contains('বিষয়') || lower.contains('course')) {
      return 'subject';
    }
    if (lower.contains('topic') || lower.contains('অধ্যায়') || lower.contains('chapter') || lower.contains('title') || lower.contains('টাস্ক')) {
      return 'topic';
    }
    if (lower.contains('start') || lower.contains('শুরু') || lower.contains('from')) {
      return 'start_time';
    }
    if (lower.contains('end') || lower.contains('শেষ') || lower.contains('to')) {
      return 'end_time';
    }
    if (lower.contains('duration') || lower.contains('সময়') || lower.contains('মিনিট') || lower.contains('min')) {
      return 'duration';
    }
    if (lower.contains('category') || lower.contains('ক্যাটাগরি') || lower.contains('type')) {
      return 'category';
    }
    if (lower.contains('note') || lower.contains('নোট') || lower.contains('comment') || lower.contains('details')) {
      return 'notes';
    }
    if (lower.contains('alarm') || lower.contains('অ্যালার্ম') || lower.contains('alert')) {
      return 'alarm';
    }
    return lower;
  }

  /// Sync parsed rows to Firestore dailyRoutines
  static Future<int> syncRowsToFirestore({
    required List<Map<String, String>> rows,
    bool replaceExisting = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please log in first to sync routine.');

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();

    // Group tasks by Target Date string (yyyy-MM-dd)
    final Map<String, List<Task>> tasksByDate = {};

    for (final row in rows) {
      final subject = row['subject'] ?? 'General';
      final topic = row['topic'] ?? row['title'] ?? 'Study Session';
      final title = topic.isNotEmpty ? topic : subject;

      // Parse target date
      final targetDate = _parseTargetDate(row['date'], now);
      final dateKey = DateFormat('yyyy-MM-dd').format(targetDate);

      // Parse start & end time
      final times = _parseStartAndEnd(row['start_time'], row['end_time'], row['duration'], targetDate);

      final task = Task(
        id: 'gsheet_${DateTime.now().microsecondsSinceEpoch}_${tasksByDate.length}',
        title: title,
        subject: subject,
        topic: topic,
        startTime: times['start'],
        endTime: times['end'],
        totalDurationMinutes: times['duration'] ?? 60,
        category: row['category'] ?? 'Study',
        notes: row['notes'] ?? 'Synced from Google Sheet',
        alarmEnabled: row['alarm']?.toLowerCase() == 'yes' || row['alarm']?.toLowerCase() == 'true',
        isCompleted: false,
        status: 'pending',
      );

      tasksByDate.putIfAbsent(dateKey, () => []).add(task);
    }

    if (tasksByDate.isEmpty) {
      throw Exception('No valid routine tasks found in the Google Sheet.');
    }

    int totalImported = 0;

    // Save to Firestore
    for (final entry in tasksByDate.entries) {
      final dateStr = entry.key;
      final newTasks = entry.value;

      final docRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailyRoutines')
          .doc(dateStr);

      final docSnap = await docRef.get();

      List<Task> finalTaskList = [];

      if (docSnap.exists && !replaceExisting) {
        // Merge with existing tasks
        final existingRoutine = DailyRoutine.fromMap(docSnap.data()!, docSnap.id);
        finalTaskList.addAll(existingRoutine.tasks);
        finalTaskList.addAll(newTasks);
      } else {
        finalTaskList = newTasks;
      }

      final routineDate = DateFormat('yyyy-MM-dd').parse(dateStr);
      final routine = DailyRoutine(
        id: dateStr,
        userId: user.uid,
        date: routineDate,
        tasks: finalTaskList,
      );

      await docRef.set(routine.toMap(), SetOptions(merge: true));
      totalImported += newTasks.length;
    }

    return totalImported;
  }

  /// Helper: Parse Target Date
  static DateTime _parseTargetDate(String? dateStr, DateTime fallback) {
    if (dateStr == null || dateStr.trim().isEmpty) return fallback;

    final trimmed = dateStr.trim().toLowerCase();
    if (trimmed == 'today' || trimmed == 'আজ') return fallback;
    if (trimmed == 'tomorrow' || trimmed == 'আগামীকাল') {
      return fallback.add(const Duration(days: 1));
    }

    // Try standard formats
    final formats = [
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'd/M/yyyy',
      'd-M-yyyy',
    ];

    for (final f in formats) {
      try {
        return DateFormat(f).parseStrict(dateStr.trim());
      } catch (_) {}
    }

    // Try Day names (e.g. Saturday, Sunday)
    final daysOfWeek = {
      'monday': 1, 'সোম': 1, 'সোমবার': 1,
      'tuesday': 2, 'মঙ্গল': 2, 'মঙ্গলবার': 2,
      'wednesday': 3, 'বুধ': 3, 'বুধবার': 3,
      'thursday': 4, 'বৃহস্পতি': 4, 'বৃহস্পতিবার': 4,
      'friday': 5, 'শুক্র': 5, 'শুক্রবার': 5,
      'saturday': 6, 'শনি': 6, 'শনিবার': 6,
      'sunday': 7, 'রবি': 7, 'রবিবার': 7,
    };

    if (daysOfWeek.containsKey(trimmed)) {
      final targetWeekday = daysOfWeek[trimmed]!;
      int diff = targetWeekday - fallback.weekday;
      if (diff < 0) diff += 7; // next upcoming day
      return fallback.add(Duration(days: diff));
    }

    return fallback;
  }

  /// Helper: Parse Start, End & Duration
  static Map<String, dynamic> _parseStartAndEnd(
    String? startStr,
    String? endStr,
    String? durationStr,
    DateTime baseDate,
  ) {
    DateTime? start;
    DateTime? end;
    int durationMinutes = 60;

    if (startStr != null && startStr.isNotEmpty) {
      start = _parseTimeOnDate(startStr, baseDate);
    }

    if (endStr != null && endStr.isNotEmpty) {
      end = _parseTimeOnDate(endStr, baseDate);
    }

    if (durationStr != null && durationStr.isNotEmpty) {
      final parsed = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed > 0) {
        durationMinutes = parsed;
      }
    }

    if (start != null && end != null) {
      durationMinutes = end.difference(start).inMinutes;
      if (durationMinutes <= 0) durationMinutes = 60;
    } else if (start != null && end == null) {
      end = start.add(Duration(minutes: durationMinutes));
    }

    return {
      'start': start,
      'end': end,
      'duration': durationMinutes,
    };
  }

  /// Helper: Parse time string (e.g. "08:00 PM", "20:00", "8:30")
  static DateTime? _parseTimeOnDate(String timeStr, DateTime baseDate) {
    final clean = timeStr.trim().toUpperCase();
    final timeFormats = [
      'hh:mm a',
      'h:mm a',
      'hh:mma',
      'h:mma',
      'HH:mm',
      'H:mm',
    ];

    for (final tf in timeFormats) {
      try {
        final parsedTime = DateFormat(tf).parseStrict(clean);
        return DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          parsedTime.hour,
          parsedTime.minute,
        );
      } catch (_) {}
    }
    return null;
  }

  /// Generate sample demo CSV for quick preview and testing
  static String generateSampleCsv() {
    return '''Date,Subject,Topic,Start Time,End Time,Duration,Category,Notes
Today,Physics,Vector & Motion,08:00 AM,09:30 AM,90,Study,Practice vector problems from Chapter 2
Today,Mathematics,Calculus Integration,10:00 AM,11:30 AM,90,Math,Exercise 9.1 to 9.3
Today,English,Vocabulary & Grammar,03:00 PM,04:00 PM,60,Language,Memorize 20 new GRE words
Today,Biology,Genetics & Heredity,07:00 PM,08:30 PM,90,Science,Review Mendel laws
Today,Islamic Studies,Surah Al-Mulk Revision,09:00 PM,09:30 PM,30,Islamic,Recite with Tafseer
''';
  }
}
