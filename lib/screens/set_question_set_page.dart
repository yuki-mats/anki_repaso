import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../utils/app_colors.dart';
import '../widgets/list_page_widgets/rounded_icon_box.dart';
import '../widgets/study_set_selectable_card.dart';
import '../widgets/study_set_skeleton_card.dart';

class SetQuestionSetPage extends StatefulWidget {
  final String userId;
  final List<String> selectedQuestionSetIds;

  const SetQuestionSetPage({
    Key? key,
    required this.userId,
    required this.selectedQuestionSetIds,
  }) : super(key: key);

  @override
  _SetQuestionSetPageState createState() => _SetQuestionSetPageState();
}

class _SetQuestionSetPageState extends State<SetQuestionSetPage> {
  Map<String, Map<String, dynamic>> folderData = {};
  Map<String, bool?> folderSelection = {};
  Map<String, bool> questionSetSelection = {};
  Map<String, bool> expandedState = {};
  bool isLoading = true;

  // 画面に収まる目安のアイテム数
  static const int _visibleItemCount = 6;

  /// whereIn 1 回あたりの最大値（Cloud Firestore は 30 まで可）:contentReference[oaicite:0]{index=0}
  static const int _batchSize = 30;

  @override
  void initState() {
    super.initState();

    // ── オフラインキャッシュを有効化
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _initializeSelections().then((_) => _fetchData());
  }

  // ──────────────────────────────
  // 既存選択 QuestionSet をバッチで検証
  // ──────────────────────────────
  Future<void> _initializeSelections() async {
    final validIds = <String>[];
    final ids = List<String>.from(widget.selectedQuestionSetIds);

    for (var i = 0; i < ids.length; i += _batchSize) {
      final batch = ids.sublist(i, min(i + _batchSize, ids.length));
      final snap = await FirebaseFirestore.instance
          .collection('questionSets')
          .where(FieldPath.documentId, whereIn: batch)
      // .select() は FlutterFire ではまだ未実装のため使用しない
          .get(const GetOptions(source: Source.serverAndCache));

      for (var doc in snap.docs) {
        final data = doc.data();
        if ((data['isDeleted'] as bool? ?? false) == false) {
          questionSetSelection[doc.id] = true;
          validIds.add(doc.id);
        }
      }
    }
    setState(() {
      widget.selectedQuestionSetIds
        ..clear()
        ..addAll(validIds);
    });
  }

  // ──────────────────────────────
  // メインデータ取得
  // ──────────────────────────────
  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    try {
      // ① ユーザー情報をキャッシュ優先で取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get(const GetOptions(source: Source.serverAndCache));
      final userData = userDoc.data() ?? {};
      final rawLicenses = userData['selectedLicenseNames'];
      final selectedLicenses = (rawLicenses is List)
          ? rawLicenses.whereType<String>().toList()
          : <String>[];

      final fetched = <String, Map<String, dynamic>>{};
      final folderState = <String, bool?>{};
      final expandInit = <String, bool>{};
      final processedIds = <String>{};

      // ② 公式フォルダ取得
      final officialSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .where('isOfficial', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));

      // ③ 公式フォルダの QuestionSet を並列取得
      await Future.wait([
        for (final f in officialSnap.docs)
          _maybeCollectFolderData(
            f,
            selectedLicenses,
            processedIds,
            fetched,
            folderState,
            expandInit,
          )
      ]);

      // ④ 権限フォルダ取得 → 並列取得
      final allFoldersSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .get(const GetOptions(source: Source.serverAndCache));

      await Future.wait([
        for (final f in allFoldersSnap.docs)
          if (!processedIds.contains(f.id))
            _maybeCollectPermittedFolderData(
              f,
              fetched,
              folderState,
              expandInit,
            )
      ]);

