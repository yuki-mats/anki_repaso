// lib/widgets/home_page_widgets/learning_now_section.dart
// ignore_for_file: avoid_classes_with_only_static_members
// ──────────────────────────────────────────────────────────────
// 今すぐ学習セクション（学習カードの取得 & 表示）
// ──────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/answer_page.dart';
import 'package:repaso/screens/study_set_answer_page.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/utils/entitlement_gate.dart';
import 'package:repaso/widgets/home_page_widgets/question_set_picker_page.dart';
import 'package:repaso/widgets/home_page_widgets/study_set_picker_page.dart';
import 'package:repaso/widgets/list_page_widgets/reusable_progress_card.dart';

import '../list_page_widgets/skeleton_card.dart';

// dynamic → int 変換ヘルパー
int _i(dynamic v) => v is int ? v : v is num ? v.toInt() : 0;

class LearningNowSection extends StatefulWidget {
  const LearningNowSection({super.key});
  @override
  State<LearningNowSection> createState() => _LearningNowSectionState();
}

class _LearningNowSectionState extends State<LearningNowSection> {
  /* ───────── ステート ───────── */
  final List<Map<String, dynamic>> _cards = [];
  bool  _loading       = false;
  int   _skeletonCount = 1;

  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _sub;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  /* ───────── 監視開始 ───────── */
  @override
  void initState() {
    super.initState();
    debugPrint('LearningNowSection: initState uid=$_uid');
    _sub = FirebaseFirestore.instance
        .doc('users/$_uid')
        .snapshots()
        .listen(_onUserDoc);
  }

  @override
  void dispose() {
    debugPrint('LearningNowSection: dispose()');
    _sub.cancel();
    super.dispose();
  }

