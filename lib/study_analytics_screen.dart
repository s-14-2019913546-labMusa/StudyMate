import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'daily_routine.dart';
import 'language_manager.dart';

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

  // New analytics datasets
  List<int> _hourlyCompletedCount = List.filled(24, 0); // 24 hours study counts
  List<double> _monthlyTrendMinutes = []; // last 30 days total minutes
  List<String> _monthlyDays = [];
  Map<String, double> _heatmapValues = {}; // date -> completion percentage (0.0 to 1.0)

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
      Map<String, int> dailyTotalMinutes = {};
      Map<String, int> dailyTaskTotalCount = {};
      List<int> hourlyCompleted = List.filled(24, 0);
      
      final DateFormat dayFormat = DateFormat('E');
      final DateFormat fullDateFormat = DateFormat('yyyy-MM-dd');
      
      // Initialize daily count for last 30 days
      List<DateTime> last30Days = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
      for (var day in last30Days) {
        final key = fullDateFormat.format(day);
        dailyCompletedCount[key] = 0;
        dailyTotalMinutes[key] = 0;
        dailyTaskTotalCount[key] = 0;
      }

      int maxCompletedInADay = 0;
      String bestDayStr = "N/A";

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final routine = DailyRoutine.fromMap(data, doc.id);
        final dateKey = fullDateFormat.format(routine.date);

        int dayCompletedCount = 0;
        
        if (dailyTaskTotalCount.containsKey(dateKey)) {
          dailyTaskTotalCount[dateKey] = routine.tasks.length;
        }

        for (var task in routine.tasks) {
          final isCompleted = task.status == 'completed' || task.isCompleted;
          final fromElapsed = task.totalDurationMinutes > 0
              ? (task.elapsedSeconds / (task.totalDurationMinutes * 60))
              : 0.0;
          final fromMinutes = task.totalDurationMinutes > 0
              ? (task.completedDurationMinutes / task.totalDurationMinutes)
              : 0.0;
          final actualProgress = fromElapsed > fromMinutes ? fromElapsed : fromMinutes;

          if (isCompleted && actualProgress >= 0.70) {
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
            
            if (dailyTotalMinutes.containsKey(dateKey)) {
              dailyTotalMinutes[dateKey] = (dailyTotalMinutes[dateKey] ?? 0) + duration;
            }

            // Peak study hours detection
            if (task.startTime != null) {
              int startHour = task.startTime!.hour;
              hourlyCompleted[startHour]++;
            } else if (task.endTime != null) {
              int endHour = task.endTime!.hour;
              hourlyCompleted[endHour]++;
            } else {
              hourlyCompleted[now.hour]++;
            }
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

      // Prepare Weekly Bar Chart data (last 7 days)
      List<int> weeklyCompleted = [];
      List<String> days = [];
      List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
      for (int i = 0; i < last7Days.length; i++) {
        final day = last7Days[i];
        final dateKey = fullDateFormat.format(day);
        final completed = dailyCompletedCount[dateKey] ?? 0;
        days.add(dayFormat.format(day));
        weeklyCompleted.add(completed);
      }

      // Prepare Monthly Line Chart data (last 30 days) and Heatmap values
      List<double> monthlyTrend = [];
      List<String> monthlyLabels = [];
      Map<String, double> heatmap = {};

      for (var day in last30Days) {
        final dateKey = fullDateFormat.format(day);
        final double minutes = (dailyTotalMinutes[dateKey] ?? 0).toDouble();
        monthlyTrend.add(minutes);
        monthlyLabels.add(DateFormat('d').format(day));

        final int totalTasks = dailyTaskTotalCount[dateKey] ?? 0;
        final int doneTasks = dailyCompletedCount[dateKey] ?? 0;
        double ratio = 0.0;
        if (totalTasks > 0) {
          ratio = doneTasks / totalTasks;
        } else if (doneTasks > 0) {
          ratio = 1.0;
        }
        heatmap[dateKey] = ratio;
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
          _hourlyCompletedCount = hourlyCompleted;
          _monthlyTrendMinutes = monthlyTrend;
          _monthlyDays = monthlyLabels;
          _heatmapValues = heatmap;
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

    // Build Hourly Bar Groups for Peak Hours
    List<BarChartGroupData> hourlyBarGroups = [];
    for (int i = 0; i < _hourlyCompletedCount.length; i++) {
      hourlyBarGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _hourlyCompletedCount[i].toDouble(),
              color: Colors.amber,
              width: 6,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
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
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Total Study',
                          '${_totalStudyHours.toStringAsFixed(1)}h',
                          Icons.hourglass_empty_rounded,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Tasks Done',
                          '$_totalTasksDone',
                          Icons.task_alt_rounded,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Daily Avg',
                          '${_avgDailyTasks.toStringAsFixed(1)} tasks',
                          Icons.analytics_rounded,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Best Day',
                          _bestDay,
                          Icons.star_rounded,
                          Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Weekly Bar Chart Card
                  Text(
                    'Weekly Task Performance'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
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
                              reservedSize: 36,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _weeklyDays.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _weeklyDays[index].tr(),
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

                  // Peak Study Hours Bar Chart
                  Text(
                    'Peak Focus Hours'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
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
                        barGroups: hourlyBarGroups,
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
                              reservedSize: 30,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final hour = value.toInt();
                                if (hour % 4 == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      '$hour:00',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold),
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

                  // Monthly Study Trend Line Chart
                  Text(
                    'Monthly Study Trend'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
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
                    child: _monthlyTrendMinutes.isEmpty
                        ? const Center(child: Text('Not enough data'))
                        : LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < _monthlyDays.length && index % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            _monthlyDays[index],
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    _monthlyTrendMinutes.length,
                                    (i) => FlSpot(i.toDouble(), _monthlyTrendMinutes[i]),
                                  ),
                                  isCurved: true,
                                  color: primaryColor,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: primaryColor.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // Streak Calendar Heatmap
                  Text(
                    'Study Calendar Heatmap'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemCount: 30,
                          itemBuilder: (ctx, i) {
                            final keys = _heatmapValues.keys.toList();
                            if (i >= keys.length) return const SizedBox.shrink();
                            final dateKey = keys[i];
                            final ratio = _heatmapValues[dateKey] ?? 0.0;
                            final dayNum = dateKey.split('-').last;

                            Color boxColor = Colors.grey.shade200;
                            if (isDark) boxColor = Colors.grey.shade800;

                            if (ratio > 0.0) {
                              boxColor = Colors.green.shade500.withValues(alpha: 0.2 + (ratio * 0.8));
                            }

                            return Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: boxColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ratio > 0.0 ? Colors.green : Colors.transparent,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                dayNum,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ratio > 0.0 ? Colors.white : Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Less'.tr(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(width: 4),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green.shade200, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green.shade400, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Text('More'.tr(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Subject Pie Chart Card
                  Text(
                    'Subject Study Distribution'.tr(),
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
                          child: Center(
                            child: Text(
                              'No study distribution data available yet. Complete some tasks first!'.tr(),
                              style: const TextStyle(color: Colors.grey),
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
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Row(
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
              Flexible(
                child: Text(
                  '$subj ($mins m)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });

    return legends;
  }
}
