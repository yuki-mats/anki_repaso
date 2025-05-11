import 'package:flutter/material.dart';

class MemoryLevelProgressBar extends StatelessWidget {
  /// 各レベルの件数（unanswered は含めず、ウィジェット内で計算）
  final Map<String, int> memoryValues; // {'again':1, 'hard':0, 'good':0, 'easy':0}
  /// 問題の総数
  final int totalCount;
  /// バーの高さ
  final double height;
  /// 角丸
  final BorderRadiusGeometry borderRadius;

  const MemoryLevelProgressBar({
    Key? key,
    required this.memoryValues,
    required this.totalCount,
    this.height = 5.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
  }) : super(key: key);

  // レベルに応じたグラデーション
  LinearGradient _gradient(String level) {
    switch (level) {
      case 'again': // 赤 → ハイライト
        return const LinearGradient(
          colors: [Color(0xFFFF6464), Color(0xFFFF8A8A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'hard': // オレンジ
        return const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFFC47E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'good': // グリーン
        return const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF9EE29F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'easy': // ブルー
        return const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF89C6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'unanswered': // グレー
      default:
        return const LinearGradient(
          colors: [Color(0xFFBDBDBD), Color(0xFFE0E0E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 回答済み合計を計算
    final int answeredSum =
        (memoryValues['again'] ?? 0) +
            (memoryValues['hard']  ?? 0) +
            (memoryValues['good']  ?? 0) +
            (memoryValues['easy']  ?? 0);

    // 未回答を計算（負にならないよう clamp）
    final int unanswered = (totalCount - answeredSum).clamp(0, totalCount);

    // 各レベルの最終的な件数マップ
    final counts = <String, int>{
      'again':      memoryValues['again'] ?? 0,
      'hard':       memoryValues['hard']  ?? 0,
      'good':       memoryValues['good']  ?? 0,
      'easy':       memoryValues['easy']  ?? 0,
      'unanswered': unanswered,
    };

    // 全て未回答（answeredSum == 0）のときはグレー1本
    if (answeredSum == 0) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          height: height,
          decoration: BoxDecoration(gradient: _gradient('unanswered')),
        ),
      );
    }

    // 部分描画
    return ClipRRect(
      borderRadius: borderRadius,
      child: Row(
        children: counts.entries.map((entry) {
          final level = entry.key;
          final flex  = entry.value;
          if (flex <= 0) return const SizedBox.shrink();
          return Expanded(
            flex: flex,
            child: Container(
              height: height,
              decoration: BoxDecoration(gradient: _gradient(level)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
