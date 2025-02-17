// lib/common/answer_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// メモリレベルに応じた色を返す
Color getMemoryLevelColor(String level) {
  switch (level) {
    case 'unanswered':
      return Colors.grey[300]!;
    case 'again':
      return Colors.red[300]!;
    case 'hard':
      return Colors.orange[300]!;
    case 'good':
      return Colors.green[300]!;
    case 'easy':
      return Colors.blue[300]!;
    default:
      return Colors.grey;
  }
}

/// 進捗バー用：各問題のメモリレベルに対応した色リストを返す
List<Color> getProgressColors({
  required int totalQuestions,
  required List<Map<String, dynamic>> answerResults,
}) {
  if (totalQuestions == 0) return [Colors.grey[300]!];

  // 未回答数を含めたカウント
  Map<String, int> memoryLevelCounts = {
    'easy': 0,
    'good': 0,
    'hard': 0,
    'again': 0,
    'unanswered': totalQuestions - answerResults.length,
  };

  for (var result in answerResults) {
    String level = result['memoryLevel'] ?? 'unanswered';
    memoryLevelCounts[level] = (memoryLevelCounts[level] ?? 0) + 1;
  }

  List<String> levelOrder = ['again', 'hard', 'good', 'easy', 'unanswered'];
  List<Color> colors = [];
  for (String level in levelOrder) {
    int count = memoryLevelCounts[level] ?? 0;
    if (count > 0) {
      colors.addAll(List.filled(count, getMemoryLevelColor(level)));
    }
  }
  return colors;
}

