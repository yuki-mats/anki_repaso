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

/// 回答内容・統計情報を Firestore に保存する共通処理（IDベースで更新）
Future<void> saveAnswer({
  required String questionId,
  required String questionSetId,
  required String folderId,
  required bool isAnswerCorrect,
  required DateTime answeredAt,
  DateTime? nextStartedAt,
  required String memoryLevel,
  required String selectedAnswer,
  required String correctChoiceText,
  DateTime? startedAt,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final userId = user.uid;
    // 質問ドキュメントは questionId を用いて取得
    final DocumentReference questionRef =
    FirebaseFirestore.instance.collection('questions').doc(questionId);

    // answerHistories に保存（Reference の代わりにIDを保存）
    await FirebaseFirestore.instance.collection('answerHistories').add({
      'userId': userId,
      'questionId': questionId,
      'startedAt': startedAt,
      'answeredAt': answeredAt,
      'nextStartedAt': nextStartedAt,
      'answerTime': (startedAt != null)
          ? answeredAt.difference(startedAt).inMilliseconds
          : 0,
      'postAnswerTime': (nextStartedAt != null)
          ? nextStartedAt.difference(answeredAt).inMilliseconds
          : 0,
      'isCorrect': isAnswerCorrect,
      'selectedChoice': selectedAnswer,
      'correctChoice': correctChoiceText,
      'memoryLevel': memoryLevel,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // questionUserStats の更新
    final DocumentReference questionUserStatsRef =
    questionRef.collection('questionUserStats').doc(userId);
    await questionUserStatsRef.set({
      'userId': userId,
      'memoryLevel': memoryLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // questionSetUserStats の更新（questionSetsコレクション内のドキュメントは、IDをもとに更新）
    final DocumentReference questionSetUserStatsRef =
    FirebaseFirestore.instance
        .collection('questionSets')
        .doc(questionSetId)
        .collection('questionSetUserStats')
        .doc(userId);
    await questionSetUserStatsRef.set({
      'userId': userId,
      'memoryLevels': {
        questionId: memoryLevel,
      },
      'lastStudiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // folderSetUserStats の更新（foldersコレクション内のドキュメントは、IDをもとに更新）
    final DocumentReference folderSetUserStatsRef =
    FirebaseFirestore.instance
        .collection('folders')
        .doc(folderId)
        .collection('folderSetUserStats')
        .doc(userId);
    await folderSetUserStatsRef.set({
      'userId': userId,
      'memoryLevels': {
        questionId: memoryLevel,
      },
      'lastStudiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 統計情報の更新処理
    await updateStatsUsingAggregation(
      questionId: questionId,
      questionRef: questionRef,
      userId: userId,
    );
  } catch (e) {
    print('Error saving answer: $e');
  }
}

/// 統計情報の更新処理（更新対象は質問ドキュメントのサブコレクション）
Future<void> updateStatsUsingAggregation({
  required String questionId,
  required DocumentReference questionRef,
  required String userId,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final now = DateTime.now();
    // userIdのみで管理するので、userRefはIDを使わない
    final String userIdStr = userId;
    final historiesRef =
    FirebaseFirestore.instance.collection('answerHistories');

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

    // query では、userId や questionId の一致でフィルタする
    final attemptQuery = historiesRef
        .where('userId', isEqualTo: userIdStr)
        .where('questionId', isEqualTo: questionId);

    final attemptCountSnapshot = await attemptQuery.count().get();
    final attemptCount = attemptCountSnapshot.count ?? 0;
    final correctCountSnapshot = await attemptQuery.where('isCorrect', isEqualTo: true).count().get();
    final correctCount = correctCountSnapshot.count ?? 0;
    final correctRate = attemptCount > 0 ? (correctCount / attemptCount) : 0;

    final DocumentReference questionUserStatsRef =
    questionRef.collection('questionUserStats').doc(userIdStr);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final questionUserStatsDoc = await transaction.get(questionUserStatsRef);
      if (!questionUserStatsDoc.exists) {
        transaction.set(questionUserStatsRef, {
          'userId': userIdStr,
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

    // 日/週/月ごとの統計更新処理
    Future<Map<String, dynamic>> aggregateStats(DateTime start, DateTime end) async {
      final query = historiesRef
          .where('userId', isEqualTo: userIdStr)
          .where('questionId', isEqualTo: questionId)
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
      final DocumentReference questionUserStatsRef = questionRef.collection('questionUserStats').doc(userIdStr);
      final DocumentReference statDocRef = questionUserStatsRef.collection(collectionName).doc(key);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final questionUserStatsDoc = await transaction.get(questionUserStatsRef);
        if (!questionUserStatsDoc.exists) {
          transaction.set(questionUserStatsRef, {
            'userId': userIdStr,
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

Future<void> updateStudySetStats({
  required String studySetId,
  required String userId,
  required List<Map<String, dynamic>> answerResults,
  required DateTime sessionStart,
  required DateTime sessionEnd,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    // StudySet ドキュメントの参照（ユーザー配下）
    final studySetRef = firestore
        .collection('users')
        .doc(userId)
        .collection('studySets')
        .doc(studySetId);

    // 現在保存されている累積統計情報を取得
    DocumentSnapshot studySetSnapshot = await studySetRef.get();
    Map<String, dynamic> currentData =
    studySetSnapshot.exists ? studySetSnapshot.data() as Map<String, dynamic> : {};
    // 既存の memoryLevelStats（なければ初期値）
    Map<String, int> currentMemoryLevelStats = currentData['memoryLevelStats'] != null
        ? Map<String, int>.from(currentData['memoryLevelStats'])
        : {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
    int currentTotalAttemptCount = currentData['totalAttemptCount'] ?? 0;
    int currentStudyStreakCount = currentData['studyStreakCount'] ?? 0;
    String? lastStudiedDate = currentData['lastStudiedDate'];

    // 今回のセッション結果から統計を計算
    int sessionAttemptCount = answerResults.length;
    int sessionCorrectCount =
        answerResults.where((result) => result['isCorrect'] == true).length;
    double sessionCorrectRate =
    sessionAttemptCount > 0 ? (sessionCorrectCount / sessionAttemptCount * 100) : 0.0;

    // セッションごとの memoryLevel のカウント（対象: 'again', 'hard', 'good', 'easy'）
    Map<String, int> sessionMemoryLevelStats = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
    for (var result in answerResults) {
      String level = result['memoryLevel'] ?? '';
      if (sessionMemoryLevelStats.containsKey(level)) {
        sessionMemoryLevelStats[level] = sessionMemoryLevelStats[level]! + 1;
      }
    }

    // 累積統計に今回分を加算
    Map<String, int> newAggregatedMemoryLevelStats = {};
    for (String level in ['again', 'hard', 'good', 'easy']) {
      newAggregatedMemoryLevelStats[level] =
          currentMemoryLevelStats[level]! + sessionMemoryLevelStats[level]!;
    }
    int newTotalAttemptCount = currentTotalAttemptCount + sessionAttemptCount;
    // 新たな memoryLevelRatios を算出（%）
    Map<String, double> newMemoryLevelRatios = {};
    newAggregatedMemoryLevelStats.forEach((level, count) {
      newMemoryLevelRatios[level] =
      newTotalAttemptCount > 0 ? (count / newTotalAttemptCount * 100) : 0.0;
    });

    // セッションの学習時間（秒）
    int sessionStudyDuration = sessionEnd.difference(sessionStart).inSeconds;

    // 日付文字列（YYYY-MM-DD）
    String todayStr = DateFormat('yyyy-MM-dd').format(sessionEnd);
    // 学習継続日数更新用：昨日の日付
    String yesterdayStr = DateFormat('yyyy-MM-dd')
        .format(sessionEnd.subtract(const Duration(days: 1)));

    // 学習継続日数の更新：前回の最終学習日が昨日なら連続日数を+1、そうでなければ1にリセット
    int newStudyStreakCount;
    if (lastStudiedDate != null && lastStudiedDate == yesterdayStr) {
      newStudyStreakCount = currentStudyStreakCount + 1;
    } else {
      newStudyStreakCount = 1;
    }

    // StudySet ドキュメントの更新（累積統計情報）
    await studySetRef.update({
      'memoryLevelStats': newAggregatedMemoryLevelStats,
      'memoryLevelRatios': newMemoryLevelRatios,
      'totalAttemptCount': newTotalAttemptCount,
      'studyStreakCount': newStudyStreakCount,
      'lastStudiedDate': todayStr,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // サブコレクション studySetDailyStats の更新（当日の統計）
    final dailyStatsRef = studySetRef.collection('studySetDailyStats').doc(todayStr);
    await dailyStatsRef.set({
      'isStudied': true,
      'studyDuration': sessionStudyDuration,
      'correctRate': sessionCorrectRate,
      'attemptCount': sessionAttemptCount,
      'again': sessionMemoryLevelStats['again'],
      'hard': sessionMemoryLevelStats['hard'],
      'good': sessionMemoryLevelStats['good'],
      'easy': sessionMemoryLevelStats['easy'],
      'date': todayStr,
      'dateTimestamp': Timestamp.fromDate(DateTime.parse(todayStr)),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('StudySet の累積統計情報を更新しました。');
  } catch (e) {
    print('StudySet 統計情報更新エラー: $e');
  }
}