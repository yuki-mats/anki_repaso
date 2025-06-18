import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/app_colors.dart';
import '../list_page_widgets/reusable_progress_card.dart';

/// ─────────────────────────────────────────────
/// StudySetPickerPage  ─ 暗記セット選択ページ
/// LibraryPage の UI と同じカードを使用
/// ─────────────────────────────────────────────

// dynamic な値を int に変換するヘルパー
int _toInt(dynamic v) => v is int ? v : v is num ? v.toInt() : 0;

class StudySetPickerPage extends StatelessWidget {
  const StudySetPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('ログインしてください')),
      );
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
              final d   = doc.data()! as Map<String, dynamic>;

              // Firestore 上の memoryLevelStats を Map<String, dynamic> に統一
              final statsData = Map<String, dynamic>.from(d['memoryLevelStats'] ?? {});

              // int 型に揃えたメモリーレベル
              final memoryLevels = <String, int>{
                'again': _toInt(statsData['again']),
                'hard' : _toInt(statsData['hard']),
                'good' : _toInt(statsData['good']),
                'easy' : _toInt(statsData['easy']),
              };

              final correct = memoryLevels['hard']!
                  + memoryLevels['good']!
                  + memoryLevels['easy']!;
              final total   = memoryLevels['again']! + correct;

              // HomePage へ返す際のペイロード
              final cardData = <String, dynamic>{
                'id'          : doc.id,
                'iconData'    : Icons.school_outlined,
                'iconColor'   : AppColors.blue600,
                'iconBg'      : AppColors.blue100,
                'title'       : d['name'] ?? '未設定',
                'verified'    : false,
                'memoryLevels': memoryLevels,
                'correct'     : correct,
                'totalAns'    : total,
                'count'       : _toInt(d['totalAttemptCount']),
                'suffix'      : '回',
              };

              return ReusableProgressCard(
                iconData       : cardData['iconData'] as IconData,
                iconColor      : cardData['iconColor'] as Color,
                iconBgColor    : cardData['iconBg']   as Color,
                title          : cardData['title']    as String,
                isVerified     : cardData['verified'] as bool,
                memoryLevels   : cardData['memoryLevels'] as Map<String, int>,
                correctAnswers : cardData['correct'] as int,
                totalAnswers   : cardData['totalAns'] as int,
                count          : cardData['count'] as int,
                countSuffix    : cardData['suffix']  as String,
                selectionMode  : false,
                cardId         : cardData['id'] as String,
                selectedId     : null,
                onSelected     : null,
                onMorePressed  : () {},
                onTap          : () => Navigator.pop(context, cardData),
              );
            },
          );
        },
      ),
    );
  }
}
