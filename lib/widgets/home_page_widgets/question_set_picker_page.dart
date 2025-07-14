// ignore_for_file: avoid_classes_with_only_static_members
// lib/widgets/home_page_widgets/question_set_picker_page.dart
// ─────────────────────────────────────────────
// QuestionSetPickerPage  ─ 問題集を 1 つだけ選択
// ─────────────────────────────────────────────
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../utils/app_colors.dart';
import '../list_page_widgets/rounded_icon_box.dart';
import '../study_set_selectable_card.dart';
import '../study_set_skeleton_card.dart';

class QuestionSetPickerPage extends StatefulWidget {
  const QuestionSetPickerPage({super.key});
  @override
  State<QuestionSetPickerPage> createState() => _QuestionSetPickerPageState();
}

class _QuestionSetPickerPageState extends State<QuestionSetPickerPage> {
  Map<String, Map<String, dynamic>> _folderData = {};
  Map<String, bool> _expanded = {};
  bool _isLoading = true;

  String? _selectedQsId;
  Map<String, dynamic>? _selectedCardPayload;

  static const int _batch = 30; // whereIn 最大件数

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /* ──────────────────────────────
   * Firestore からフォルダ＆問題集を取得
   * ────────────────────────────── */
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // ① ユーザーのライセンス
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));

      final licenses = (userSnap.data()?['selectedLicenseNames'] as List?)
          ?.whereType<String>()
          .toList() ??
          [];

      // ② すべてのフォルダ取得
      final foldersSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .get(const GetOptions(source: Source.serverAndCache));

      final fetched = <String, Map<String, dynamic>>{};
      final expandedInit = <String, bool>{};

      // ③ フォルダごとに問題集を収集
      await Future.wait([
        for (final f in foldersSnap.docs)
              () async {
            final fd = f.data();
            final lic = fd['licenseName'] as String? ?? '';
            final isOfficial = fd['isOfficial'] as bool? ?? false;

            // 公式：ライセンスフィルタ
            if (isOfficial &&
                licenses.isNotEmpty &&
                !licenses.contains(lic)) return;

            // 非公式：アクセス権を確認
            if (!isOfficial) {
              final permSnap = await f.reference
                  .collection('permissions')
                  .where('userRef',
                  isEqualTo:
                  FirebaseFirestore.instance.doc('users/$uid'))
                  .where('role', whereIn: ['owner', 'editor', 'viewer'])
                  .limit(1)
                  .get(const GetOptions(source: Source.serverAndCache));
              if (permSnap.docs.isEmpty) return;
            }

            // フォルダ内 QuestionSet
            final qsSnap = await FirebaseFirestore.instance
                .collection('questionSets')
                .where('folderId', isEqualTo: f.id)
                .where('isDeleted', isEqualTo: false)
                .get(const GetOptions(source: Source.serverAndCache));

            final qsList = [
              for (var q in qsSnap.docs)
                {
                  'id': q.id,
                  'name': q.data()['name'] ?? '',
                  'count': q.data()['questionCount'] ?? 0,
                  'ref': q.reference,
                }
            ];

            if (qsList.isNotEmpty) {
              fetched[f.id] = {
                'name': fd['name'] ?? '',
                'questionSets': qsList
              };
              expandedInit[f.id] = false;
            }
          }()
      ]);

      setState(() {
        _folderData = fetched;
        _expanded = expandedInit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fetch error: $e');
      setState(() => _isLoading = false);
    }
  }

  /* ──────────────────────────────
   * 単一選択ハンドラ
   * ────────────────────────────── */
  void _select(String qsId, Map<String, dynamic> payload) {
    setState(() {
      _selectedQsId = qsId;
      _selectedCardPayload = payload;
    });
  }

  /* ──────────────────────────────
   * Firestore 書き込み: learningNow に追加
   * ────────────────────────────── */
  /* ───────── Firestore 書き込み: learningNow に追加 ───────── */
  Future<void> _addLearningNow({
    required String qsId,
    required String folderId,
  }) async {
    final uid    = FirebaseAuth.instance.currentUser!.uid;
    final itemId = FirebaseFirestore.instance.collection('_').doc().id;
    final now    = FieldValue.serverTimestamp();

    final payload = {
      'type'     : 'questionSet',
      'refId'    : qsId,
      'folderId' : folderId,
      'order'    : DateTime.now().millisecondsSinceEpoch,
      'createdAt': now,
      'updatedAt': now,
    };

    await FirebaseFirestore.instance.doc('users/$uid').set({
      'settings': {
        'learningNow': { itemId: payload }   // ← パス 2 でネスト登録
      },
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /* ──────────────────────────────
   * 保存
   * ────────────────────────────── */
  Future<void> _onSave() async {
    if (_selectedCardPayload == null) return;

    await _addLearningNow(
      qsId: _selectedCardPayload!['id'] as String,
      folderId: _selectedCardPayload!['folderId'] as String,
    );

    if (mounted) Navigator.pop(context); // 戻る（値は返さない）
  }

  @override
  Widget build(BuildContext context) {
    final physics = _isLoading
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集を選択'),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading ? _buildSkeleton(physics) : _buildContent(physics),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  /* ──────────────── ここから下はレイアウトのみ（変更なし） ──────────────── */
  Widget _buildSkeleton(ScrollPhysics physics) => CustomScrollView(
    physics: physics,
    slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, __) => const StudySetSkeletonCard(),
          childCount: 4,
        ),
      ),
    ],
  );

  Widget _buildContent(ScrollPhysics physics) => CustomScrollView(
    physics: physics,
    slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ..._folderData.entries.map((entry) {
        final fid = entry.key;
        final info = entry.value;
        final expanded = _expanded[fid] ?? false;

        return SliverStickyHeader(
          header: Material(
            color: Colors.white,
            child: InkWell(
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              onTap: () => setState(() => _expanded[fid] = !expanded),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    RoundedIconBox(
                      icon: expanded
                          ? MdiIcons.folderOpenOutline
                          : MdiIcons.folderOutline,
                      size: 28,
                      iconSize: 18,
                      iconColor: AppColors.blue500,
                      backgroundColor: AppColors.blue100,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(info['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final qs =
                (info['questionSets'] as List<Map<String, dynamic>>)[i];
                final qsId = qs['id'] as String;
                final sel = _selectedQsId == qsId;
                final ref = qs['ref'] as DocumentReference;

                return StreamBuilder<DocumentSnapshot>(
                  stream: ref
                      .collection('questionSetUserStats')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (_, statSnap) {
                    final mem = {
                      'again': 0,
                      'hard': 0,
                      'good': 0,
                      'easy': 0,
                      'unanswered': 0
                    };
                    int correct = 0, total = 0;

                    if (statSnap.hasData && statSnap.data!.exists) {
                      final raw =
                          (statSnap.data!.data() as Map<String, dynamic>?)?[
                          'memoryLevels'] as Map<String, dynamic>? ??
                              {};
                      for (var v in raw.values) {
                        if (mem.containsKey(v)) mem[v] = mem[v]! + 1;
                      }
                      correct = mem['easy']! +
                          mem['good']! +
                          mem['hard']!;
                      total = correct + mem['again']!;
                    }
                    mem['unanswered'] =
                        max(0, (qs['count'] as int) - correct);

                    // ★ LearningNowSection で期待される最低限のフィールド
                    final payload = <String, dynamic>{
                      'type': 'questionSet',
                      'id': qsId,
                      'folderId': fid,
                      'title': qs['name'],
                      'iconData': Icons.quiz_outlined,
                      'iconColor': AppColors.blue500,
                      'iconBg': AppColors.blue100,
                      'verified': false,
                      'memoryLevels': Map<String, int>.from(mem),
                      'correct': correct,
                      'totalAns': total,
                      'count': qs['count'],
                      'suffix': '問',
                    };

                    return StudySetSelectableCard(
                      iconData: Icons.quiz_outlined,
                      iconColor: AppColors.blue500,
                      iconBgColor: AppColors.blue100,
                      title: qs['name'] as String,
                      isVerified: false,
                      memoryLevels: Map<String, int>.from(mem),
                      correctAnswers: correct,
                      totalAnswers: total,
                      count: qs['count'] as int,
                      countSuffix: ' 問',
                      isSelected: sel,
                      onTap: () => _select(qsId, payload),
                      onSelectionChanged: (_) => _select(qsId, payload),
                    );
                  },
                );
              },
              childCount:
              expanded ? (info['questionSets'] as List).length : 0,
            ),
          ),
        );
      }).toList(),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ],
  );

  Widget _buildSaveButton() => SafeArea(
    minimum: const EdgeInsets.all(16),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue500,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _selectedQsId == null ? null : _onSave,
        child: const Text('保存',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    ),
  );
}
