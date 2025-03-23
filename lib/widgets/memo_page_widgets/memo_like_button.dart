import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemoLikeButton extends StatefulWidget {
  final String memoId;      // 対象のメモのID
  final String createdById; // メモ投稿者のID（いいねを受ける側）

  const MemoLikeButton({
    Key? key,
    required this.memoId,
    required this.createdById,
  }) : super(key: key);

  @override
  _MemoLikeButtonState createState() => _MemoLikeButtonState();
}

class _MemoLikeButtonState extends State<MemoLikeButton> {
  bool _isProcessing = false; // 追加：処理中かどうかのフラグ

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox(); // ログインしていない場合は空のウィジェットを返す

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('memos')
          .doc(widget.memoId)
          .collection('likes')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        bool isLiked = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isLiked = snapshot.data!.get('isActive') ?? false;
        }

        return GestureDetector(
          onTap: () {
            // すでにいいね済みまたは処理中の場合は何もしない
            if (!_isProcessing && !isLiked) {
              _handleLike(user.uid, isLiked);
            }
          },
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
    if (isLiked || _isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final firestore = FirebaseFirestore.instance;
    final memoLikesRef = firestore
        .collection('memos')
        .doc(widget.memoId)
        .collection('likes')
        .doc(userId);

    final userLikesReceivedRef = firestore
        .collection('users')
        .doc(widget.createdById)
        .collection('likesReceived')
        .doc(); // 自動生成IDで追加

    final userRef = firestore.collection('users').doc(widget.createdById);

    try {
      await firestore.runTransaction((transaction) async {
        // メモのいいね登録
        transaction.set(memoLikesRef, {
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
          'memoId': widget.memoId,
          'replyId': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        // count() 集約クエリを使用して likesReceived の総数を取得
        final likesReceivedCountQuery = await firestore
            .collection('users')
            .doc(widget.createdById)
            .collection('likesReceived')
            .count()
            .get();
        final likesReceivedCount = likesReceivedCountQuery.count;

        // ユーザー情報を更新
        transaction.update(userRef, {
          'totalLikesReceived': likesReceivedCount,
          'availableLikes': likesReceivedCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // メモの likeCount を +1 更新
        transaction.update(firestore.collection('memos').doc(widget.memoId), {
          'likeCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      // エラーハンドリング
      print("Error in transaction: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}
