import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'question_count_update.dart';

/// 問題を別の問題集へ移動しつつ、記憶度を
/// - 元/先の questionSetUserStats.memoryLevels
/// - 元/先の folderSetUserStats.memoryLevels
/// でエントリ単位に移し替える。
/// /questions/{qid}/questionUserStats/{uid}.memoryLevel は保持（変更しない）。
Future<void> moveQuestionsWithMemoryForUser({
  required String userId,
  required List<String> questionIds,
  required String fromFolderId,
  required String fromQuestionSetId,
  required String toFolderId,
  required String toQuestionSetId,
}) async {
  if (questionIds.isEmpty) return;
  if (fromQuestionSetId == toQuestionSetId && fromFolderId == toFolderId) return;

  final fs = FirebaseFirestore.instance;

  final fromSetRef   = fs.collection('questionSets').doc(fromQuestionSetId);
  final toSetRef     = fs.collection('questionSets').doc(toQuestionSetId);

  final fromSetUser  = fromSetRef.collection('questionSetUserStats').doc(userId);
  final toSetUser    = toSetRef  .collection('questionSetUserStats').doc(userId);

  final fromFolderUser = fs.collection('folders').doc(fromFolderId)
      .collection('folderSetUserStats').doc(userId);
  final toFolderUser   = fs.collection('folders').doc(toFolderId)
      .collection('folderSetUserStats').doc(userId);

  // 事前に存在化
  await Future.wait([
    toSetUser.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
    toFolderUser.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
    fromSetUser.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
    fromFolderUser.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
  ]);

  // フォールバック用に元の memoryLevels を取得
  final fromSetSnap    = await fromSetUser.get(const GetOptions(source: Source.serverAndCache));
  final fromFolderSnap = await fromFolderUser.get(const GetOptions(source: Source.serverAndCache));

  final Map<String, dynamic> fromSetLevels =
      (fromSetSnap.data() as Map<String, dynamic>?)?['memoryLevels']
      as Map<String, dynamic>? ?? const {};
  final Map<String, dynamic> fromFolderLevels =
      (fromFolderSnap.data() as Map<String, dynamic>?)?['memoryLevels']
      as Map<String, dynamic>? ?? const {};

  // 各問題の memoryLevel（qUser を最優先 → 元Set → 元Folder）
  final Map<String, String?> levelByQid = {};
  await Future.wait(questionIds.map((qid) async {
    try {
      final snap = await fs.collection('questions').doc(qid)
          .collection('questionUserStats').doc(userId)
          .get(const GetOptions(source: Source.serverAndCache));
      final lv = (snap.data() ?? const {})['memoryLevel'];
      if (lv is String && lv.isNotEmpty) {
        levelByQid[qid] = lv;
      } else if (fromSetLevels[qid] is String && (fromSetLevels[qid] as String).isNotEmpty) {
        levelByQid[qid] = fromSetLevels[qid] as String;
      } else if (fromFolderLevels[qid] is String && (fromFolderLevels[qid] as String).isNotEmpty) {
        levelByQid[qid] = fromFolderLevels[qid] as String;
      } else {
        levelByQid[qid] = null;
      }
    } catch (_) {
      if (fromSetLevels[qid] is String && (fromSetLevels[qid] as String).isNotEmpty) {
        levelByQid[qid] = fromSetLevels[qid] as String;
      } else if (fromFolderLevels[qid] is String && (fromFolderLevels[qid] as String).isNotEmpty) {
        levelByQid[qid] = fromFolderLevels[qid] as String;
      } else {
        levelByQid[qid] = null;
      }
    }
  }));

  // 追加は「サブマップ merge」、削除は「ドット表記で key 単位 delete」
  final Map<String, dynamic> delFromSetPaths    = {};
  final Map<String, dynamic> delFromFolderPaths = {};
  final Map<String, dynamic> addToSetNested     = {'memoryLevels': <String, dynamic>{}};
  final Map<String, dynamic> addToFolderNested  = {'memoryLevels': <String, dynamic>{}};

  for (final qid in questionIds) {
    delFromSetPaths['memoryLevels.$qid']    = FieldValue.delete();
    delFromFolderPaths['memoryLevels.$qid'] = FieldValue.delete();

    final lv = levelByQid[qid];
    if (lv != null && lv.isNotEmpty) {
      (addToSetNested['memoryLevels'] as Map<String, dynamic>)[qid] = lv;
      (addToFolderNested['memoryLevels'] as Map<String, dynamic>)[qid] = lv;
    }
  }

  // 1) /questions の移動（バッチ分割）
  const maxItemsPerBatch = 450;
  for (var i = 0; i < questionIds.length; i += maxItemsPerBatch) {
    final part = questionIds.sublist(i, min(i + maxItemsPerBatch, questionIds.length));
    final batch = fs.batch();
    for (final qid in part) {
      batch.update(
        fs.collection('questions').doc(qid),
        {
          'questionSetId' : toQuestionSetId,
          'questionSetRef': toSetRef,
          'updatedAt'     : FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  // 2) 元/先の UserStats を更新
  final batch2 = fs.batch();

  if (delFromSetPaths.isNotEmpty) {
    batch2.update(fromSetUser, delFromSetPaths); // ドット表記 delete
  }
  if (delFromFolderPaths.isNotEmpty) {
    batch2.update(fromFolderUser, delFromFolderPaths);
  }
  final addSetMap = (addToSetNested['memoryLevels'] as Map<String, dynamic>);
  if (addSetMap.isNotEmpty) {
    batch2.set(
      toSetUser,
      {
        'memoryLevels': addSetMap, // ← サブマップで merge
        'updatedAt'   : FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
  final addFolderMap = (addToFolderNested['memoryLevels'] as Map<String, dynamic>);
  if (addFolderMap.isNotEmpty) {
    batch2.set(
      toFolderUser,
      {
        'memoryLevels': addFolderMap, // ← サブマップで merge
        'updatedAt'   : FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  await batch2.commit();

  // 3) 件数再集計
  await questionCountsUpdate(fromFolderId, fromQuestionSetId);
  await questionCountsUpdate(toFolderId,   toQuestionSetId);
}
