// lib/widgets/list_page_widgets/folder_selection_page.dart
//
// 選択した questionSetIds（複数・単体どちらも可）を
// 1 つのフォルダへ移動し、questionCount と memoryLevels を同期するページ。
// 変更点：
//   • 引数は questionSetIds: List<String> のみ（単体でも [id] で渡す）
//   • 内部でループして移動処理を実行
//   • UI は従来どおり（ラジオ + 「移動する」ボタン）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/memory_level_sync.dart';
import '../../services/question_count_update.dart';

class FolderSelectionPage extends StatefulWidget {
  const FolderSelectionPage({
    Key? key,
    required this.questionSetIds,
  }) : super(key: key);

  /// 移動対象の questionSetId 一覧（単体移動でも `[id]` で渡す）
  final List<String> questionSetIds;

  @override
  State<FolderSelectionPage> createState() => _FolderSelectionPageState();
}

class _FolderSelectionPageState extends State<FolderSelectionPage> {
  late Future<List<DocumentSnapshot>> _foldersFuture;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _foldersFuture = _fetchEditableFolders();
  }

  /// ─────────────────────────────────────────────
  /// ログインユーザーが owner / editor のフォルダを取得
  /// ─────────────────────────────────────────────
  Future<List<DocumentSnapshot>> _fetchEditableFolders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs  = FirebaseFirestore.instance;

    // ① 自分が owner のフォルダ
    final ownerSnap = await fs
        .collection('folders')
        .where('isDeleted', isEqualTo: false)
        .where('createdById', isEqualTo: uid)
        .get();

    // ② editor 権限を持つフォルダ
    final editorSnap = await fs
        .collectionGroup('permissions')
        .where('userId', isEqualTo: uid)
        .where('role', isEqualTo: 'editor')
        .get();

    // 重複除外して参照をまとめる
    final Map<String, DocumentReference> refs = {
      for (final d in ownerSnap.docs) d.id: d.reference,
    };
    for (final p in editorSnap.docs) {
      final ref = p.reference.parent.parent; // /folders/{folderId}
      if (ref != null) refs[ref.id] = ref;
    }

    // ドキュメントを取得
    final List<DocumentSnapshot> folders = [];
    for (final ref in refs.values) {
      final doc = await ref.get();
      final isDeleted = doc.data() is Map
          ? (doc.data() as Map<String, dynamic>)['isDeleted'] as bool? ?? false
          : false;
      if (doc.exists && !isDeleted) folders.add(doc);
    }

    // 名前順ソート
    folders.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return folders;
  }

  /// ─────────────────────────────────────────────
  /// 移動処理
  /// ─────────────────────────────────────────────
  Future<void> _move() async {
    if (_selectedFolderId == null) return;
    final newFolderId = _selectedFolderId!;
    final fs  = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    /// oldFolderId => {questionId: memoryLevel}
    final Map<String, Map<String, String>> moveMaps = {};
    final Set<String> oldFolderIds = {};

    /* ---------- 1) questionSet を移動しつつ memoryLevels を収集 ---------- */
    for (final qsId in widget.questionSetIds) {
      final qsDoc = await fs.collection('questionSets').doc(qsId).get();
      if (!qsDoc.exists) continue;

      final oldFolderId = qsDoc['folderId'] as String?;
      if (oldFolderId == null || oldFolderId == newFolderId) continue;
      oldFolderIds.add(oldFolderId);

      // questionSet ドキュメントを更新
      await qsDoc.reference.update({
        'folderId'  : newFolderId,
        'folderRef' : fs.collection('folders').doc(newFolderId),
        'updatedAt' : FieldValue.serverTimestamp(),
      });

      // その問題集での memoryLevels を取得
      final statSnap = await qsDoc.reference
          .collection('questionSetUserStats')
          .doc(uid)
          .get();
      final memLevels =
      (statSnap.data()?['memoryLevels'] as Map<String, dynamic>? ?? {});

      // 旧フォルダ単位でまとめる
      moveMaps.putIfAbsent(oldFolderId, () => {});
      moveMaps[oldFolderId]!.addAll(
        memLevels.map((k, v) => MapEntry(k, v as String)),
      );
    }

    /* ---------- 2) memoryLevels を同期（旧→新） ---------- */
    for (final oldId in moveMaps.keys) {
      await moveMemoryLevelsForUser(
        userId      : uid,
        oldFolderId : oldId,
        newFolderId : newFolderId,
        memoryLevels: moveMaps[oldId]!,
      );
    }

    /* ---------- 3) questionCount を再集計 ---------- */
    for (final id in oldFolderIds) {
      await updateFolderQuestionCount(id);
    }
    await updateFolderQuestionCount(newFolderId);

    if (mounted) Navigator.pop(context, true);
  }
  /// ─────────────────────────────────────────────
  /// UI
  /// ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '移動先フォルダを選択',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _foldersFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final folders = snap.data!;
          if (folders.isEmpty) {
            return const Center(child: Text('編集可能なフォルダがありません'));
          }
          return ListView.builder(
            itemCount: folders.length,
            itemBuilder: (ctx, i) {
              final f = folders[i];
              return RadioListTile<String>(
                value: f.id,
                groupValue: _selectedFolderId,
                title: Text(f['name'] ?? ''),
                onChanged: (val) => setState(() => _selectedFolderId = val),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _selectedFolderId == null ? null : _move,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('移動する'),
          ),
        ),
      ),
    );
  }
}
