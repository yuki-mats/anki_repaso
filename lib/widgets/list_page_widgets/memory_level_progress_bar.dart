import 'package:flutter/material.dart';

class MemoryLevelProgressBar extends StatelessWidget {
  final Map<String, int> memoryValues;                // {'again': 3, 'hard': 2, ...}
  final double height;
  final BorderRadiusGeometry borderRadius;
  final List<String> order;

  const MemoryLevelProgressBar({
    Key? key,
    required this.memoryValues,
    this.height = 8.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    this.order = const ['again', 'hard', 'good', 'easy', 'unanswered'],
  }) : super(key: key);

  // ── レベルに応じたグラデーション ────────────────────
  LinearGradient _gradient(String level) {
    switch (level) {
      case 'again':       // 赤 → ハイライト
        return const LinearGradient(
          colors: [Color(0xFFFF6464), Color(0xFFFF8A8A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'hard':        // オレンジ
        return const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFFC47E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'good':        // グリーン
        return const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF9EE29F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'easy':        // ブルー
        return const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF89C6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'unanswered':  // グレー
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
    final isAllZero = order.every((level) => (memoryValues[level] ?? 0) == 0);

    // 全て 0 のときはグレー 1 本
    if (isAllZero) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          height: height,
          decoration: BoxDecoration(gradient: _gradient('unanswered')),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Row(
        children: order.map((level) {
          final flexValue = memoryValues[level] ?? 0;
          if (flexValue <= 0) return const SizedBox.shrink();
          return Expanded(
            flex: flexValue,
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
