import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReplyLikeButton extends StatefulWidget {
  final String memoId;       // 親メモのID（返信の場合、memoIdは存在するが空で管理する）
  final String replyId;      // 対象返信のID
  final String createdById;  // 返信投稿者のID（いいねを受ける側）

  const ReplyLikeButton({
    Key? key,
    required this.memoId,
    required this.replyId,
    required this.createdById,
  }) : super(key: key);

  @override
  _ReplyLikeButtonState createState() => _ReplyLikeButtonState();
}

class _ReplyLikeButtonState extends State<ReplyLikeButton> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox(); // ログインしていない場合は空のウィジェットを返す

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('memos')
          .doc(widget.memoId)
          .collection('replies')
          .doc(widget.replyId)
          .collection('likes')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        bool isLiked = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isLiked = snapshot.data!.get('isActive') ?? false;
        }

        return GestureDetector(
          onTap: () => _handleLike(user.uid, isLiked),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.shade100),
              color: isLiked ? Colors.red.shade100 : Colors.white,
            ),
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.pink.shade300 : Colors.red.shade200,
              size: 16,
            ),
          ),
        );
      },
    );
  }

  /// いいね処理：一度いいねしたら取り消せない仕様
  Future<void> _handleLike(String userId, bool isLiked) async {
    if (isLiked) return; // すでにいいね済みなら何もしない

    final firestore = FirebaseFirestore.instance;
    final replyLikesRef = firestore
        .collection('memos')
        .doc(widget.memoId)
        .collection('replies')
        .doc(widget.replyId)
        .collection('likes')
        .doc(userId);

    final userLikesReceivedRef = firestore
        .collection('users')
        .doc(widget.createdById)
        .collection('likesReceived')
        .doc(); // 🔹 `auto-generate ID` で追加

    final userRef = firestore.collection('users').doc(widget.createdById);

    await firestore.runTransaction((transaction) async {
      // 返信のいいね登録
      transaction.set(replyLikesRef, {
        'fromUserId': userId,
        'toUserId': widget.createdById,
        'isActive': true,
        'hasRewarded': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ユーザーの受け取ったいいねに登録
      transaction.set(userLikesReceivedRef, {
        'fromUserId': userId,
        'memoId': '', // 🔹 返信へのいいねなので memoId は空にする
        'replyId': widget.replyId,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // 🔹 Firestore の `count()` を使用して `/likesReceived` の総数を取得
      final likesReceivedCountQuery = await firestore
          .collection('users')
          .doc(widget.createdById)
          .collection('likesReceived')
          .count()
          .get();

      final likesReceivedCount = likesReceivedCountQuery.count; // 🔹 `.count` で取得

      // `totalLikesReceived` と `availableLikes` を更新
      transaction.update(userRef, {
        'totalLikesReceived': likesReceivedCount, // 🔹 総数と一致させる
        'availableLikes': likesReceivedCount, // 🔹 `availableLikes` も `likesReceived` の数と一致させる
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 返信の `likeCount` を +1 更新
      transaction.update(
        firestore.collection('memos').doc(widget.memoId).collection('replies').doc(widget.replyId),
        {'likeCount': FieldValue.increment(1)},
      );
    });
  }
}
