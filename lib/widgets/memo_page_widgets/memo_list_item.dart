import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:repaso/screens/reply_list_page.dart';
import 'package:repaso/widgets/memo_edit_page.dart';
import '../../utils/app_colors.dart';

class MemoListItem extends StatelessWidget {
  const MemoListItem({
    Key? key,
    required this.memoDoc,
    this.onTapReply,
  }) : super(key: key);

  final DocumentSnapshot memoDoc;
  final void Function(BuildContext, String, Map<String, dynamic>)? onTapReply;

  /* ───────────── ユーザー情報取得 ───────────── */
  Future<Map<String, dynamic>> _getUserData(String uid) async {
    final snap =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return snap.data() as Map<String, dynamic>? ?? {};
  }

  /* ───────────── タグ変換 & 色ヘルパー ───────────── */
  String _label(String type) => switch (type) {
    'notice'      => '気づき',
    'explanation' => '解説',
    'knowledge'   => '知識・用語',
    'question'    => '疑問',
    _             => type,
  };

  /* ───────────── 投稿日時フォーマット ───────────── */
  String _fmt(DateTime d) => DateFormat('yyyy.MM.dd HH:mm').format(d);

  /* ───────────── ソフトデリート ───────────── */
  Future<void> _deleteMemo(BuildContext ctx, String memoId) async {
    try {
      await FirebaseFirestore.instance.collection('memos').doc(memoId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('メモを削除しました')));
    } catch (_) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('メモの削除に失敗しました')));
    }
  }

  /* ───────────── 通報ダミー ───────────── */
  void _reportMemo(BuildContext ctx) => ScaffoldMessenger.of(ctx)
      .showSnackBar(const SnackBar(content: Text('メモを通報しました')));

  /* ───────────── メニューモーダル ───────────── */
  void _showMenu(BuildContext ctx, String memoId, String ownerId) {
    final isMine = FirebaseAuth.instance.currentUser?.uid == ownerId;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(12.0))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isMine) ...[
            ListTile(
              leading: _circleIcon(Icons.edit_outlined),
              title: const Text('メモを編集'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => MemoEditPage(memoId: memoId),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: _circleIcon(Icons.delete_outline),
              title: const Text('メモを削除'),
              onTap: () async {
                Navigator.pop(ctx);
                await _deleteMemo(ctx, memoId);
              },
            ),
          ] else
            ListTile(
              leading: _circleIcon(Icons.flag_outlined),
              title: const Text('メモを通報'),
              onTap: () {
                Navigator.pop(ctx);
                _reportMemo(ctx);
              },
            ),
        ]),
      ),
    );
  }

  Widget _circleIcon(IconData i) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.gray100,
      shape: BoxShape.circle,
    ),
    child: Icon(i, size: 22, color: AppColors.gray600),
  );

  /* ───────────── 問題メタの取得 ───────────── */
  Future<Map<String, String>> _questionMeta(String? qId) async {
    if (qId == null || qId.isEmpty) {
      return {'set': '', 'lic': ''};
    }
    final qSnap =
    await FirebaseFirestore.instance.collection('questions').doc(qId).get();
    final q = qSnap.data() as Map<String, dynamic>? ?? {};

    DocumentReference? setRef;
    if (q['questionSetRef'] != null) {
      setRef = q['questionSetRef'] as DocumentReference;
    } else if (q['questionSetId'] != null) {
      setRef = FirebaseFirestore.instance
          .collection('questionSets')
          .doc(q['questionSetId']);
    }
    if (setRef == null) return {'set': '', 'lic': ''};

    final setSnap = await setRef.get();
    final set = setSnap.data() as Map<String, dynamic>? ?? {};
    final setName = set['name'] as String? ?? '';

    DocumentReference? folderRef;
    if (set['folderRef'] != null) {
      folderRef = set['folderRef'] as DocumentReference;
    } else if (set['folderId'] != null) {
      folderRef = FirebaseFirestore.instance
          .collection('folders')
          .doc(set['folderId']);
    }
    String lic = '';
    if (folderRef != null) {
      final fSnap = await folderRef.get();
      lic = (fSnap.data() as Map<String, dynamic>? ?? {})['licenseName'] as String? ?? '';
    }
    return {'set': setName, 'lic': lic};
  }

  @override
  Widget build(BuildContext context) {
    /* ───────────── null セーフに取り出し ───────────── */
    final m   = memoDoc.data() as Map<String, dynamic>? ?? {};
    final uid = (m['createdById'] ?? '') as String;
    final title = (m['title'] ?? '') as String;
    final content = (m['content'] ?? '') as String;
    final likeCnt  = (m['likeCount']  ?? 0) as int;
    final replyCnt = (m['replyCount'] ?? 0) as int;
    final memoType = (m['memoType']   ?? '') as String;
    final qId      = m['questionId']  as String? ?? '';
    final ts       = m['createdAt']   as Timestamp?;
    final created  = ts?.toDate() ?? DateTime.now();

    return InkWell(
      onTap: () => onTapReply != null
          ? onTapReply!(context, memoDoc.id, m)
          : Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ReplyListPage(
                memoId: memoDoc.id,
                memoData: m,
              ))),
      child: Container(
        padding:
        const EdgeInsets.only(top: 8, bottom: 12, left: 8, right: 8),
        decoration: const BoxDecoration(
            border:
            Border(bottom: BorderSide(color: Colors.grey, width: .3))),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getUserData(uid),
          builder: (_, userSnap) {
            final user = userSnap.data ?? {};
            final iconUrl = user['profileImageUrl'] as String?;
            final uName   = (user['name'] ?? 'ユーザー') as String;

            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              /* ───── Avatar ───── */
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                    iconUrl != null && iconUrl.isNotEmpty
                        ? iconUrl
                        : 'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2Fdefault_profile_icon_v1.0.png?alt=media&token=545710a7-af21-41d8-ab8b-c56484685f68',
                  ),
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 8),
              /* ───── 内容 ───── */
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  /* ユーザー名／日時／メニュー */
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(uName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(_fmt(created),
                            style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_outlined,
                            color: Colors.grey),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showMenu(context, memoDoc.id, uid),
                      ),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                  const SizedBox(height: 2),
                  Text(content, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  /* ───── ハッシュタグ ───── */
                  FutureBuilder<Map<String, String>>(
                    future: _questionMeta(qId),
                    builder: (_, metaSnap) {
                      final meta = metaSnap.data ?? {'set': '', 'lic': ''};
                      return Wrap(spacing: 4, runSpacing: 8, children: [
                        if (memoType.isNotEmpty)
                          _hashTag(_label(memoType)),
                        if (meta['lic']!.isNotEmpty)
                          _hashTag(meta['lic']!),
                        if (meta['set']!.isNotEmpty)
                          _hashTag(meta['set']!),
                      ]);
                    },
                  ),
                  const SizedBox(height: 8),
                  /* ───── いいね／返信数 ───── */
                  Row(children: [
                    _cntIcon(Icons.favorite_border, likeCnt),
                    const SizedBox(width: 12),
                    _cntIcon(Icons.chat_bubble_outline, replyCnt),
                  ]),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _hashTag(String t) => Text('#$t',
      style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1DA1F2),
          fontWeight: FontWeight.w500),
      overflow: TextOverflow.ellipsis);

  Widget _cntIcon(IconData i, int n) => Row(children: [
    Icon(i, size: 16, color: Colors.grey),
    const SizedBox(width: 4),
    Text('$n', style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ]);
}
