// lib/widgets/home_page_widgets/learning_now_section.dart
// ignore_for_file: avoid_classes_with_only_static_members
// ★ UI はそのままで「現在の記憶度」を反映できるように _fillMeta を刷新
//    加えて：
//    ・無料ユーザー（Pro でない）は 1 件までしか表示しない
//    ・無料ユーザーが 1 件以上ある状態で ＋ を押すと PaywallPage へ遷移
//    ・isDeleted==true／ドキュメント消失時は learningNow から物理削除
// ─────────────────────────────────────────────
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/answer_page.dart';
import 'package:repaso/screens/study_set_answer_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/home_page_widgets/question_set_picker_page.dart';
import 'package:repaso/widgets/home_page_widgets/study_set_picker_page.dart';
import 'package:repaso/widgets/list_page_widgets/reusable_progress_card.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/utils/entitlement_gate.dart';

// dynamic → int 変換用ヘルパー
int _i(dynamic v) => v is int ? v : v is num ? v.toInt() : 0;

class LearningNowSection extends StatefulWidget {
  const LearningNowSection({super.key});
  @override
  State<LearningNowSection> createState() => _LearningNowSectionState();
}

class _LearningNowSectionState extends State<LearningNowSection> {
  final List<Map<String, dynamic>> _cards = [];
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _sub;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .doc('users/$_uid')
        .snapshots()
        .listen(_onUserDoc);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /* ───────────────── Firestore → List 変換 ───────────────── */
  Future<void> _onUserDoc(DocumentSnapshot<Map<String, dynamic>> snap) async {
    final settings =
    (snap.data()?['settings'] ?? {}) as Map<String, dynamic>;
    final ln = (settings['learningNow'] ?? {}) as Map<String, dynamic>;

    // ① learningNow(Map) → List<Map>
    var items = ln.entries
        .map((e) {
      final m = e.value as Map<String, dynamic>;
      return {
        'itemId': e.key,
        'type': m['type'] as String?,
        'refId': m['refId'] as String?,
        'folderId': m['folderId'] as String?,
        'order': (m['order'] as num?)?.toInt() ?? 0,
      };
    })
        .where((m) => (m['type'] ?? '').toString().isNotEmpty)
        .toList()
      ..sort((a, b) =>
          (a['order'] as int).compareTo(b['order'] as int));

    // ② isDeleted==true / ドキュメントなし を検知して Map から物理削除
    final List<String> keysToDelete = [];
    await Future.wait(items.map((m) async {
      final valid = await _fillMeta(m);
      if (!valid) keysToDelete.add(m['itemId'] as String);
    }));
    if (keysToDelete.isNotEmpty) {
      final upd = <String, Object?>{};
      for (final k in keysToDelete) {
        upd['settings.learningNow.$k'] = FieldValue.delete();
      }
      upd['updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.doc('users/$_uid').update(upd);
      items =
          items.where((m) => !keysToDelete.contains(m['itemId'])).toList();
    }

    // ③ 無料ユーザーなら 1 件まで表示
    final bool isPro = EntitlementGate().isPro;
    if (!isPro && items.length > 1) {
      items = items.sublist(0, 1);
    }

    if (!mounted) return;
    setState(() {
      _cards
        ..clear()
        ..addAll(items);
    });
  }

  /* ───────────────── 参照先メタ & 記憶度取得 ───────────────── */
  /// 戻り値: 有効なら true, 削除対象なら false
  Future<bool> _fillMeta(Map<String, dynamic> item) async {
    final bool isQs = item['type'] == 'questionSet';

    // ① ベースドキュメント取得
    final String basePath = isQs
        ? 'questionSets/${item['refId']}'
        : 'users/$_uid/studySets/${item['refId']}';

    final baseSnap = await FirebaseFirestore.instance
        .doc(basePath)
        .get(const GetOptions(source: Source.serverAndCache));

    if (!baseSnap.exists) return false;
    final d = baseSnap.data()!;
    if ((d['isDeleted'] ?? false) == true) return false;

    // ② 記憶度集計
    Map<String, int> mem = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
    if (isQs) {
      final statSnap = await FirebaseFirestore.instance
          .doc('$basePath/questionSetUserStats/$_uid')
          .get(const GetOptions(source: Source.serverAndCache));

      if (statSnap.exists) {
        final raw = statSnap.data();
        final mlStats =
        (raw?['memoryLevelStats'] ?? {}) as Map<String, dynamic>;
        if (mlStats.isNotEmpty) {
          mem['again'] = _i(mlStats['again']);
          mem['hard'] = _i(mlStats['hard']);
          mem['good'] = _i(mlStats['good']);
          mem['easy'] = _i(mlStats['easy']);
        } else {
          final ml =
          (raw?['memoryLevels'] ?? {}) as Map<String, dynamic>;
          for (final v in ml.values) {
            if (mem.containsKey(v)) mem[v] = mem[v]! + 1;
          }
        }
      }
    } else {
      final mlStats =
      (d['memoryLevelStats'] ?? {}) as Map<String, dynamic>;
      mem['again'] = _i(mlStats['again']);
      mem['hard'] = _i(mlStats['hard']);
      mem['good'] = _i(mlStats['good']);
      mem['easy'] = _i(mlStats['easy']);
    }

    final int correct = mem['easy']! + mem['good']! + mem['hard']!;
    final int totalAns = correct + mem['again']!;

    // ③ カード用フィールドを詰める
    item
      ..['title'] = d['name'] ?? ''
      ..['iconData'] =
      isQs ? Icons.quiz_outlined : Icons.school_outlined
      ..['iconColor'] = Colors.white
      ..['iconBg'] =
      isQs ? Colors.indigo : Colors.deepPurple
      ..['verified'] = false
      ..['memoryLevels'] = mem
      ..['correct'] = correct
      ..['totalAns'] = totalAns
      ..['count'] = isQs ? _i(d['questionCount']) : totalAns
      ..['suffix'] = isQs ? ' 問' : ' 回';

    return true;
  }

  /* ───────────────── Firestore 書き込みヘルパ ───────────────── */
  Future<void> _addLearningNow(Map<String, dynamic> p) async {
    final itemId = FirebaseFirestore.instance.collection('_').doc().id;
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.doc('users/$_uid').update({
      'settings.learningNow.$itemId': {
        'type': p['type'],
        'refId': p['id'],
        'folderId': p['folderId'],
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': now,
        'updatedAt': now,
      },
      'updatedAt': now,
    });
  }

  Future<void> _deleteLearningNow(String itemId) async {
    await FirebaseFirestore.instance.doc('users/$_uid').update({
      'settings.learningNow.$itemId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          _cards.isEmpty
              ? Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 4),
            child: GestureDetector(
              onTap: _openAddMenu,
              child: _emptyCard(),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 0),
            child: Column(
              children: [
                for (int i = 0; i < _cards.length; i++) ...[
                  _progressCard(_cards[i]),
                  if (i != _cards.length - 1)
                    const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ───────── 共通 UI パーツ ───────── */
  Widget _header(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
    child: Row(
      children: [
        const Icon(Icons.push_pin, color: Colors.black87),
        const SizedBox(width: 8),
        Text('今すぐ学習',
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.black87)),
        const Spacer(),
        GestureDetector(
          onTap: _handleAddPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add,
                size: 18, color: Colors.black87),
          ),
        ),
      ],
    ),
  );

  Widget _emptyCard() => Container(
    height: 80,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade300),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add,
              size: 24, color: Colors.black54),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('今すぐ学習にセット',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
        ),
        const Icon(Icons.chevron_right, color: Colors.black38),
      ],
    ),
  );

  ReusableProgressCard _progressCard(Map<String, dynamic> m) =>
      ReusableProgressCard(
        iconData: m['iconData'] as IconData,
        iconColor: m['iconColor'] as Color,
        iconBgColor: m['iconBg'] as Color,
        title: m['title'] as String,
        isVerified: m['verified'] as bool,
        memoryLevels: m['memoryLevels'] as Map<String, int>,
        correctAnswers: m['correct'] as int,
        totalAnswers: m['totalAns'] as int,
        count: m['count'] as int,
        countSuffix: m['suffix'] as String,
        onTap: () => _onCardTap(m),
        onMorePressed: () => _showMoreModal(m['itemId'] as String),
        selectionMode: false,
        cardId: m['refId'] as String,
        selectedId: null,
        onSelected: null,
      );

  /* ───────── イベント ───────── */
  void _onCardTap(Map<String, dynamic> m) {
    final bool isQs = m['type'] == 'questionSet';
    if (isQs) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnswerPage(
            folderId: m['folderId'] ?? '',
            questionSetId: m['refId'] as String,
            questionSetName: m['title'] as String,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StudySetAnswerPage(studySetId: m['refId'] as String),
        ),
      );
    }
  }

  void _showMoreModal(String itemId) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: _circleIcon(Icons.delete_outline),
              title: const Text('削除'),
              onTap: () {
                Navigator.pop(context);
                _deleteLearningNow(itemId);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /* ───────── 追加メニュー ───────── */
  void _openAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('今すぐ学習にセット',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.black87)),
            const SizedBox(height: 20),
            Row(
              children: [
                _optionCard(
                  emoji: '📚',
                  title: '問題集',
                  onTap: () async {
                    Navigator.pop(context);
                    final sel = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const QuestionSetPickerPage()),
                    );
                    if (sel != null) _addLearningNow(sel);
                  },
                ),
                const SizedBox(width: 12),
                _optionCard(
                  emoji: '📝',
                  title: '暗記セット',
                  onTap: () async {
                    Navigator.pop(context);
                    final sel = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StudySetPickerPage()),
                    );
                    if (sel != null) _addLearningNow(sel);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /* ───────── 小物 ───────── */
  Widget _optionCard({
    required String emoji,
    required String title,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ],
            ),
          ),
        ),
      );

  Widget _circleIcon(IconData icon) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.gray100,
      borderRadius: BorderRadius.circular(100),
    ),
    child:
    Icon(icon, size: 22, color: AppColors.gray600),
  );

  /* ───────── ＋ボタン押下処理 ───────── */
  Future<void> _handleAddPressed() async {
    final bool isPro = EntitlementGate().isPro;
    if (!isPro && _cards.length >= 1) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PaywallPage(
            subtitle:
            '暗記プラス Proプランでは、今すぐ学習を無制限でセットすることができます。学習効率UP！',
          ),
        ),
      );
      return;
    }
    _openAddMenu();
  }
}
