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

  // FutureBuilder を使わずにデータを state に直接格納する
  Map<String, dynamic>? _userData;
  Map<String, String>? _questionMeta;
  bool _isLoading = true; // データ取得中か否かを表すフラグ

  /// Firestore のスナップショット更新を待つ前に返信を即時表示するためのローカル返信一覧
  final List<Map<String, dynamic>> _localReplies = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // initState 内で非同期にデータを取得して状態変数に格納する
  Future<void> _fetchInitialData() async {
    final userData = await _getUserData(widget.memoData['createdById'] ?? '');
    final questionMeta =
    await _getQuestionMetaData(widget.memoData['questionId'] as String);
    setState(() {
      _userData = userData;
      _questionMeta = questionMeta;
      _isLoading = false;
    });
  }

  /// 返信送信処理（楽観的更新を実施）
  Future<void> _sendReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String localId = DateTime.now().millisecondsSinceEpoch.toString();

    final replyData = {
      'content': replyText,
      'createdById': user.uid,
      'isDeleted': false,
      'likeCount': 0,
      'reportCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'localId': localId,
    };

    try {
      final memoRef =
      FirebaseFirestore.instance.collection('memos').doc(widget.memoId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final newReplyRef = memoRef.collection('replies').doc();
        transaction.set(newReplyRef, replyData);
        transaction.update(memoRef, {'replyCount': FieldValue.increment(1)});
      });
      setState(() {
        _localReplies.add({
          'id': localId,
          'content': replyText,
          'createdById': user.uid,
          'likeCount': 0,
          'reportCount': 0,
          'createdAt': DateTime.now(),
          'localId': localId,
          'isLocal': true,
        });
      });
      _replyController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('返信の送信に失敗しました')),
      );
    }
  }

  /// Firestore から isDeleted == false の返信を取得する
  Stream<QuerySnapshot> _getRepliesStream() {
    return FirebaseFirestore.instance
        .collection('memos')
        .doc(widget.memoId)
        .collection('replies')
        .orderBy('isDeleted')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  // 非同期データ取得メソッド
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() as Map<String, dynamic>?;
  }

  Future<Map<String, String>> _getQuestionMetaData(String questionId) async {
    final questionSnapshot = await FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .get();
    final questionData = questionSnapshot.data() as Map<String, dynamic>? ?? {};

    DocumentReference? questionSetRef;
    if (questionData.containsKey('questionSetRef') &&
        questionData['questionSetRef'] != null) {
      questionSetRef = questionData['questionSetRef'] as DocumentReference;
    } else if (questionData.containsKey('questionSetId') &&
        questionData['questionSetId'] != null) {
      questionSetRef = FirebaseFirestore.instance
          .collection('questionSets')
          .doc(questionData['questionSetId']);
    }
    if (questionSetRef == null) {
      return {'questionSetName': '', 'licenseName': ''};
    }

    final questionSetSnapshot = await questionSetRef.get();
    final questionSetData =
        questionSetSnapshot.data() as Map<String, dynamic>? ?? {};
    final questionSetName = questionSetData['name'] as String? ?? '';

    DocumentReference? folderRef;
    if (questionSetData.containsKey('folderRef') &&
        questionSetData['folderRef'] != null) {
      folderRef = questionSetData['folderRef'] as DocumentReference;
    } else if (questionSetData.containsKey('folderId') &&
        questionSetData['folderId'] != null) {
      folderRef = FirebaseFirestore.instance
          .collection('folders')
          .doc(questionSetData['folderId']);
    }

    String licenseName = '';
    if (folderRef != null) {
      final folderSnapshot = await folderRef.get();
      final folderData = folderSnapshot.data() as Map<String, dynamic>? ?? {};
      licenseName = folderData['licenseName'] as String? ?? '';
    }

    return {
      'questionSetName': questionSetName,
      'licenseName': licenseName,
    };
  }

  // memoType を日本語表記に変換するヘルパー
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

  /// ヘッダー部分の UI を構築するメソッド
  Widget _buildHeader() {
    if (_isLoading) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    final userData = _userData ?? {};
    final profileImageUrl = userData['profileImageUrl'] as String?;
    final userName = userData['name'] ?? 'ユーザー';

    final header = Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ユーザー情報
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
                  Text(userName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),
          QuestionToggleSection(questionId: widget.memoData['questionId'] as String),
          const SizedBox(height: 12),
          if ((widget.memoData['title'] ?? '').toString().isNotEmpty)
            Text(widget.memoData['title'],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          if ((widget.memoData['title'] ?? '').toString().isNotEmpty)
            const SizedBox(height: 4),
          Text(widget.memoData['content'] ?? '', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (widget.memoData['memoType'] != null &&
                            (widget.memoData['memoType'] as String).isNotEmpty)
                          Text(
                            "#${_getMemoTypeLabel(widget.memoData['memoType'] as String?)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1DA1F2),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if ((_questionMeta?['licenseName'] ?? '').isNotEmpty)
                          Text(
                            "#${_questionMeta?['licenseName']}",
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1DA1F2),
                                fontWeight: FontWeight.w500),
                          ),
                        if ((_questionMeta?['questionSetName'] ?? '').isNotEmpty)
                          Text(
                            "#${_questionMeta?['questionSetName']}",
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1DA1F2),
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${widget.memoData['likeCount'] ?? 0}',
                                style:
                                const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${widget.memoData['replyCount'] ?? 0}',
                                style:
                                const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
    return header;
  }

  /// Firestore のスナップショットとローカル返信をマージして表示するリスト
  Widget _buildReplyList(AsyncSnapshot<QuerySnapshot> snapshot) {
    final firebaseReplies = snapshot.data?.docs ?? [];
    final localRepliesToShow = _localReplies.where((localReply) {
      return firebaseReplies.every((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['localId'] != localReply['localId'];
      });
    }).toList();

    final allReplies = <dynamic>[
      ...firebaseReplies,
      ...localRepliesToShow,
    ];
    allReplies.sort((a, b) {
      final DateTime timeA = a is DocumentSnapshot
          ? ((a.data() as Map<String, dynamic>)['createdAt'] is Timestamp
          ? (((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp)
          .toDate())
          : DateTime.now())
          : (a as Map<String, dynamic>)['createdAt'] as DateTime;
      final DateTime timeB = b is DocumentSnapshot
          ? ((b.data() as Map<String, dynamic>)['createdAt'] is Timestamp
          ? (((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp)
          .toDate())
          : DateTime.now())
          : (b as Map<String, dynamic>)['createdAt'] as DateTime;
      return timeA.compareTo(timeB);
    });

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: allReplies.length + 1, // ヘッダー + 返信一覧
      itemBuilder: (context, index) {
        if (index == 0) {
          return RepaintBoundary(
            child: MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: _buildHeader(),
            ),
          );
        } else {
          final replyItem = allReplies[index - 1];
          if (replyItem is DocumentSnapshot) {
            return ReplyItem(replyDoc: replyItem);
          } else if (replyItem is Map<String, dynamic>) {
            return ReplyItemLocal(replyData: replyItem);
          } else {
            return const SizedBox.shrink();
          }
        }
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
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getRepliesStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('データを取得できませんでした'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildReplyList(snapshot);
          },
        ),
      ),
      bottomNavigationBar: ReplyInputBar(
        controller: _replyController,
        onSend: _sendReply,
      ),
    );
  }
}

