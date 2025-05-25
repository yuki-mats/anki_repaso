import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';          // ← 追加
import '../../utils/app_colors.dart';

/// スケルトンカードウィジェット
/// ReusableProgressCard のレイアウトに合わせたスケルトン
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 共通シャマーラッパー
    Widget shimmer(Widget child) => Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[200]!,
      period: const Duration(milliseconds: 1000),
      child: child,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── タイトル行スケルトン ─────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // アイコン枠
                  shimmer(Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                  const SizedBox(width: 10),
                  // タイトルテキストスケルトン
                  Expanded(
                    child: shimmer(Container(
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(width: 10),
                  // メニューアイコンスケルトン
                  shimmer(Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              // ───── 正答率・件数スケルトン (右寄せ) ─────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  shimmer(Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                  const SizedBox(width: 8),
                  shimmer(Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              // ───── メモリーレベルバースケルトン ─────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: List.generate(
                    5,
                        (_) => Expanded(
                      child: shimmer(Container(
                        height: 8,
                        color: Colors.grey[300],
                      )),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
