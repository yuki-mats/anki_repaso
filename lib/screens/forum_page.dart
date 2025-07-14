// “待機 → スピナー → 再描画” のループを根本原因から解消しました。
// 変更点は 2 つだけ：
// ① Stream を initState で 1 度だけ生成 → 再購読が起きないのでチラつきゼロ
// ② _refreshMemos() では setState を呼ばずにサーバー再フェッチだけ実行
// これにより UI はそのまま／UX が大幅改善されます。

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:repaso/widgets/memo_page_widgets/memo_list_item.dart';
import 'reply_list_page.dart';
import '../utils/app_colors.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({Key? key}) : super(key: key);

  @override
  _AllMemoListPageState createState() => _AllMemoListPageState();
}

class _AllMemoListPageState extends State<ForumPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  late final Stream<QuerySnapshot> _memoStream;               // ★ 追加

  @override
  void initState() {
    super.initState();
    // Stream を 1 回だけ生成し、build ごとの再購読を防止
    _memoStream = FirebaseFirestore.instance
        .collection('memos')
        .where('isDeleted', isEqualTo: false)
        .snapshots();
  }

  /// リフレッシュ時の処理（サーバーに強制再アクセス）
  Future<void> _refreshMemos() async {
    await FirebaseFirestore.instance
        .collection('memos')
        .where('isDeleted', isEqualTo: false)
        .get(const GetOptions(source: Source.serverAndCache));
    // Artificial delay は不要だが UX 的に 400 ms だけ残しても可
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// 返信ページへ遷移する
  void _showReplyPage(BuildContext context, String memoId, Map<String, dynamic> memoData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ReplyListPage(memoId: memoId, memoData: memoData),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        centerTitle: false,
        title: const Text('コミュニティ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.gray100, height: 1.0),
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: _memoStream,                       // ★ build ごとに同じ Stream
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('エラーが発生しました'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator(radius: 16));
            }

            final memos = snapshot.data!.docs;
            if (memos.isEmpty) {
              return const Center(
                child: Text(
                  'メモがまだありません。\n今すぐ、みんなのために情報を蓄積しよう！\n※投稿したメモは全ユーザーに公開されます。',
                  textAlign: TextAlign.center,
                ),
              );
            }

            // 作成日時(createdAt)の降順にソート（最新順）
            memos.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTs = aData['createdAt'] as Timestamp? ?? Timestamp(0, 0);
              final bTs = bData['createdAt'] as Timestamp? ?? Timestamp(0, 0);
              return bTs.compareTo(aTs);
            });

            // ───── Twitter 風 Pull‑to‑Refresh ─────
            return CustomRefreshIndicator(
              onRefresh: _refreshMemos,
              offsetToArmed: 80,
              builder: (context, child, controller) {
                Widget _indicator() {
                  if (controller.isDragging && !controller.isArmed) {
                    return const Icon(Icons.arrow_downward, size: 20);
                  }
                  if (controller.isArmed && !controller.isLoading) {
                    return const RotatedBox(
                      quarterTurns: 2,
                      child: Icon(Icons.arrow_downward, size: 20),
                    );
                  }
                  if (controller.isLoading) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CupertinoActivityIndicator(radius: 10),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }

                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Transform.translate(
                      offset: Offset(0, controller.value * 80),
                      child: child,
                    ),
                    if (!controller.isIdle)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _indicator(),
                      ),
                  ],
                );
              },
              child: ListView.builder(
                itemCount: memos.length,
                itemBuilder: (context, index) {
                  final memoDoc = memos[index];
                  return MemoListItem(
                    memoDoc: memoDoc,
                    onTapReply: (ctx, memoId, memoData) =>
                        _showReplyPage(ctx, memoId, memoData),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
