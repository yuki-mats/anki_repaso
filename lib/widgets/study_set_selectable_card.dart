import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/common_widgets/question_rate_display.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'list_page_widgets/memory_level_progress_bar.dart';

/// StudySet 用：選択可能な進捗カード
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
    required this.onSelectionChanged,
  }) : super(key: key);

  // ───── 外部から渡すプロパティ ─────
  final IconData          iconData;
  final Color             iconColor;
  final Color             iconBgColor;
  final String            title;
  final bool              isVerified;
  final Map<String,int>   memoryLevels;
  final int               correctAnswers;
  final int               totalAnswers;
  final int               count;
  final String            countSuffix;
  final VoidCallback      onTap;
  final bool              isSelected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
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
                          icon            : iconData,
                          iconColor       : iconColor,
                          backgroundColor : iconBgColor,
                        ),
                        if (isVerified)
                          const Positioned(
                            bottom: 1,
                            right : 0,
                            child : Icon(Icons.verified,
                                size: 12, color: Colors.blueAccent),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize : 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    // ─── フォルダ用と同じサイズのチェックボックス ───
                    Container(
                      width: 20,
                      height: 20,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 20,
                        onPressed: () => onSelectionChanged(!isSelected),
                        icon: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isSelected
                              ? AppColors.blue500
                              : AppColors.gray600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ───── 正答率・件数表示 ─────
                QuestionRateDisplay(
                  top          : correctAnswers,
                  bottom       : totalAnswers,
                  memoryLevels : memoryLevels,
                  count        : count,
                  countSuffix  : countSuffix,
                ),
                const SizedBox(height: 4),
                // ───── メモリーレベルバー ─────
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: MemoryLevelProgressBar(
                    memoryValues: memoryLevels,
                    totalCount:   count,
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
