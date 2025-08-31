// lib/widgets/list_page_widgets/folder_selection_page.dart

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
  /// ログインユーザーが owner / editor 権限を持つフォルダを取得
  /// （permissions サブコレクションを信頼）
  /// ─────────────────────────────────────────────
  Future<List<DocumentSnapshot>> _fetchEditableFolders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    // 自分の permissions（owner / editor）のみ取得
    final permSnap = await fs
        .collectionGroup('permissions')
        .where('userId', isEqualTo: uid)
        .where('role', whereIn: ['owner', 'editor'])
        .get();

    // 親フォルダ参照をユニーク化
    final Map<String, DocumentReference> refs = {};
    for (final p in permSnap.docs) {
      final parentFolderRef = p.reference.parent.parent; // /folders/{folderId}
      if (parentFolderRef != null) {
        refs[parentFolderRef.id] = parentFolderRef;
      }
    }

    // 実体のフォルダを取得（isDeleted はローカルで判定）
    final List<DocumentSnapshot> folders = [];
    for (final ref in refs.values) {
      final doc = await ref.get(); // ここで folders の read ルールが評価される
      if (!doc.exists) continue;
      final data = doc.data();
      bool isDeleted = false;
      if (data is Map<String, dynamic>) {
        isDeleted = (data['isDeleted'] as bool?) ?? false;
      }
      if (!isDeleted) {
        folders.add(doc);
      }
    }

    // 名前順ソート（UI 変更なし）
    folders.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return folders;
  }

  /// ─────────────────────────────────────────────
  /// 移動処理
  /// ─────────────────────────────────────────────
  Future<void> _move() async {
    if (_selectedFolderId == null) return;
    final newFolderId = _selectedFolderId!;
    final fs = FirebaseFirestore.instance;
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
        'folderId': newFolderId,
        'folderRef': fs.collection('folders').doc(newFolderId),
        'updatedAt': FieldValue.serverTimestamp(),
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
        userId: uid,
        oldFolderId: oldId,
        newFolderId: newFolderId,
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
  /// UI（従来どおり）
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
