import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────
/// StreakBadge  ─ 連続学習日数を表示するバッジ
/// ─────────────────────────────────────────────
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final bool isZero  = count == 0;
    final Color bgCol  = isZero ? Colors.grey.shade400 : Colors.deepOrange;
    final Color txtCol = Colors.white; // どちらの背景でも読みやすい白文字

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Icon(Icons.local_fire_department, color: txtCol, size: 16),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(color: txtCol, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
