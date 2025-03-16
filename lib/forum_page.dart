import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repaso/widgets/memo_page_widgets/memo_list_item.dart';
import 'reply_list_page.dart';
import 'utils/app_colors.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({Key? key}) : super(key: key);

  @override
  _AllMemoListPageState createState() => _AllMemoListPageState();
}

class _AllMemoListPageState extends State<ForumPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  /// Firestore から全メモ（isDeleted が false のもの）を取得するストリーム
  Stream<QuerySnapshot> _getMemoStream() {
    return FirebaseFirestore.instance
        .collection('memos')
        .where('isDeleted', isEqualTo: false)
        .snapshots();
  }

  /// リフレッシュ時の処理（ここでは setState で再描画するだけ）
  Future<void> _refreshMemos() async {
    setState(() {});
    // 例として 1 秒待機する
    await Future.delayed(Duration(seconds: 1));
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
        title: const Text('コミュニティ'),
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.gray100, height: 1.0),
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getMemoStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('エラーが発生しました'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final memos = snapshot.data?.docs ?? [];
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
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};
              final aTimestamp = aData['createdAt'] as Timestamp? ?? Timestamp(0, 0);
              final bTimestamp = bData['createdAt'] as Timestamp? ?? Timestamp(0, 0);
              return bTimestamp.compareTo(aTimestamp);
            });
            return RefreshIndicator(
              color: Colors.blue,
              backgroundColor: Colors.white,
              onRefresh: _refreshMemos,
              child: ListView.builder(
                itemCount: memos.length,
                itemBuilder: (context, index) {
                  final memoDoc = memos[index];
                  return MemoListItem(
                    memoDoc: memoDoc,
                    onTapReply: (ctx, memoId, memoData) {
                      _showReplyPage(ctx, memoId, memoData);
                    },
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