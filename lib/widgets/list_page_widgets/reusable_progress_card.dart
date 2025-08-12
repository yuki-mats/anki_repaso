import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/common_widgets/question_rate_display.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'memory_level_progress_bar.dart';

/// 汎用カード：フォルダ・暗記セット・問題集を共通レイアウトで表示
class ReusableProgressCard extends StatelessWidget {
  const ReusableProgressCard({
    super.key,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.memoryLevels,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.count,
    required this.countSuffix,
    required this.onTap,
    required this.onMorePressed,
    required this.selectionMode,
    required this.cardId,
    required this.hasPermission,
    this.selectedId,
    this.onSelected,
    this.iconBoxSize,
    this.iconSize,
  });

  /* ───────── props ───────── */
  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Map<String, int> memoryLevels;
  final int correctAnswers;
  final int totalAnswers;
  final int count;
  final String countSuffix;
  final VoidCallback onTap;
  final VoidCallback onMorePressed;

  // チェックボックス選択用
  final bool selectionMode;
  final String cardId;
  final String? selectedId;
  final ValueChanged<String?>? onSelected;

  final bool hasPermission;

  final double? iconBoxSize;
  final double? iconSize;

  static const double _actionAreaSize = 40; // チェック / more 領域

  @override
  Widget build(BuildContext context) {
    final bool isChecked = selectedId == cardId;

    final borderColor = isChecked ? Colors.blue[800]! : AppColors.gray100;

    final Color effectiveIconColor = hasPermission ? iconColor : Colors.white;
    final Color effectiveIconBgColor = hasPermission ? iconBgColor : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /* ───── タイトル行 ───── */
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RoundedIconBox(
                      icon: iconData,
                      iconColor: effectiveIconColor,
                      backgroundColor: effectiveIconBgColor,
                      size: iconBoxSize ?? 28.0,
                      iconSize: iconSize ?? 16.0,
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
                    /* ───── 右側アクション ───── */
                    SizedBox(
                      width: _actionAreaSize,
                      height: _actionAreaSize,
                      child: selectionMode
                          ? const SizedBox.shrink() // ★ 複数選択時は非表示
                          : IconButton(
                        icon: const Icon(Icons.more_horiz_outlined,
                            color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: onMorePressed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                /* ───── 正答率・件数 ───── */
                QuestionRateDisplay(
                  top: correctAnswers,
                  bottom: totalAnswers,
                  memoryLevels: memoryLevels,
                  count: count,
                  countSuffix: countSuffix,
                ),
                const SizedBox(height: 4),
                /* ───── メモリーバー ───── */
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
