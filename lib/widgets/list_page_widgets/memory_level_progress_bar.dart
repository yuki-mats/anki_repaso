import 'package:flutter/material.dart';

class MemoryLevelProgressBar extends StatelessWidget {
  final Map<String, int> memoryValues; // 各メモリレベルの数値（例：{'again': 3, 'hard': 2, ...}）
  final double height;
  final BorderRadiusGeometry borderRadius;
  final List<String> order; // 左から右への表示順（デフォルトでは 'again', 'hard', 'good', 'easy', 'unanswered'）

  const MemoryLevelProgressBar({
    Key? key,
    required this.memoryValues,
    this.height = 8.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(2.0)),
    this.order = const ['again', 'hard', 'good', 'easy', 'unanswered'],
  }) : super(key: key);

  // メモリーレベルに応じた色を返す関数
  Color _getMemoryLevelColor(String level) {
    switch (level) {
      case 'unanswered':
        return Colors.grey[300]!;  // 未回答（グレー）
      case 'again':
        return Colors.red[300]!;   // 間違えた問題（赤）
      case 'hard':
        return Colors.orange[300]!; // 難しい問題（オレンジ）
      case 'good':
        return Colors.green[300]!;  // 良好（緑）
      case 'easy':
        return Colors.blue[300]!;   // 簡単（青）
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAllZero = order.every((level) => (memoryValues[level] ?? 0) == 0);

    if (isAllZero) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          height: height,
          color: _getMemoryLevelColor('unanswered'),
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
              color: _getMemoryLevelColor(level),
            ),
          );
        }).toList(),
      ),
    );
  }
}