/// 回答内容・統計情報を Firestore に保存する共通処理
Future<void> saveAnswer({
  required String questionId,
  required bool isAnswerCorrect,
  required DateTime answeredAt,
  DateTime? nextStartedAt,
  required String memoryLevel,
  required DocumentReference questionSetRef,
  DocumentReference? folderRef,
  required String selectedAnswer,
  required String correctChoiceText,
  DateTime? startedAt,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final userId = user.uid;
    final questionRef = FirebaseFirestore.instance.collection('questions').doc(questionId);
    final questionUserStatsRef = questionRef.collection('questionUserStats').doc(userId);
    final questionSetUserStatsRef = questionSetRef.collection('questionSetUserStats').doc(userId);

    final answerTime = (startedAt != null)
        ? answeredAt.difference(startedAt).inMilliseconds
        : 0;
    final postAnswerTime = nextStartedAt != null
        ? nextStartedAt.difference(answeredAt).inMilliseconds
        : 0;

    // answerHistories に保存
    await FirebaseFirestore.instance.collection('answerHistories').add({
      'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
      'questionRef': questionRef,
      'questionSetRef': questionSetRef,
      if (folderRef != null) 'folderRef': folderRef,
      'startedAt': startedAt,
      'answeredAt': answeredAt,
      'nextStartedAt': nextStartedAt,
      'answerTime': answerTime,
      'postAnswerTime': postAnswerTime,
      'isCorrect': isAnswerCorrect,
      'selectedChoice': selectedAnswer,
      'correctChoice': correctChoiceText,
      'memoryLevel': memoryLevel,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // questionUserStats の更新
    await questionUserStatsRef.set({
      'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
      'memoryLevel': memoryLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // questionSetUserStats の更新
    await questionSetUserStatsRef.set({
      'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
      'memoryLevels': {
        questionId: memoryLevel,
      },
      'lastStudiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // folderSetUserStats の更新（folderRef がある場合）
    if (folderRef != null) {
      final folderSetUserStatsRef = folderRef.collection('folderSetUserStats').doc(userId);
      await folderSetUserStatsRef.set({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'memoryLevels': {
          questionId: memoryLevel,
        },
        'lastStudiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 統計情報の更新
    await updateStatsUsingAggregation(
      questionId: questionId,
      questionRef: questionRef,
      userId: userId,
    );
  } catch (e) {
    print('Error saving answer: $e');
  }
}

/// 統計情報の更新処理（_updateStatsUsingAggregation の共通処理版）
Future<void> updateStatsUsingAggregation({
  required String questionId,
  required DocumentReference questionRef,
  required String userId,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final now = DateTime.now();
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final historiesRef = FirebaseFirestore.instance.collection('answerHistories');

    int calculateIsoWeekNumber(DateTime date) {
      final firstDayOfYear = DateTime(date.year, 1, 1);
      final firstThursday = firstDayOfYear.add(Duration(days: (4 - firstDayOfYear.weekday + 7) % 7));
      final weekNumber = ((date.difference(firstThursday).inDays) / 7).ceil() + 1;
      return weekNumber;
    }

    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final isoWeekNumber = calculateIsoWeekNumber(now);
    final weekKey = '${now.year}-W${isoWeekNumber.toString().padLeft(2, '0')}';
    final monthKey = DateFormat('yyyy-MM').format(now);

    final attemptQuery = historiesRef
        .where('userRef', isEqualTo: userRef)
        .where('questionRef', isEqualTo: questionRef);

    final attemptCountSnapshot = await attemptQuery.count().get();
    final attemptCount = attemptCountSnapshot.count ?? 0;
    final correctCountSnapshot = await attemptQuery.where('isCorrect', isEqualTo: true).count().get();
    final correctCount = correctCountSnapshot.count ?? 0;
    final correctRate = attemptCount > 0 ? (correctCount / attemptCount) : 0;

    final questionUserStatsRef = questionRef.collection('questionUserStats').doc(userId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final questionUserStatsDoc = await transaction.get(questionUserStatsRef);
      if (!questionUserStatsDoc.exists) {
        transaction.set(questionUserStatsRef, {
          'userRef': userRef,
          'attemptCount': attemptCount,
          'correctCount': correctCount,
          'correctRate': correctRate,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(questionUserStatsRef, {
          'attemptCount': attemptCount,
          'correctCount': correctCount,
          'correctRate': correctRate,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // 以下、日/週/月ごとの統計更新処理（_aggregateStats, _updateStat を利用）
    Future<Map<String, dynamic>> aggregateStats(DateTime start, DateTime end) async {
      final query = historiesRef
          .where('userRef', isEqualTo: userRef)
          .where('questionRef', isEqualTo: questionRef)
          .where('answeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('answeredAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      final aggregateQuerySnapshot = await query.aggregate(
        count(),
        sum('answerTime'),
        sum('postAnswerTime'),
      ).get();
      final attemptCount = aggregateQuerySnapshot.count ?? 0;
      final totalAnswerTime = aggregateQuerySnapshot.getSum('answerTime') ?? 0;
      final totalPostAnswerTime = aggregateQuerySnapshot.getSum('postAnswerTime') ?? 0;
      final totalStudyTime = totalAnswerTime + totalPostAnswerTime;
      final correctCountSnapshot = await query.where('isCorrect', isEqualTo: true).count().get();
      final correctCount = correctCountSnapshot.count ?? 0;
      final incorrectCount = attemptCount - correctCount;
      return {
        'attemptCount': attemptCount,
        'correctCount': correctCount,
        'incorrectCount': incorrectCount,
        'totalAnswerTime': totalAnswerTime,
        'totalPostAnswerTime': totalPostAnswerTime,
        'totalStudyTime': totalStudyTime,
      };
    }

    final dateStart = DateTime(now.year, now.month, now.day);
    final weekStart = dateStart.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1).subtract(const Duration(seconds: 1));

    final dailyStats = await aggregateStats(dateStart, dateStart.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
    final weeklyStats = await aggregateStats(weekStart, weekEnd);
    final monthlyStats = await aggregateStats(monthStart, monthEnd);

    Future<void> updateStat(String collectionName, String key, Map<String, dynamic> stats, Map<String, dynamic> additionalFields) async {
      final questionUserStatsRef = questionRef.collection('questionUserStats').doc(userId);
      final statDocRef = questionUserStatsRef.collection(collectionName).doc(key);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final questionUserStatsDoc = await transaction.get(questionUserStatsRef);
        if (!questionUserStatsDoc.exists) {
          transaction.set(questionUserStatsRef, {
            'userRef': userRef,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        transaction.set(
          statDocRef,
          {
            ...stats,
            ...additionalFields,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    }

    await updateStat('dailyStats', dateKey, dailyStats, {
      'date': dateKey,
      'dateTimestamp': Timestamp.fromDate(dateStart),
    });
    await updateStat('weeklyStats', weekKey, weeklyStats, {
      'week': weekKey,
      'weekStartTimestamp': Timestamp.fromDate(weekStart),
      'weekEndTimestamp': Timestamp.fromDate(weekEnd),
    });
    await updateStat('monthlyStats', monthKey, monthlyStats, {
      'month': monthKey,
      'monthStartTimestamp': Timestamp.fromDate(monthStart),
      'monthEndTimestamp': Timestamp.fromDate(monthEnd),
    });
  } catch (e) {
    print('Error updating stats using aggregation queries: $e');
  }
}
