import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'daily_routine.dart';

class StudyAnalyticsScreen extends StatefulWidget {
  const StudyAnalyticsScreen({super.key});

  @override
  State<StudyAnalyticsScreen> createState() => _StudyAnalyticsScreenState();
}

class _StudyAnalyticsScreenState extends State<StudyAnalyticsScreen> {
  bool _isLoading = true;
  int _totalTasksDone = 0;
  double _totalStudyHours = 0.0;
  double _avgDailyTasks = 0.0;
  String _bestDay = "N/A";
  
  List<int> _weeklyCompletedCount = [];
  Map<String, int> _subjectDurations = {};
  List<String> _weeklyDays = [];

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyRoutines')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      int totalCompleted = 0;
      int totalMinutes = 0;
      Map<String, int> subjectMap = {};
      Map<String, int> dailyCompletedCount = {};
      
      // Initialize daily count for last 7 days
      final DateFormat dayFormat = DateFormat('E');
      final DateFormat fullDateFormat = DateFormat('yyyy-MM-dd');
      
      List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
      for (var day in last7Days) {
        dailyCompletedCount[fullDateFormat.format(day)] = 0;
      }

      int maxCompletedInADay = 0;
      String bestDayStr = "N/A";

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final routine = DailyRoutine.fromMap(data, doc.id);
        final dateKey = fullDateFormat.format(routine.date);

        int dayCompletedCount = 0;
        for (var task in routine.tasks) {
          if (task.status == 'completed' || task.isCompleted) {
            totalCompleted++;
            dayCompletedCount++;
            
            final subject = task.subject?.trim().isNotEmpty == true 
                ? task.subject! 
                : (task.title.trim().isNotEmpty == true ? task.title : 'General');
            
            final duration = task.completedDurationMinutes > 0
                ? task.completedDurationMinutes
                : (task.elapsedSeconds ~/ 60);

            totalMinutes += duration;
            subjectMap[subject] = (subjectMap[subject] ?? 0) + duration;
          }
        }

        if (dailyCompletedCount.containsKey(dateKey)) {
          dailyCompletedCount[dateKey] = dayCompletedCount;
        }

        if (dayCompletedCount > maxCompletedInADay) {
          maxCompletedInADay = dayCompletedCount;
          bestDayStr = DateFormat('EEEE, MMM d').format(routine.date);
        }
      }

      // Prepare Weekly Bar Chart data
      List<int> weeklyCompleted = [];
      List<String> days = [];
      for (int i = 0; i < last7Days.length; i++) {
        final day = last7Days[i];
        final dateKey = fullDateFormat.format(day);
        final completed = dailyCompletedCount[dateKey] ?? 0;
        days.add(dayFormat.format(day));
        weeklyCompleted.add(completed);
      }

      // Calculate averages
      double avgTasks = snapshot.docs.isNotEmpty ? totalCompleted / snapshot.docs.length : 0.0;

      if (mounted) {
        setState(() {
          _totalTasksDone = totalCompleted;
          _totalStudyHours = totalMinutes / 60.0;
          _avgDailyTasks = avgTasks;
          _bestDay = bestDayStr;
          _weeklyCompletedCount = weeklyCompleted;
          _weeklyDays = days;
          _subjectDurations = subjectMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading analytics: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    // Build Weekly Bar Groups
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < _weeklyCompletedCount.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _weeklyCompletedCount[i].toDouble(),
              color: primaryColor,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 10,
                color: primaryColor.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
    }

    // Build Subject Pie Sections
    List<Color> colorPalette = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.red,
      Colors.indigo,
      Colors.pink,
    ];
    List<PieChartSectionData> pieSections = [];
    int colorIndex = 0;
    int totalSubjectMinutes = _subjectDurations.values.fold(0, (acc, val) => acc + val);

    _subjectDurations.forEach((subj, mins) {
      final double percentage = totalSubjectMinutes > 0 ? (mins / totalSubjectMinutes) * 100 : 0.0;
      final color = colorPalette[colorIndex % colorPalette.length];
      colorIndex++;

      pieSections.add(
        PieChartSectionData(
          color: color,
          value: mins.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview stats cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricCard(
                        'Total Study',
                        '${_totalStudyHours.toStringAsFixed(1)}h',
                        Icons.hourglass_empty_rounded,
                        Colors.orange,
                      ),
                      _buildMetricCard(
                        'Tasks Done',
                        '$_totalTasksDone',
                        Icons.task_alt_rounded,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricCard(
                        'Daily Avg',
                        '${_avgDailyTasks.toStringAsFixed(1)} tasks',
                        Icons.analytics_rounded,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'Best Day',
                        _bestDay,
                        Icons.star_rounded,
                        Colors.amber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Weekly Bar Chart Card
                  Text(
                    'Weekly Task Performance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: BarChart(
                      BarChartData(
                        barGroups: barGroups,
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        alignment: BarChartAlignment.spaceAround,
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _weeklyDays.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _weeklyDays[index],
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Subject Pie Chart Card
                  Text(
                    'Subject Study Distribution',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  pieSections.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'No study distribution data available yet. Complete some tasks first!',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 160,
                                child: PieChart(
                                  PieChartData(
                                    sections: pieSections,
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Legends
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: _buildPieLegends(),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: MediaQuery.of(context).size.width * 0.43,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPieLegends() {
    List<Color> colorPalette = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.red,
      Colors.indigo,
      Colors.pink,
    ];
    List<Widget> legends = [];
    int index = 0;

    _subjectDurations.forEach((subj, mins) {
      final color = colorPalette[index % colorPalette.length];
      index++;

      legends.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$subj ($mins m)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    });

    return legends;
  }
}
