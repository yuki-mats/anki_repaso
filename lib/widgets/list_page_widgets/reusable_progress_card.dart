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
    required this.isVerified,
    required this.memoryLevels,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.count,
    required this.countSuffix,
    required this.onTap,
    required this.onMorePressed,
    required this.selectionMode,    // 追加
    required this.cardId,           // 追加
    this.selectedId,                // 追加
    this.onSelected,                // 追加
  });

  // ------- 外から渡すプロパティ -------
  final IconData           iconData;
  final Color              iconColor;
  final Color              iconBgColor;
  final String             title;
  final bool               isVerified;
  final Map<String, int>   memoryLevels;
  final int                correctAnswers;
  final int                totalAnswers;
  final int                count;
  final String             countSuffix;
  final VoidCallback       onTap;
  final VoidCallback       onMorePressed;

  // 追加: ラジオ選択用プロパティ
  final bool               selectionMode;
  final String             cardId;
  final String?            selectedId;
  final ValueChanged<String?>? onSelected;

  @override
  Widget build(BuildContext context) {
    // ★ デバッグ出力
    print('[ReusableProgressCard] build  '
        'cardId=$cardId  selectionMode=$selectionMode  selectedId=$selectedId');

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
                    // ───── ここをラジオ or アイコンボタンに切り替え ─────
                    if (selectionMode)
                      Radio<String>(
                        value       : cardId,
                        groupValue  : selectedId,
                        activeColor : AppColors.blue500,
                        onChanged   : (val) {
                          // ★ デバッグ出力
                          print('[ReusableProgressCard] Radio onChanged → $val');
                          if (onSelected != null) onSelected!(val);
                        },
                      )
                    else
                      SizedBox(
                        width : 40,
                        height: 40,
                        child : IconButton(
                          icon            : const Icon(
                            Icons.more_horiz_outlined,
                            color: Colors.grey,
                          ),
                          padding       : EdgeInsets.zero,
                          constraints   : const BoxConstraints(),
                          visualDensity : VisualDensity.compact,
                          onPressed     : onMorePressed,
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
                  child  : MemoryLevelProgressBar(
                    memoryValues: memoryLevels,
                    totalCount  : count,
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
