import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// StudySet モデル
/// すべてのフィールドを省略せず記述しています。
class StudySet {
  /// Firestore ドキュメント ID
  final String id;

  /// 学習セット名
  final String name;

  /// 対象となる問題集 ID リスト
  final List<String> questionSetIds;

  /// 出題数（最大）
  final int numberOfQuestions;

  /// 出題順
  ///   random | attemptsDescending | attemptsAscending | accuracyDescending |
  ///   accuracyAscending | studyTimeDescending | studyTimeAscending |
  ///   responseTimeDescending | responseTimeAscending |
  ///   lastStudiedDescending | lastStudiedAscending
  final String selectedQuestionOrder;

  /// 正答率フィルター（下限〜上限）
  final RangeValues correctRateRange;

  /// フラグ（要確認）のみを対象とするか
  final bool isFlagged;

  /// 記憶度フィルター（again / hard / good / easy）
  final List<String> selectedMemoryLevels;

  /// 「正しい」問題だけ / 「間違い」問題だけ / すべて
  ///   'all' | 'correct' | 'incorrect'
  final String correctChoiceFilter;

  /// ユーザーの学習履歴により更新される統計値
  final Map<String, int> memoryLevelStats;   // 各記憶度の累計数
  final Map<String, int> memoryLevelRatios; // 各記憶度の割合（%）
  final int totalAttemptCount;              // 総試行回数
  final int studyStreakCount;               // 連続学習日数
  final String lastStudiedDate;             // 最後に学習した日 (YYYY-MM-DD)

  /// 作成日時（nullable：未保存のときは null）
  final DateTime? createdAt;

  // ───────────────────────────────────────────
  // コンストラクタ
  // ───────────────────────────────────────────
  StudySet({
    required this.id,
    required this.name,
    required this.questionSetIds,
    required this.numberOfQuestions,
    required this.selectedQuestionOrder,
    required this.correctRateRange,
    required this.isFlagged,
    required this.selectedMemoryLevels,
    required this.correctChoiceFilter,
    required this.memoryLevelStats,
    required this.memoryLevelRatios,
    required this.totalAttemptCount,
    required this.studyStreakCount,
    required this.lastStudiedDate,
    this.createdAt,
  });

  // ───────────────────────────────────────────
  // Firestore から生成
  // ───────────────────────────────────────────
  factory StudySet.fromFirestore(String id, Map<String, dynamic> data) {
    return StudySet(
      id: id,
      name: data['name'] as String? ?? '',
      questionSetIds: List<String>.from(data['questionSetIds'] ?? []),
      numberOfQuestions: data['numberOfQuestions'] as int? ?? 10,
      selectedQuestionOrder: data['selectedQuestionOrder'] as String? ?? 'random',
      correctRateRange: RangeValues(
        (data['correctRateRange']?['start'] ?? 0).toDouble(),
        (data['correctRateRange']?['end'] ?? 100).toDouble(),
      ),
      isFlagged: data['isFlagged'] as bool? ?? false,
      selectedMemoryLevels:
      List<String>.from(data['selectedMemoryLevels'] ?? ['again', 'hard', 'good', 'easy']),
      correctChoiceFilter: data['correctChoiceFilter'] as String? ?? 'all',
      memoryLevelStats: Map<String, int>.from(
        data['memoryLevelStats'] ?? {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      ),
      memoryLevelRatios: Map<String, int>.from(
        data['memoryLevelRatios'] ?? {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      ),
      totalAttemptCount: data['totalAttemptCount'] as int? ?? 0,
      studyStreakCount: data['studyStreakCount'] as int? ?? 0,
      lastStudiedDate: data['lastStudiedDate'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ───────────────────────────────────────────
  // Firestore 保存用 Map
  // ───────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'questionSetIds': questionSetIds,
      'numberOfQuestions': numberOfQuestions,
      'selectedQuestionOrder': selectedQuestionOrder,
      'correctRateRange': {
        'start': correctRateRange.start,
        'end': correctRateRange.end,
      },
      'isFlagged': isFlagged,
      'selectedMemoryLevels': selectedMemoryLevels,
      'correctChoiceFilter': correctChoiceFilter,
      'memoryLevelStats': memoryLevelStats,
      'memoryLevelRatios': memoryLevelRatios,
      'totalAttemptCount': totalAttemptCount,
      'studyStreakCount': studyStreakCount,
      'lastStudiedDate': lastStudiedDate,
      'createdAt': createdAt,
    };
  }
}
