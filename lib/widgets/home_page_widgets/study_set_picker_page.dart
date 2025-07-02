// lib/widgets/home_page_widgets/study_set_picker_page.dart
// ★ このファイル全体を丸ごと置き換えてください
// learningNow への登録まで完了させて HomePage に戻ります
// ─────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/list_page_widgets/reusable_progress_card.dart';

/// dynamic → int 変換
int _i(dynamic v) => v is int
    ? v
    : v is num
    ? v.toInt()
    : 0;

/// 暗記セットを 1 つ選択して learningNow に即登録
class StudySetPickerPage extends StatelessWidget {
  const StudySetPickerPage({super.key});

  /* ───────── Firestore 追加 ───────── */
  Future<void> _addLearningNow(String studySetId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final itemId = FirebaseFirestore.instance.collection('_').doc().id;
    final now = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance.doc('users/$uid').update({
      'settings.learningNow.$itemId': {
        'type': 'studySet',
        'refId': studySetId,
        'folderId': null,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': now,
        'updatedAt': now,
      },
      'updatedAt': now,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ログインしてください')));
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('studySets')
        .where('isDeleted', isEqualTo: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('暗記セットを選択')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('エラー: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('暗記セットがありません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data()! as Map<String, dynamic>;

              final memRaw = Map<String, dynamic>.from(
                  d['memoryLevelStats'] ?? <String, dynamic>{});

              final mem = <String, int>{
                'again': _i(memRaw['again']),
                'hard': _i(memRaw['hard']),
                'good': _i(memRaw['good']),
                'easy': _i(memRaw['easy']),
              };

              final correct = mem['easy']! + mem['good']! + mem['hard']!;
              final total = correct + mem['again']!;

              return ReusableProgressCard(
                iconData: Icons.school_outlined,
                iconColor: Colors.white,
                iconBgColor: Colors.deepPurple,
                title: d['name'] ?? '未設定',
                isVerified: false,
                memoryLevels: mem,
                correctAnswers: correct,
                totalAnswers: total,
                count: _i(d['numberOfQuestions']),
                countSuffix: '枚',
                selectionMode: false,
                cardId: doc.id,
                selectedId: null,
                onSelected: null,
                onMorePressed: () {},
                onTap: () async {
                  await _addLearningNow(doc.id);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}
