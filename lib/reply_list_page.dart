import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/memo_page_widgets/memo_like_button.dart';
import 'package:repaso/widgets/memo_page_widgets/question_toggle_section.dart';
import 'package:repaso/widgets/memo_page_widgets/reply_like_button.dart';

/// 返信ページ（モーダルボトムシートで表示）
class ReplyListPage extends StatefulWidget {
  final String memoId;
  final Map<String, dynamic> memoData; // メモの概要情報（タイトル、本文、その他必要な情報）

  const ReplyListPage({
    Key? key,
    required this.memoId,
    required this.memoData,
  }) : super(key: key);

  @override
  _ReplyPageState createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyListPage> {
  final TextEditingController _replyController = TextEditingController();

  /// 返信送信処理
  Future<void> _sendReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final replyData = {
      'content': replyText,
      'createdById': user.uid,
      'isDeleted': false,
      'likeCount': 0,
      'reportCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final memoRef =
      FirebaseFirestore.instance.collection('memos').doc(widget.memoId);
      // トランザクション内で返信の追加と replyCount の更新を同時に実施
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 自動生成されたドキュメントIDで新規返信ドキュメントの参照を取得
        final newReplyRef = memoRef.collection('replies').doc();
        // 返信の追加
        transaction.set(newReplyRef, replyData);
        // replyCount をインクリメント
        transaction.update(memoRef, {'replyCount': FieldValue.increment(1)});
      });
      _replyController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('返信の送信に失敗しました')),
      );
    }
  }

  /// Firestoreから`isDeleted == false` の返信を取得
  Stream<QuerySnapshot> _getRepliesStream() {
    return FirebaseFirestore.instance
        .collection('memos')
        .doc(widget.memoId)
        .collection('replies')
        .orderBy('isDeleted') // クエリを安定させるため追加
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  /// ユーザー情報をFirestoreから取得
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() as Map<String, dynamic>?;
  }

  // memoType を日本語表記に変換
  String _getMemoTypeLabel(String? memoType) {
    switch (memoType) {
      case 'notice':
        return '気づき';
      case 'explanation':
        return '解説';
      case 'knowledge':
        return '知識・用語';
      case 'question':
        return '疑問';
      default:
        return memoType ?? '';
    }
  }

  /// ヘッダー部分：メモの概要＋トグルボタン・問題セクションを構築
  Widget _buildHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserData(widget.memoData['createdById'] ?? ''),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};
        final profileImageUrl = userData['profileImageUrl'] as String?;
        final userName = userData['name'] ?? 'ユーザー';
        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ユーザー情報：プロフィール画像、ユーザー名、投稿日時
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                        child: profileImageUrl == null ? const Icon(Icons.person, size: 18) : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm').format(
                              (widget.memoData['createdAt'] is Timestamp)
                                  ? (widget.memoData['createdAt'] as Timestamp).toDate()
                                  : DateTime.now(),
                            ),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              QuestionToggleSection(questionId: widget.memoData['questionId'] as String),
              const SizedBox(height: 12),
              // メモのタイトルと本文
              if ((widget.memoData['title'] ?? '').toString().isNotEmpty)
                Text(
                  widget.memoData['title'],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              if ((widget.memoData['title'] ?? '').toString().isNotEmpty)
                const SizedBox(height: 4),
              Text(
                widget.memoData['content'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
              // メモの種別、いいね数、返信数、いいねボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.memoData['memoType'] != null &&
                          (widget.memoData['memoType'] as String).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(top: 8, bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Text(
                            _getMemoTypeLabel(widget.memoData['memoType'] as String?),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.memoData['likeCount'] ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              // 返信件数は下部リストでカウントしているため、ここは省略可
                              Text(
                                '${widget.memoData['replyCount'] ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: MemoLikeButton(
                      memoId: widget.memoId,
                      createdById: widget.memoData['createdById'] ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('返信'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        automaticallyImplyLeading: false,
        // 左に戻るボタン
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _getRepliesStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint("Firestore エラー: ${snapshot.error}");
              return const Center(child: Text('データを取得できませんでした'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final replies = snapshot.data?.docs ?? [];
            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: replies.length + 1, // ヘッダー1件＋返信件数
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader();
                } else {
                  final replyDoc = replies[index - 1];
                  return ReplyItem(replyDoc: replyDoc);
                }
              },
            );
          },
        ),
      ),
      // 返信入力フィールド（下部固定）
      bottomNavigationBar: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: TextField(
                      autofocus: false,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      cursorColor: Colors.blue,
                      style: const TextStyle(fontSize: 14),
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: 'コメントを入力',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_circle_up_rounded, size: 36, color: Colors.blue),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ReplyItem：各返信を表示するウィジェット
class ReplyItem extends StatelessWidget {
  final DocumentSnapshot replyDoc;

  const ReplyItem({Key? key, required this.replyDoc}) : super(key: key);

  /// 返信投稿者データを取得
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() as Map<String, dynamic>?;
  }

  void _showReplyMenu(BuildContext context, String replyId, String createdById) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool isOwnReply = user.uid == createdById;

    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwnReply) ...[
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.delete_outline, size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('返信を削除', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(modalContext);
                    final memoId = replyDoc.reference.parent.parent?.id ?? '';
                    final memoRef = FirebaseFirestore.instance.collection('memos').doc(memoId);
                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      // 対象の返信ドキュメント参照を取得
                      final replyRef = memoRef.collection('replies').doc(replyDoc.id);
                      // 返信を削除（ソフトデリート）
                      transaction.update(replyRef, {'isDeleted': true});
                      // メモの replyCount を1減算
                      transaction.update(memoRef, {'replyCount': FieldValue.increment(-1)});
                    });
                  },
                ),
              ] else ...[
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.flag_outlined, size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('返信を通報', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(modalContext);
                    // 通報処理を追加
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final replyData = replyDoc.data() as Map<String, dynamic>? ?? {};
    final content = replyData['content'] ?? '';
    final createdAtTimestamp = replyData['createdAt'] as Timestamp?;
    final createdAt = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();
    final createdById = replyData['createdById'] ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserData(createdById),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};
        final profileImageUrl = userData['profileImageUrl'] as String?;
        final userName = userData['name'] ?? 'ユーザー';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                  child: profileImageUrl == null ? const Icon(Icons.person, size: 18) : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              _formatTime(createdAt),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                          onPressed: () {
                            _showReplyMenu(context, replyDoc.id, createdById);
                          },
                        ),
                      ],
                    ),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${replyData['likeCount'] ?? 0}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: ReplyLikeButton(
                            memoId: replyDoc.reference.parent.parent?.id ?? '',
                            replyId: replyDoc.id,
                            createdById: createdById,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