  /* ───────────────── Firestore → List 変換 ───────────────── */
  Future<void> _onUserDoc(DocumentSnapshot<Map<String, dynamic>> snap) async {
    debugPrint('LearningNowSection: _onUserDoc() triggered');
    final rootData = snap.data() ?? {};

    // settings.learningNow / learningNow 両対応
    final settings = Map<String, dynamic>.from(rootData['settings'] ?? {});
    final ln = Map<String, dynamic>.from(
        settings['learningNow'] ?? rootData['learningNow'] ?? {});
    debugPrint('LearningNowSection: learningNow map length=${ln.length}');

    // ① learningNow(Map) → List<Map>
    var items = ln.entries
        .map((e) {
      final m = Map<String, dynamic>.from(e.value as Map);
      return {
        'itemId'  : e.key,
        'type'    : m['type'] as String?,
        'refId'   : m['refId'] as String?,
        'folderId': m['folderId'] as String?,
        'order'   : (m['order'] as num?)?.toInt() ?? 0,
      };
    })
        .where((m) => (m['type'] ?? '').toString().isNotEmpty)
        .toList()
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    debugPrint('LearningNowSection: parsed items length=${items.length}');

    // Skeleton 表示
    if (items.isNotEmpty && mounted) {
      setState(() {
        _loading       = true;
        _skeletonCount = items.length;
        _cards.clear();
      });
      debugPrint(
          'LearningNowSection: showing skeletons count=$_skeletonCount');
    }

    // ② 削除対象の検知
    final List<String> keysToDelete = [];
    await Future.wait(items.map((m) async {
      try {
        final ok = await _fillMeta(m);
        if (!ok) {
          debugPrint(
              'LearningNowSection: _fillMeta returned false for itemId=${m['itemId']}');
          keysToDelete.add(m['itemId'] as String);
        }
      } catch (e, st) {
        debugPrint(
            'LearningNowSection: _fillMeta exception for itemId=${m['itemId']} → $e\n$st');
        keysToDelete.add(m['itemId'] as String);
      }
    }));
    debugPrint(
        'LearningNowSection: keysToDelete=${keysToDelete.length} ${keysToDelete.toString()}');
    if (keysToDelete.isNotEmpty) {
      final upd = <String, Object?>{};
      for (final k in keysToDelete) {
        upd['learningNow.$k']             = FieldValue.delete();
        upd['settings.learningNow.$k']    = FieldValue.delete();
      }
      upd['updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.doc('users/$_uid').update(upd);
      items = items.where((m) => !keysToDelete.contains(m['itemId'])).toList();
      debugPrint(
          'LearningNowSection: deleted invalid items, remaining=${items.length}');
    }

    // ③ 無料ユーザーは 1 件制限
    final bool isPro = EntitlementGate().isPro;
    if (!isPro && items.length > 1) {
      debugPrint(
          'LearningNowSection: free user, trimming items from ${items.length} to 1');
      items = items.sublist(0, 1);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _cards
        ..clear()
        ..addAll(items);
    });
    debugPrint(
        'LearningNowSection: cards updated, _cards.length=${_cards.length}');
  }

/* ───────────────── 参照先メタ & 記憶度取得 ───────────────── */
  Future<bool> _fillMeta(Map<String, dynamic> item) async {
    final bool isQs = item['type'] == 'questionSet';
    debugPrint(
        '_fillMeta: start itemId=${item['itemId']} type=${item['type']} refId=${item['refId']} folderId=${item['folderId']}');

    // ─── 参照先ドキュメントのパスを決定 ───
    late String path;
    DocumentSnapshot<Map<String, dynamic>> snap;

    if (isQs) {
      // 1) トップレベル
      path = 'questionSets/${item['refId']}';
      snap = await FirebaseFirestore.instance
          .doc(path)
          .get(const GetOptions(source: Source.serverAndCache));
      debugPrint('_fillMeta: tried $path exists=${snap.exists}');

      // 2) folders フォールバック
      if (!snap.exists) {
        final String folderId = (item['folderId'] ?? '').toString();
        if (folderId.isNotEmpty) {
          path = 'folders/$folderId/questionSets/${item['refId']}';
          snap = await FirebaseFirestore.instance
              .doc(path)
              .get(const GetOptions(source: Source.serverAndCache));
          debugPrint('_fillMeta: tried $path exists=${snap.exists}');
        }
      }
    } else {
      path = 'users/$_uid/studySets/${item['refId']}';
      snap = await FirebaseFirestore.instance
          .doc(path)
          .get(const GetOptions(source: Source.serverAndCache));
      debugPrint('_fillMeta: tried $path exists=${snap.exists}');
    }

    if (!snap.exists) {
      debugPrint('_fillMeta: doc not found, returning false');
      return false;
    }
    final d = snap.data()!;
    if ((d['isDeleted'] ?? false) == true) {
      debugPrint('_fillMeta: doc isDeleted=true, returning false');
      return false;
    }

    // ─── 記憶度集計 ───
    final mem = <String, int>{
      'again': 0,
      'hard': 0,
      'good': 0,
      'easy': 0,
      'unanswered': 0,
    };

    if (isQs) {
      final statSnap = await FirebaseFirestore.instance
          .doc('$path/questionSetUserStats/$_uid')
          .get(const GetOptions(source: Source.serverAndCache));
      debugPrint('_fillMeta: stats exists=${statSnap.exists}');

      if (statSnap.exists) {
        final raw = statSnap.data();
        final mlStats =
        Map<String, dynamic>.from(raw?['memoryLevelStats'] ?? {});

        if (mlStats.isNotEmpty) {
          mem['again'] = _i(mlStats['again']);
          mem['hard']  = _i(mlStats['hard']);
          mem['good']  = _i(mlStats['good']);
          mem['easy']  = _i(mlStats['easy']);
        } else {
          final ml = Map<String, dynamic>.from(raw?['memoryLevels'] ?? {});
          for (final v in ml.values) {
            if (mem.containsKey(v)) mem[v] = mem[v]! + 1;
          }
        }
      }
    } else {
      final mlStats = Map<String, dynamic>.from(d['memoryLevelStats'] ?? {});
      mem['again'] = _i(mlStats['again']);
      mem['hard']  = _i(mlStats['hard']);
      mem['good']  = _i(mlStats['good']);
      mem['easy']  = _i(mlStats['easy']);
    }

    if (isQs) {
      final qsCnt = _i(d['questionCount']);
      final answered =
          mem['again']! + mem['hard']! + mem['good']! + mem['easy']!;
      mem['unanswered'] = max(0, qsCnt - answered);
    }

    final correct  = mem['easy']! + mem['good']! + mem['hard']!;
    final totalAns = correct + mem['again']!;

    debugPrint(
        '_fillMeta: mem=$mem correct=$correct totalAns=$totalAns title=${d['name']}');

    // ─── カード用フィールドを付加 ───
    item
      ..['title'] = d['name'] ?? ''
      ..['iconData'] = isQs ? Icons.dehaze_rounded : Icons.rule
      ..['iconColor'] = Colors.white
      ..['iconBg'] = isQs ? Colors.amber[600] : Colors.amber[800]
      ..['memoryLevels'] = mem
      ..['correct'] = correct
      ..['totalAns'] = totalAns
      ..['count'] = isQs ? _i(d['questionCount']) : totalAns
      ..['suffix'] = isQs ? ' 問' : ' 回';

    debugPrint('_fillMeta: finished for itemId=${item['itemId']}');
    return true;
  }

