import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'list_page_widgets/skeleton_card.dart';

/// フォルダヘッダー用スケルトン
class FolderHeaderSkeleton extends StatelessWidget {
  const FolderHeaderSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 共通シャマーラッパー
    Widget shimmer(Widget child) => Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: child,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // フォルダアイコン枠スケルトン
          shimmer(Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
          )),
          const SizedBox(width: 8),
          // フォルダ名テキストスケルトン
          Expanded(
            child: shimmer(Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
          const SizedBox(width: 8),
          // 選択チェックボックス枠スケルトン
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
    );
  }
}

/// 子アイテム（問題集）用スケルトン
class QuestionSetSkeleton extends StatelessWidget {
  const QuestionSetSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 親の horizontal=16 + 子の indent=16 で計32px
    return const SkeletonCard();
  }
}

/// スケルトンカードウィジェット（StudySet 選択用）
/// フォルダとその配下の問題集リストを示すスケルトン
class StudySetSkeletonCard extends StatelessWidget {
  const StudySetSkeletonCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        // フォルダヘッダー
        FolderHeaderSkeleton(),
        FolderHeaderSkeleton(),
        QuestionSetSkeleton(),
        QuestionSetSkeleton(),
        QuestionSetSkeleton(),
        FolderHeaderSkeleton(),
        QuestionSetSkeleton(),
        QuestionSetSkeleton(),
        FolderHeaderSkeleton(),
        QuestionSetSkeleton(),
      ],
    );
  }
}
