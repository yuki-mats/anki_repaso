import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> updateQuestionCounts(
    String folderId, String questionSetId) async {
  try {
    // 問題集の質問数をカウント
    final questionSetCountSnapshot = await FirebaseFirestore.instance
        .collection('questions')
        .where('questionSetId', isEqualTo: questionSetId)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();

    final questionSetTotalQuestions = questionSetCountSnapshot.count;

    // 問題集の質問数を更新（updatedBy はIDとして保存）
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(
        FirebaseFirestore.instance.collection('questionSets').doc(questionSetId),
        {
          'questionCount': questionSetTotalQuestions,
          'updatedById': FirebaseAuth.instance.currentUser!.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });

    // フォルダ内の各問題集の質問数を再計算
    final folderQuestionSetsSnapshot = await FirebaseFirestore.instance
        .collection('questionSets')
        .where('folderId', isEqualTo: folderId)
        .where('isDeleted', isEqualTo: false)
        .get();

    int folderTotalQuestions = 0;

    for (var doc in folderQuestionSetsSnapshot.docs) {
      final latestQuestionSetData = await FirebaseFirestore.instance
          .collection('questionSets')
          .doc(doc.id)
          .get();

      final latestQuestionCount = latestQuestionSetData.data()?['questionCount'] ?? 0;
      folderTotalQuestions += (latestQuestionCount as int);
    }

    // フォルダの質問数を更新（updatedBy はIDとして保存）
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(
        FirebaseFirestore.instance.collection('folders').doc(folderId),
        {
          'questionCount': folderTotalQuestions,
          'updatedById': FirebaseAuth.instance.currentUser!.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  } catch (e) {
    print('質問数の更新に失敗しました: $e');
  }
}
