//Users/yuki/StudioProjects/repaso/lib/services/question_count_update.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 質問数を更新するユーティリティ
Future<void> questionCountsUpdate(
    String folderId, String questionSetId) async {
  try {
    /* ───── 1. 対象問題集の質問数を count() で再計算 ───── */
    final qsCountSnap = await FirebaseFirestore.instance
        .collection('questions')
        .where('questionSetId', isEqualTo: questionSetId)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();

    // count が int? の SDK もあるため ?? 0 でフォールバック
    final int setTotal = qsCountSnap.count ?? 0;

    await FirebaseFirestore.instance
        .collection('questionSets')
        .doc(questionSetId)
        .update({
      'questionCount': setTotal,
      'updatedById': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    /* ───── 2. フォルダ配下の質問数を aggregate(sum()) で取得 ───── */
    final aggSnap = await FirebaseFirestore.instance
        .collection('questionSets')
        .where('folderId', isEqualTo: folderId)
        .where('isDeleted', isEqualTo: false)
        .aggregate(sum('questionCount'))
        .get();

    // getSum は double? を返す ⇒ int へ丸める
    final int folderTotal = (aggSnap.getSum('questionCount') ?? 0).round();

    /* ───── 3. フォルダ合計を update() ───── */
    await FirebaseFirestore.instance
        .collection('folders')
        .doc(folderId)
        .update({
      'questionCount': folderTotal,
      'updatedById': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print('質問数の更新に失敗しました: $e');
  }
}


Future<void> updateFolderQuestionCount(String folderId) async {
  try {
    final fs = FirebaseFirestore.instance;

    final aggSnap = await fs
        .collection('questionSets')
        .where('folderId', isEqualTo: folderId)
        .where('isDeleted', isEqualTo: false)
        .aggregate(sum('questionCount'))
        .get();

    final int total = (aggSnap.getSum('questionCount') ?? 0).round();

    await fs.collection('folders').doc(folderId).update({
      'questionCount': total,
      'updatedById': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print('フォルダの質問数集計に失敗しました: $e');
  }
}