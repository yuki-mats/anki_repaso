import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:repaso/reply_list_page.dart';
import 'package:repaso/widgets/memo_edit_page.dart';
import '../../utils/app_colors.dart';
import 'memo_like_button.dart';

/// 共通ウィジェット：1件のメモを表示する
class MemoListItem extends StatelessWidget {
  final DocumentSnapshot memoDoc;
  // タップ時の挙動を外部から渡す（省略可能）
  final void Function(BuildContext context, String memoId, Map<String, dynamic> memoData)? onTapReply;

  const MemoListItem({
    Key? key,
    required this.memoDoc,
    this.onTapReply,
  }) : super(key: key);

  // Firestoreから投稿者データを取得
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() as Map<String, dynamic>?;
  }

  // memoTypeを日本語表記に変換
  String _getMemoTypeLabel(String memoType) {
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
        return memoType;
    }
  }

  // ヘルパー関数：memoTypeに応じた背景色を返す（※現在はチップ全体のスタイルに統一しているため直接利用していません）
  Color _getMemoTypeColor(String memoType) {
    switch (memoType) {
      case 'notice':
        return Colors.lightBlue.shade100;
      case 'explanation':
        return Colors.green.shade100;
      case 'knowledge':
        return Colors.orange.shade100;
      case 'question':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  // ヘルパー関数：memoTypeに応じたテキスト色を返す（※現在はチップ全体のスタイルに統一しているため直接利用していません）
  Color _getMemoTypeTextColor(String memoType) {
    switch (memoType) {
      case 'notice':
        return Colors.lightBlue.shade800;
      case 'explanation':
        return Colors.green.shade800;
      case 'knowledge':
        return Colors.orange.shade800;
      case 'question':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade600;
    }
  }

  // 投稿日時を"yyyy.MM.dd HH:mm"形式に変換
  String _formatTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm').format(dateTime);
  }

  // メモの削除処理（ソフトデリート）
  Future<void> _deleteMemo(BuildContext context, String memoId) async {
    try {
      await FirebaseFirestore.instance.collection('memos').doc(memoId).update({
        'isDeleted': true, // ソフトデリートフラグを設定
        'deletedAt': FieldValue.serverTimestamp(), // 削除日時を記録
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモを削除しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモの削除に失敗しました')),
      );
    }
  }

  // メモの通報処理（ダミー）
  void _reportMemo(BuildContext context, String memoId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('メモを通報しました')));
  }

  // メニューを表示する
  void _showMemoMenu(BuildContext context, String memoId, String createdById) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool isOwnMemo = user.uid == createdById;

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
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwnMemo) ...[
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('メモを編集', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MemoEditPage(memoId: memoId),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
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
                  title: const Text('メモを削除', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteMemo(context, memoId);
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
                  title: const Text('メモを通報', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    _reportMemo(context, memoId);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showReplyPage(BuildContext context, String memoId, Map<String, dynamic> memoData) {
    if (onTapReply != null) {
      onTapReply!(context, memoId, memoData);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReplyListPage(memoId: memoId, memoData: memoData),
        ),
      );
    }
  }

  /// memo の questionId から、該当の問題・問題集・フォルダ情報を取得し、
  /// questionSetName と licenseName を返す
  Future<Map<String, String>> _getQuestionMetaData(String questionId) async {
    final questionSnapshot = await FirebaseFirestore.instance.collection('questions').doc(questionId).get();
    final questionData = questionSnapshot.data() as Map<String, dynamic>? ?? {};
    DocumentReference? questionSetRef;
    if (questionData.containsKey('questionSetRef') && questionData['questionSetRef'] != null) {
      questionSetRef = questionData['questionSetRef'] as DocumentReference;
    } else if (questionData.containsKey('questionSetId') && questionData['questionSetId'] != null) {
      questionSetRef = FirebaseFirestore.instance.collection('questionSets').doc(questionData['questionSetId']);
    }
    if (questionSetRef == null) {
      return {'questionSetName': '', 'licenseName': ''};
    }
    final questionSetSnapshot = await questionSetRef.get();
    final questionSetData = questionSetSnapshot.data() as Map<String, dynamic>? ?? {};
    final questionSetName = questionSetData['name'] as String? ?? '';
    DocumentReference? folderRef;
    if (questionSetData.containsKey('folderRef') && questionSetData['folderRef'] != null) {
      folderRef = questionSetData['folderRef'] as DocumentReference;
    } else if (questionSetData.containsKey('folderId') && questionSetData['folderId'] != null) {
      folderRef = FirebaseFirestore.instance.collection('folders').doc(questionSetData['folderId']);
    }
    String licenseName = '';
    if (folderRef != null) {
      final folderSnapshot = await folderRef.get();
      final folderData = folderSnapshot.data() as Map<String, dynamic>? ?? {};
      licenseName = folderData['licenseName'] as String? ?? '';
    }
    return {'questionSetName': questionSetName, 'licenseName': licenseName};
  }

  @override
  Widget build(BuildContext context) {
    final memoData = memoDoc.data() as Map<String, dynamic>? ?? {};
    final createdById = memoData['createdById'] ?? '';
    final title = memoData['title'] ?? '';
    final content = memoData['content'] ?? '';
    final likeCount = memoData['likeCount'] ?? 0;
    final replyCount = memoData['replyCount'] ?? 0;
    final memoType = memoData['memoType'] as String?;
    final createdAtTimestamp = memoData['createdAt'] as Timestamp?;
    final createdAt = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();

    return InkWell(
      onTap: () => _showReplyPage(context, memoDoc.id, memoData),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey, width: 0.3),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 12.0, top: 8.0, left: 8.0, right: 8.0),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _getUserData(createdById),
          builder: (context, snapshot) {
            final userData = snapshot.data ?? {};
            final profileImageUrl = userData['profileImageUrl'] as String?;
            final userName = userData['name'] ?? 'ユーザー';

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側：アイコン画像（下端は独立して余白となる）
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                    child: profileImageUrl == null ? const Icon(Icons.person, size: 18) : null,
                  ),
                ),
                const SizedBox(width: 8),
                // 右側：ユーザー情報、タイトル、本文など
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ユーザー名、投稿日時とメニューアイコンを横並びで表示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            //サイズを指定しないと、アイコンが上に寄ってしまう。というか縦幅を最小にしたい。
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ユーザー名
                              Text(
                                userName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                _formatTime(createdAt),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32), // 最低48×48のタップ領域を確保
                            alignment: Alignment.center,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              // constraints の指定は不要になったので削除
                              icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                              onPressed: () {
                                _showMemoMenu(context, memoDoc.id, createdById);
                              },
                            ),
                          )
                        ],
                      ),
                      // タイトル（存在する場合）
                      if (title.isNotEmpty) ...[
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 2),
                      // 本文
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      // メモタイプ、資格名、問題集名をTwitter風ハッシュタグとして表示
                      FutureBuilder<Map<String, String>>(
                        future: _getQuestionMetaData(memoData['questionId'] as String),
                        builder: (context, metaSnapshot) {
                          final questionSetName = metaSnapshot.hasData ? metaSnapshot.data!['questionSetName'] ?? '' : '';
                          final licenseName = metaSnapshot.hasData ? metaSnapshot.data!['licenseName'] ?? '' : '';
                          return Wrap(
                            spacing: 4,
                            runSpacing: 8,
                            children: [
                              if (memoType != null && memoType.isNotEmpty)
                                Text(
                                  "#${_getMemoTypeLabel(memoType)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1DA1F2),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (licenseName.isNotEmpty)
                                Text(
                                  "#$licenseName",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1DA1F2),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (questionSetName.isNotEmpty)
                                Text(
                                  "#$questionSetName",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1DA1F2),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // いいね数、返信数の表示
                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '$replyCount',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
