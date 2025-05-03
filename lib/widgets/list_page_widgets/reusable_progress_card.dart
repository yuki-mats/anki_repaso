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
  });

  // ------- 外から渡すプロパティ -------
  final IconData      iconData;
  final Color         iconColor;
  final Color         iconBgColor;
  final String        title;
  final bool          isVerified;
  final Map<String,int> memoryLevels;
  final int           correctAnswers;
  final int           totalAnswers;
  final int           count;
  final String        countSuffix;
  final VoidCallback  onTap;
  final VoidCallback  onMorePressed;

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    SizedBox(
                      width : 40,
                      height: 40,
                      child : IconButton(
                        icon            : const Icon(Icons.more_horiz_outlined,
                            color: Colors.grey),
                        padding         : EdgeInsets.zero,
                        constraints     : const BoxConstraints(),
                        visualDensity   : VisualDensity.compact,
                        onPressed       : onMorePressed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                  child  : MemoryLevelProgressBar(memoryValues: memoryLevels, totalCount: count,),
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