      setState(() {
        folderData = fetched;
        folderSelection = folderState;
        expandedState = expandInit;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => isLoading = false);
    }
  }

  // ──────────────────────────────
  // 公式フォルダ用フィルタ
  // ──────────────────────────────
  Future<void> _maybeCollectFolderData(
      QueryDocumentSnapshot<Map<String, dynamic>> f,
      List<String> selectedLicenses,
      Set<String> processed,
      Map<String, Map<String, dynamic>> fetched,
      Map<String, bool?> folderState,
      Map<String, bool> expandInit,
      ) async {
    final lic = f.data()['licenseName'] as String? ?? '';
    if (selectedLicenses.isNotEmpty && !selectedLicenses.contains(lic)) return;

    processed.add(f.id);
    await _collectFolderData(f, fetched, folderState, expandInit);
  }

  // ──────────────────────────────
  // 権限付きフォルダ (sub-collection) を確認
  // ──────────────────────────────
  Future<void> _maybeCollectPermittedFolderData(
      QueryDocumentSnapshot<Map<String, dynamic>> f,
      Map<String, Map<String, dynamic>> fetched,
      Map<String, bool?> folderState,
      Map<String, bool> expandInit,
      ) async {
    final permSnap = await f.reference
        .collection('permissions')
        .where(
      'userRef',
      isEqualTo:
      FirebaseFirestore.instance.doc('users/${widget.userId}'),
    )
        .where('role', whereIn: ['owner', 'editor', 'viewer'])
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));

    if (permSnap.docs.isNotEmpty) {
      await _collectFolderData(f, fetched, folderState, expandInit);
    }
  }

  // ──────────────────────────────
  // フォルダとその QuestionSet を取得
  // ──────────────────────────────
  Future<void> _collectFolderData(
      QueryDocumentSnapshot<Map<String, dynamic>> f,
      Map<String, Map<String, dynamic>> fetched,
      Map<String, bool?> folderState,
      Map<String, bool> expandInit,
      ) async {
    final fid = f.id;
    final folderName = f.data()['name'] as String? ?? '';

    // QuestionSet 取得
    final qsSnap = await FirebaseFirestore.instance
        .collection('questionSets')
        .where('folderId', isEqualTo: fid)
        .where('isDeleted', isEqualTo: false)
        .get(const GetOptions(source: Source.serverAndCache));

    final qsList = <Map<String, dynamic>>[];
    for (var dq in qsSnap.docs) {
      final id = dq.id;
      final data = dq.data();
      final name = data['name'] as String? ?? '';
      final count = data['questionCount'] as int? ?? 0;
      final sel = widget.selectedQuestionSetIds.contains(id);
      questionSetSelection[id] = questionSetSelection[id] ?? sel;
      if (sel) expandInit[fid] = true;

      qsList.add({
        'id': id,
        'name': name,
        'ref': dq.reference,
        'count': count,
      });
    }

    fetched[fid] = {
      'name': folderName,
      'questionSets': qsList,
    };
    folderState[fid] = _calcFolderSel(
      qsList.map((e) => e['id'] as String),
    );
    expandInit.putIfAbsent(fid, () => false);
  }

  // ──────────────────────────────
  // フォルダ選択状態を計算
  // ──────────────────────────────
  bool? _calcFolderSel(Iterable<String> ids) {
    final allSel = ids.every((i) => questionSetSelection[i] == true);
    final noneSel = ids.every((i) => questionSetSelection[i] == false);
    if (allSel) return true;
    if (noneSel) return false;
    return null;
  }

  void _toggleFolder(String fid, bool sel) {
    for (var qs in (folderData[fid]!['questionSets'] as List)) {
      questionSetSelection[qs['id'] as String] = sel;
    }
    setState(() {
      folderSelection[fid] = sel;
      expandedState[fid] = true;
    });
  }

  void _toggleQuestionSet(String fid, String qsId) {
    setState(() {
      questionSetSelection[qsId] = !(questionSetSelection[qsId] ?? false);
      folderSelection[fid] = _calcFolderSel(
        (folderData[fid]!['questionSets'] as List)
            .map((e) => e['id'] as String),
      );
    });
  }

  void _onBack() {
    Navigator.pop(
      context,
      questionSetSelection.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // スクロール判定
    final totalItems = folderData.entries.fold<int>(
      0,
          (sum, entry) => sum + 1 + (entry.value['questionSets'] as List).length,
    );
    final physics = totalItems <= _visibleItemCount
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集の選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: _onBack,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.gray100),
        ),
      ),
      body: isLoading
          ? CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, __) => const StudySetSkeletonCard(),
              childCount: 4,
            ),
          ),
        ],
      )
          : CustomScrollView(
        physics: physics,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ...folderData.entries.map((entry) {
            final fid = entry.key;
            final info = entry.value;
            final expanded = expandedState[fid] ?? false;
            final folderSel = folderSelection[fid];
            return SliverStickyHeader(
              header: Material(
                color: Colors.white,
                child: InkWell(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () =>
                      setState(() => expandedState[fid] = !expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        RoundedIconBox(
                          icon: expanded
                              ? MdiIcons.folderOpenOutline
                              : MdiIcons.folderOutline,
                          size: 28.0,
                          iconSize: 18.0,
                          iconColor: AppColors.blue500,
                          backgroundColor: AppColors.blue100,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            info['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black87),
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _toggleFolder(fid, folderSel != true),
                          child: Padding(
                            padding:
                            const EdgeInsets.only(right: 10.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Icon(
                                folderSel == true
                                    ? Icons.check_box
                                    : (folderSel == false
                                    ? Icons
                                    .check_box_outline_blank
                                    : Icons
                                    .indeterminate_check_box),
                                color: folderSel != false
                                    ? AppColors.blue500
                                    : AppColors.gray600,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final qsInfo = (info['questionSets']
                    as List<Map<String, dynamic>>)[i];
                    final id = qsInfo['id'] as String;
                    final count = qsInfo['count'] as int? ?? 0;
                    final sel = questionSetSelection[id] ?? false;
                    final ref = qsInfo['ref'] as DocumentReference;

                    // 統計をストリームで監視
                    return StreamBuilder<DocumentSnapshot>(
                      stream: ref
                          .collection('questionSetUserStats')
                          .doc(FirebaseAuth
                          .instance.currentUser?.uid)
                          .snapshots(),
                      builder: (ctx, statSnap) {
                        final base = {
                          'again': 0,
                          'hard': 0,
                          'good': 0,
                          'easy': 0,
                        };
                        int correct = 0, total = 0;

                        if (statSnap.hasData &&
                            statSnap.data!.exists) {
                          final raw =
                              (statSnap.data!.data()
                              as Map<String, dynamic>?)?[
                              'memoryLevels'] as Map<String,
                                  dynamic>? ??
                                  {};
                          for (var v in raw.values) {
                            if (base.containsKey(v)) {
                              base[v] = base[v]! + 1;
                            }
                          }
                          correct = base['easy']! +
                              base['good']! +
                              base['hard']!;
                          total = correct + base['again']!;
                        }
                        base['unanswered'] =
                        count > correct
                            ? count - correct
                            : 0;

                        return StudySetSelectableCard(
                          iconData: Icons.quiz_outlined,
                          iconColor: AppColors.blue500,
                          iconBgColor: AppColors.blue100,
                          title: qsInfo['name'] as String,
                          isVerified: false,
                          memoryLevels:
                          Map<String, int>.from(base),
                          correctAnswers: correct,
                          totalAnswers: total,
                          count: count,
                          countSuffix: ' 問',
                          onTap: () =>
                              _toggleQuestionSet(fid, id),
                          isSelected: sel,
                          onSelectionChanged: (_) =>
                              _toggleQuestionSet(fid, id),
                        );
                      },
                    );
                  },
                  childCount: expanded
                      ? (info['questionSets'] as List).length
                      : 0,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
