// lib/widgets/study_set_selectable_card.dart
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/common_widgets/question_rate_display.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'list_page_widgets/memory_level_progress_bar.dart';

/// StudySet 用：選択可能な進捗カード（外側に左チェックを置く想定）
/// 右端のチェックは置かず、選択時は枠色で強調します。
class StudySetSelectableCard extends StatelessWidget {
  const StudySetSelectableCard({
    Key? key,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.isVerified,
    required this.memoryLevels,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.count,
    required this.countSuffix,
    required this.onTap,
    required this.isSelected,
    required this.onSelectionChanged, // 互換のために残す（内部では使わない）
    this.iconBoxSize,
    this.iconSize,
  }) : super(key: key);

  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final bool isVerified;
  final Map<String, int> memoryLevels;
  final int correctAnswers;
  final int totalAnswers;
  final int count;
  final String countSuffix;
  final VoidCallback onTap;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  final double? iconBoxSize;
  final double? iconSize;

  static const double _outerHPadding = 16;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.gray100;

    return Padding(
      // 他ページのカードと統一：左右16 / 縦4
      padding: const EdgeInsets.symmetric(horizontal: _outerHPadding, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // ReusableProgressCard に合わせた内側余白
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───── タイトル行 ─────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        RoundedIconBox(
                          icon: iconData,
                          iconColor: iconColor,
                          backgroundColor: iconBgColor,
                          size: iconBoxSize ?? 28.0,
                          iconSize: iconSize ?? 16.0,
                        ),
                        if (isVerified)
                          const Positioned(
                            bottom: 1,
                            right: 0,
                            child: Icon(Icons.verified, size: 12, color: Colors.blueAccent),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    // 右端のアクションは置かない（左外側にチェックを配置する前提）
                  ],
                ),
                const SizedBox(height: 12),
                // ───── 正答率・件数 ─────
                QuestionRateDisplay(
                  top: correctAnswers,
                  bottom: totalAnswers,
                  memoryLevels: memoryLevels,
                  count: count,
                  countSuffix: countSuffix,
                ),
                const SizedBox(height: 4),
                // ───── メモリーバー ─────
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: MemoryLevelProgressBar(
                    memoryValues: memoryLevels,
                    totalCount: count,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