/// 以下、ReplyItem、ReplyItemLocal、ReplyInputBar の実装

class ReplyItem extends StatelessWidget {
  final DocumentSnapshot replyDoc;
  const ReplyItem({Key? key, required this.replyDoc}) : super(key: key);

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
              topLeft: Radius.circular(12.0), topRight: Radius.circular(12.0))),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwnReply)
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
                    Navigator.pop(modalContext);
                    final memoId = replyDoc.reference.parent.parent?.id ?? '';
                    final memoRef = FirebaseFirestore.instance.collection('memos').doc(memoId);
                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      final replyRef = memoRef.collection('replies').doc(replyDoc.id);
                      transaction.update(replyRef, {'isDeleted': true});
                      transaction.update(memoRef, {'replyCount': FieldValue.increment(-1)});
                    });
                  },
                )
              else
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
                    Navigator.pop(modalContext);
                  },
                ),
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
                            Text(userName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(_formatTime(createdAt),
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                    Text(content, style: const TextStyle(fontSize: 14), softWrap: true),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${replyData['likeCount'] ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

class ReplyItemLocal extends StatelessWidget {
  final Map<String, dynamic> replyData;
  const ReplyItemLocal({Key? key, required this.replyData}) : super(key: key);

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() as Map<String, dynamic>?;
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final content = replyData['content'] ?? '';
    final createdAt = replyData['createdAt'] as DateTime;
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
                            Text(userName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(_formatTime(createdAt),
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    Text(content, style: const TextStyle(fontSize: 14), softWrap: true),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${replyData['likeCount'] ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: ReplyLikeButton(
                            memoId: '',
                            replyId: replyData['id'] ?? '',
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

class ReplyInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const ReplyInputBar({
    Key? key,
    required this.controller,
    required this.onSend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(color: Colors.grey.shade100),
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
                    controller: controller,
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
                onPressed: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
