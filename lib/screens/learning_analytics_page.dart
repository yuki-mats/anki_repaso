import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:repaso/utils/app_colors.dart';

class LearningAnalyticsPage extends StatefulWidget {
  final List<DocumentReference> questionRefs;

  LearningAnalyticsPage({required this.questionRefs});

  @override
  _LearningAnalyticsPageState createState() => _LearningAnalyticsPageState();
}

class _LearningAnalyticsPageState extends State<LearningAnalyticsPage> {
  late Future<Map<String, dynamic>> analyticsData;

  @override
  void initState() {
    super.initState();
    analyticsData = fetchAnalyticsData(widget.questionRefs);
  }

  Future<Map<String, dynamic>> fetchAnalyticsData(List<DocumentReference> questionRefs) async {
    try {
      if (questionRefs.isEmpty) {
        return {
          'dailyStats': {'attempts': {}, 'accuracy': {}},
          'totalAttemptCount': 0,
          'totalStudyTime': 0,
        };
      }

      int totalAttemptCount = 0;
      int totalStudyTime = 0;
      Map<String, int> attempts = {};
      Map<String, int> correctAnswers = {};
      Map<String, double> accuracy = {};

      for (var questionRef in questionRefs) {
        QuerySnapshot userStatsSnapshot = await questionRef.collection("questionUserStats").get();

        for (var userStatsDoc in userStatsSnapshot.docs) {
          QuerySnapshot statsSnapshot = await userStatsDoc.reference.collection("dailyStats").get();

          for (var statDoc in statsSnapshot.docs) {
            final statData = statDoc.data() as Map<String, dynamic>;

            String? date = (statData['dateTimestamp'] as Timestamp?)?.toDate().toIso8601String().split('T')[0];
            if (date != null) {
              int dailyAttempts = (statData['attemptCount'] as num?)?.toInt() ?? 0;
              int dailyCorrect = (statData['correctCount'] as num?)?.toInt() ?? 0;
              int dailyStudyTime = (statData['totalStudyTime'] as num?)?.toInt() ?? 0;

              attempts[date] = (attempts[date] ?? 0) + dailyAttempts;
              correctAnswers[date] = (correctAnswers[date] ?? 0) + dailyCorrect;
              totalAttemptCount += dailyAttempts;
              totalStudyTime += dailyStudyTime;
            }
          }
        }
      }

      for (var date in attempts.keys) {
        int attempt = attempts[date] ?? 0;
        int correct = correctAnswers[date] ?? 0;
        accuracy[date] = attempt > 0 ? (correct / attempt) * 100 : 0.0;
      }

      return {
        'dailyStats': {
          'attempts': attempts,
          'accuracy': accuracy,
        },
        'totalAttemptCount': totalAttemptCount,
        'totalStudyTime': totalStudyTime,
      };
    } catch (e) {
      print("Error fetching analytics data: $e");
      return {
        'dailyStats': {'attempts': {}, 'accuracy': {}},
        'totalAttemptCount': 0,
        'totalStudyTime': 0,
      };
    }
  }

  List<String> _generateLast7Days() {
    DateTime today = DateTime.now();
    return List.generate(7, (index) {
      DateTime day = today.subtract(Duration(days: index));
      return DateFormat('yyyy-MM-dd').format(day);
    }).reversed.toList();
  }

  double _calculateStepSize(double maxY) {
    if (maxY == 0) return 1;
    double rawStep = maxY / 2;
    int magnitude = rawStep.floor().toString().length - 1;
    double stepBase = pow(10, magnitude).toDouble();
    return (rawStep / stepBase).ceil() * stepBase;
  }

  Widget buildBarChart({
    required Map<String, double> data,
    required List<String> labels,
    required double maxValue,
    required String tooltipSuffix,
    required Color barColor,
  }) {
    double stepSize = _calculateStepSize(maxValue);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: stepSize,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 0.8,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < labels.length) {
                  String label = labels[index];
                  DateTime date = DateTime.parse(label);
                  String weekday = DateFormat.E('ja').format(date);
                  return Text(weekday, style: const TextStyle(fontSize: 16));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        barGroups: labels.map((label) {
          int index = labels.indexOf(label);
          double value = data[label] ?? 0.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                width: 16,
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipHorizontalAlignment: FLHorizontalAlignment.center,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipMargin: 400,
            getTooltipColor: (group) => AppColors.gray50,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipBorder: BorderSide(color: AppColors.gray50, width: 1),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label = labels[group.x.toInt()];
              return BarTooltipItem(
                '$label: ${rod.toY.toInt()}$tooltipSuffix',
                const TextStyle(color: Colors.black, fontSize: 12),
              );
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  Widget _buildAttemptBarChart(Map<String, dynamic> stats) {
    Map<String, int> attempts = Map<String, int>.from(stats['attempts']);
    List<String> last7Days = _generateLast7Days();

    double maxAttempts = attempts.values.isNotEmpty
        ? attempts.values.reduce((a, b) => a > b ? a : b).toDouble()
        : 0;
    maxAttempts = maxAttempts > 0 ? maxAttempts * 1.2 : 10;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        color: Colors.transparent,
        height: 320,
        child: buildBarChart(
          data: attempts.map((k, v) => MapEntry(k, v.toDouble())),
          labels: last7Days,
          maxValue: maxAttempts,
          tooltipSuffix: '回',
          barColor: AppColors.blue400,
        ),
      ),
    );
  }

  Widget _buildAccuracyBarChart(Map<String, dynamic> stats) {
    Map<String, double> accuracyRates = Map<String, double>.from(stats['accuracy']);
    List<String> last7Days = _generateLast7Days();

    double maxAccuracy = accuracyRates.values.isNotEmpty
        ? accuracyRates.values.reduce((a, b) => a > b ? a : b)
        : 0;
    maxAccuracy = maxAccuracy > 0 ? maxAccuracy * 1.2 : 10;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        color: Colors.transparent,
        height: 320,
        child: buildBarChart(
          data: accuracyRates,
          labels: last7Days,
          maxValue: maxAccuracy,
          tooltipSuffix: '%',
          barColor: AppColors.blue400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ダッシュボード'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: analyticsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('データの取得中にエラーが発生しました。後でもう一度お試しください。'),
            );
          }

          Map<String, dynamic> data = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildAttemptBarChart(data['dailyStats']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildAccuracyBarChart(data['dailyStats']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