  /* ───────────────── Firestore 書き込み ───────────────── */
  Future<void> _addLearningNow(Map<String, dynamic> p) async {
    debugPrint('_addLearningNow called with $p');
    final itemId = FirebaseFirestore.instance.collection('_').doc().id;
    final now    = FieldValue.serverTimestamp();
    final payload = {
      'type'      : p['type'],
      'refId'     : p['id'],
      'folderId'  : p['folderId'] ?? '',
      'order'     : DateTime.now().millisecondsSinceEpoch,
      'createdAt' : now,
      'updatedAt' : now,
    };

    await FirebaseFirestore.instance.doc('users/$_uid').set({
      'learningNow.$itemId'          : payload,
      'settings.learningNow.$itemId' : payload,
      'updatedAt'                    : now,
    }, SetOptions(merge: true));
    debugPrint('_addLearningNow: payload saved itemId=$itemId');
  }

  Future<void> _deleteLearningNow(String itemId) async {
    debugPrint('_deleteLearningNow: itemId=$itemId');
    await FirebaseFirestore.instance.doc('users/$_uid').update({
      'learningNow.$itemId'          : FieldValue.delete(),
      'settings.learningNow.$itemId' : FieldValue.delete(),
      'updatedAt'                    : FieldValue.serverTimestamp(),
    });
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        if (_loading)                     _skeletonList()
        else if (_cards.isEmpty)          _emptyArea()
        else                              _cardsList(),
      ],
    ),
  );

  /* --- ヘッダー --- */
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
            child: const Icon(Icons.add, size: 18, color: Colors.black87),
          ),
        ),
      ],
    ),
  );

  /* --- Skeleton 表示 --- */
  Widget _skeletonList() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      children: List.generate(_skeletonCount, (i) => Column(
        children: [
          const SkeletonCard(),
          if (i != _skeletonCount - 1) const SizedBox(height: 4),
        ],
      )),
    ),
  );

  /* --- 空カード --- */
  Widget _emptyArea() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    child: GestureDetector(onTap: _openAddMenu, child: _emptyCard()),
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
          child: const Icon(Icons.add, size: 24, color: Colors.black54),
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

  /* --- カードリスト --- */
  Widget _cardsList() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      children: [
        for (int i = 0; i < _cards.length; i++) ...[
          _progressCard(_cards[i]),
          if (i != _cards.length - 1) const SizedBox(height: 4),
        ],
      ],
    ),
  );

  ReusableProgressCard _progressCard(Map<String, dynamic> m) =>
      ReusableProgressCard(
        iconData       : m['iconData'] as IconData,
        iconColor      : m['iconColor'] as Color,
        iconBgColor    : m['iconBg'] as Color,
        title          : m['title'] as String,
        memoryLevels   : m['memoryLevels'] as Map<String, int>,
        correctAnswers : m['correct'] as int,
        totalAnswers   : m['totalAns'] as int,
        count          : m['count'] as int,
        countSuffix    : m['suffix'] as String,
        onTap          : () => _onCardTap(m),
        onMorePressed  : () => _showMoreModal(m['itemId'] as String),
        selectionMode  : false,
        cardId         : m['refId'] as String,
        selectedId     : null,
        onSelected     : null,
        hasPermission  : true,
      );

  /* ───────── イベント ───────── */
  void _onCardTap(Map<String, dynamic> m) {
    debugPrint('_onCardTap: type=${m['type']} refId=${m['refId']}');
    final bool isQs = m['type'] == 'questionSet';
    if (isQs) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnswerPage(
            folderId       : m['folderId'] ?? '',
            questionSetId  : m['refId'] as String,
            questionSetName: m['title'] as String,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudySetAnswerPage(studySetId: m['refId'] as String),
        ),
      );
    }
  }

  void _showMoreModal(String itemId) => showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
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
            title  : const Text('削除'),
            onTap  : () {
              Navigator.pop(context);
              _deleteLearningNow(itemId);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  /* ───────── 追加メニュー ───────── */
  void _openAddMenu() => showModalBottomSheet<void>(
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
                  borderRadius: BorderRadius.circular(2)),
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
                  final sel =
                  await Navigator.push<Map<String, dynamic>>(
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
                  final sel =
                  await Navigator.push<Map<String, dynamic>>(
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
    child: Icon(icon, size: 22, color: AppColors.gray600),
  );

  /* ───────── ＋ボタン ───────── */
  Future<void> _handleAddPressed() async {
    final bool isPro = EntitlementGate().isPro;
    debugPrint('_handleAddPressed: isPro=$isPro cards=${_cards.length}');
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
