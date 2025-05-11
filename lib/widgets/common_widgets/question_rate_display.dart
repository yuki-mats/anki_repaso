import 'package:flutter/material.dart';

/// 正答率と数値（問題数や試行回数など）を表示する共通ウィジェット
class QuestionRateDisplay extends StatelessWidget {
  /// 問題数または試行回数（正答率の分母）
  final int top;
  /// 正答数（正答率の分子）
  final int bottom;
  /// 正答率の隣に表示する任意の数字
  final int count;
  /// メモリーレベルのカウント（例: {'again': 3, 'hard': 2, 'good': 5, 'easy': 0}）
  final Map<String, dynamic> memoryLevels;
  /// 数値表示のサフィックス（例: " 問" または " 回"）【bottom用】
  final String bottomSuffix;
  /// countの単位（例: " 問" または " 回"）
  final String countSuffix;

  const QuestionRateDisplay({
    Key? key,
    required this.top,     // 問題数や試行回数（正答率の分母）
    required this.bottom,  // 正答数（正答率の分子）
    required this.count,
    required this.memoryLevels,
    this.bottomSuffix = ' 問', // bottomのデフォルトは「問」
    this.countSuffix = '',     // countのデフォルトは空文字列
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // bottom > 0の場合、(正答数(top) / 総問題数(bottom)) * 100
    double correctRate = bottom > 0 ? ((top / bottom) * 100) : 0;
    String correctRateStr = correctRate.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 正答率表示
          Container(
            width: 90,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '正答率',
                    style: TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                  const TextSpan(
                    text: ' : ',
                    style: TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                  TextSpan(
                    text: correctRateStr,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const TextSpan(
                    text: ' %',
                    style: TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          // countの表示（正答率の隣に表示）
          Container(
            width: 50,
            alignment: Alignment.centerRight,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$count',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  TextSpan(
                    text: countSuffix,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
