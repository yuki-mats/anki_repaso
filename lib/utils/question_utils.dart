import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> updateQuestionCounts(
    DocumentReference folderRef, DocumentReference questionSetRef) async {
  try {
    // 問題集の質問数をカウント
    final questionSetCountSnapshot = await FirebaseFirestore.instance
        .collection('questions')
        .where('questionSetRef', isEqualTo: questionSetRef)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();

    final questionSetTotalQuestions = questionSetCountSnapshot.count;

    // 問題集の質問数を更新
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(questionSetRef, {
        'questionCount': questionSetTotalQuestions,
        'updatedByRef': FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // フォルダの質問数を再計算
    final folderQuestionSetsSnapshot = await FirebaseFirestore.instance
        .collection('questionSets')
        .where('folderRef', isEqualTo: folderRef)
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

    // フォルダの質問数を更新
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(folderRef, {
        'questionCount': folderTotalQuestions,
        'updatedByRef': FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

  } catch (e) {
    print('質問数の更新に失敗しました: $e');
  }
}
