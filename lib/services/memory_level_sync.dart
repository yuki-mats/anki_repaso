// lib/services/memory_level_sync.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────
/// 指定ユーザーの memoryLevels を旧フォルダ → 新フォルダへ移植（既存・変更なし）
/// ─────────────────────────────────────────────
Future<void> moveMemoryLevelsForUser({
  required String userId,
  required String oldFolderId,
  required String newFolderId,
  required Map<String, String> memoryLevels,
}) async {
  if (memoryLevels.isEmpty) return;

  final fs = FirebaseFirestore.instance;
  final batch = fs.batch();

  /* ---------- 旧フォルダ: 削除は update() で確実に ---------- */
  final oldRef = fs
      .collection('folders')
      .doc(oldFolderId)
      .collection('folderSetUserStats')
      .doc(userId);

  final Map<String, dynamic> delPayload = {
    'updatedAt': FieldValue.serverTimestamp(),
  };
  for (final qId in memoryLevels.keys) {
    delPayload['memoryLevels.$qId'] = FieldValue.delete();
  }
  batch.update(oldRef, delPayload); // 既存仕様を踏襲

  /* ---------- 新フォルダ: 追加は set(merge:true) で OK ---------- */
  final newRef = fs
      .collection('folders')
      .doc(newFolderId)
      .collection('folderSetUserStats')
      .doc(userId);

  batch.set(
    newRef,
    {
      'memoryLevels': memoryLevels,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  await batch.commit();
}

/// ─────────────────────────────────────────────
/// 単一ユーザー：/questionSetUserStats の memoryLevels から
/// 指定 questionIds を削除（ドキュメントが無ければ何もしない）
/// ─────────────────────────────────────────────
Future<void> removeMemoryLevelsInQuestionSetForUser({
  required String userId,
  required String questionSetId,
  required List<String> questionIds,
}) async {
  if (questionIds.isEmpty) return;

  final fs = FirebaseFirestore.instance;
  final ref = fs
      .collection('questionSets')
      .doc(questionSetId)
      .collection('questionSetUserStats')
      .doc(userId);

  final doc = await ref.get();
  if (!doc.exists) return; // 記録が無ければスキップ

  final Map<String, dynamic> payload = {
    'updatedAt': FieldValue.serverTimestamp(),
  };
  for (final qid in questionIds) {
    payload['memoryLevels.$qid'] = FieldValue.delete();
  }
  await ref.update(payload);
}

/// ─────────────────────────────────────────────
/// 単一ユーザー：問題削除時に、上位の questionSet と folder の
/// memoryLevels から対象 questionIds を“同時に”削除。
/// - それぞれの doc が存在する場合のみ update に含める
/// - どちらか一方しか無くても問題なし
/// ─────────────────────────────────────────────
Future<void> removeMemoryLevelsOnQuestionDeleteForUser({
  required String userId,
  required String folderId,
  required String questionSetId,
  required List<String> questionIds,
}) async {
  if (questionIds.isEmpty) return;

  final fs = FirebaseFirestore.instance;
  final batch = fs.batch();

  // questionSet 側
  final qsRef = fs
      .collection('questionSets')
      .doc(questionSetId)
      .collection('questionSetUserStats')
      .doc(userId);
  final qsDoc = await qsRef.get();
  if (qsDoc.exists) {
    final Map<String, dynamic> qsPayload = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final qid in questionIds) {
      qsPayload['memoryLevels.$qid'] = FieldValue.delete();
    }
    batch.update(qsRef, qsPayload);
  }

  // folder 側
  final folderRef = fs
      .collection('folders')
      .doc(folderId)
      .collection('folderSetUserStats')
      .doc(userId);
  final folderDoc = await folderRef.get();
  if (folderDoc.exists) {
    final Map<String, dynamic> folderPayload = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final qid in questionIds) {
      folderPayload['memoryLevels.$qid'] = FieldValue.delete();
    }
    batch.update(folderRef, folderPayload);
  }

  // どちらかに更新があるときのみ commit
  if (qsDoc.exists || folderDoc.exists) {
    await batch.commit();
  }
}
