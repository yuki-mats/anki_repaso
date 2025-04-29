import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repaso/screens/memo_add_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/memo_page_widgets/memo_list_item.dart';
import 'reply_list_page.dart';

class MemoListPage extends StatefulWidget {
  final String questionId;
  final String questionSetId;

  const MemoListPage({
    Key? key,
    required this.questionId,
    required this.questionSetId,
  }) : super(key: key);

  @override
  _MemoListPageState createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  bool filterByQuestionSet = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();


  /// メモ追加ページを下からスライド表示
  void _showAddMemoPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true, // 下からスライドするページ遷移
        builder: (context) => MemoAddPage(
          questionId: widget.questionId,
          questionSetId: widget.questionSetId,
        ),
      ),
    );
  }



  /// Firestoreからメモを取得するストリーム
  Stream<QuerySnapshot> _getMemoStream() {
    final memosCollection = FirebaseFirestore.instance.collection('memos');

    if (filterByQuestionSet) {
      return memosCollection
          .where('questionSetId', isEqualTo: widget.questionSetId)
          .where('isDeleted', isEqualTo: false) // 🔹 isDeleted が false のみ取得
          .snapshots();
    } else {
      return memosCollection
          .where('questionId', isEqualTo: widget.questionId)
          .where('isDeleted', isEqualTo: false) // 🔹 isDeleted が false のみ取得
          .snapshots();
    }
  }


  /// 返信ページへ遷移する（モーダルボトムシートとして表示）
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
      appBar: AppBar(
        title: Text('メモ投稿一覧'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        automaticallyImplyLeading: false,
        //左に戻るボタンを表示する。
        leading: IconButton(
          icon: const Icon(size: 22, Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // フィルターチップ
            Row(
              children: [
                ChoiceChip(
                  label: const Text("この問題"),
                  selected: !filterByQuestionSet,
                  onSelected: (selected) {
                    setState(() {
                      filterByQuestionSet = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("この問題集"),
                  selected: filterByQuestionSet,
                  onSelected: (selected) {
                    setState(() {
                      filterByQuestionSet = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            // メモ一覧部分
            Expanded(
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
                    return const Center(child: Text('メモがまだありません。\n今すぐ、みんなのために情報を蓄積しよう！\n※投稿したメモは全ユーザーに公開されます。'));
                  }
                  // 作成日時の降順にソート
                  memos.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>? ?? {};
                    final bData = b.data() as Map<String, dynamic>? ?? {};
                    final aTimestamp = aData['createdAt'] as Timestamp? ?? Timestamp(0, 0);
                    final bTimestamp = bData['createdAt'] as Timestamp? ?? Timestamp(0, 0);
                    return bTimestamp.compareTo(aTimestamp);
                  });
                  return ListView.builder(
                    itemCount: memos.length,
                    itemBuilder: (context, index) {
                      final doc = memos[index];
                      final memoItem = MemoListItem(
                        memoDoc: doc,
                        onTapReply: (ctx, memoId, memoData) {
                          _showReplyPage(ctx, memoId, memoData);
                        },
                      );
                      if (index == memos.length - 1) {
                        return Column(
                          children: [
                            memoItem,
                            const SizedBox(height: 120.0),
                          ],
                        );
                      } else {
                        return memoItem;
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemoPage,
        child: const Icon(Icons.add, color: Colors.white),
        shape: const CircleBorder(),
        backgroundColor: AppColors.blue500,
      ),
    );
  }
}
