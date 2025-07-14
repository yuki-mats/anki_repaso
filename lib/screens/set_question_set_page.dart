import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../screens/paywall_page.dart';
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

  // 選択中 QuestionSet の問題数を素早く参照するために保持
  final Map<String, int> _questionCounts = {};

  bool isLoading = true;
  bool _isPro = false; // 課金ユーザーかどうか

  // 画面に収まる目安のアイテム数
  static const int _visibleItemCount = 6;

  /// whereIn 1 回あたりの最大値（Cloud Firestore は 30 まで可）
  static const int _batchSize = 30;

  @override
  void initState() {
    super.initState();

    debugPrint('[DEBUG] SetQuestionSetPage opened for user: ${widget.userId}');

    // オフラインキャッシュを有効化
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _initializeSelections().then((_) => _fetchData());
  }

  // 保存せずに閉じる
  void _onCancel() => Navigator.pop(context);

  // 既存選択 QuestionSet をバッチで検証
  Future<void> _initializeSelections() async {
    final validIds = <String>[];
    final ids = List<String>.from(widget.selectedQuestionSetIds);

    for (var i = 0; i < ids.length; i += _batchSize) {
      final batch = ids.sublist(i, min(i + _batchSize, ids.length));
      final snap = await FirebaseFirestore.instance
          .collection('questionSets')
          .where(FieldPath.documentId, whereIn: batch)
          .get(const GetOptions(source: Source.serverAndCache));

      for (var doc in snap.docs) {
        final data = doc.data();
        if ((data['isDeleted'] as bool? ?? false) == false) {
          questionSetSelection[doc.id] = true;
          validIds.add(doc.id);
          _questionCounts[doc.id] = data['questionCount'] as int? ?? 0;
        }
      }
    }
    setState(() {
      widget.selectedQuestionSetIds
        ..clear()
        ..addAll(validIds);
    });
  }

  // メインデータ取得
  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    try {
      // ① ユーザー情報
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get(const GetOptions(source: Source.serverAndCache));
      final userData = userDoc.data() ?? {};
      final rawLicenses = userData['selectedLicenseNames'];
      final selectedLicenses = (rawLicenses is List)
          ? rawLicenses.whereType<String>().toList()
          : <String>[];

      _isPro = userData['isPro'] as bool? ?? false;

      debugPrint('[DEBUG] isPro status for ${widget.userId}: $_isPro');

      final fetched = <String, Map<String, dynamic>>{};
      final folderState = <String, bool?>{};
      final expandInit = <String, bool>{};
      final processedIds = <String>{};

      // ② 公式フォルダ
      final officialSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .where('isOfficial', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));

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

      // ③ 権限フォルダ
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

  // 公式フォルダ用フィルタ
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

  // 権限付きフォルダ確認
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
      isEqualTo: FirebaseFirestore.instance.doc('users/${widget.userId}'),
    )
        .where('role', whereIn: ['owner', 'editor', 'viewer'])
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));

    if (permSnap.docs.isNotEmpty) {
      await _collectFolderData(f, fetched, folderState, expandInit);
    }
  }

  // フォルダとその QuestionSet を取得
  Future<void> _collectFolderData(
      QueryDocumentSnapshot<Map<String, dynamic>> f,
      Map<String, Map<String, dynamic>> fetched,
      Map<String, bool?> folderState,
      Map<String, bool> expandInit,
      ) async {
    final fid = f.id;
    final folderName = f.data()['name'] as String? ?? '';

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
      _questionCounts[id] = count;
    }

    fetched[fid] = {
      'name': folderName,
      'questionSets': qsList,
    };
    folderState[fid] = _calcFolderSel(qsList.map((e) => e['id'] as String));
    expandInit.putIfAbsent(fid, () => false);
  }

  // フォルダ選択状態を計算
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
        (folderData[fid]!['questionSets'] as List).map((e) => e['id'] as String),
      );
    });
  }

  void _onBack() => Navigator.pop(
    context,
    questionSetSelection.entries.where((e) => e.value).map((e) => e.key).toList(),
  );

  // 選択済み問題数を算出
  int _selectedQuestionCount() {
    int total = 0;
    questionSetSelection.forEach((id, sel) {
      if (sel) total += _questionCounts[id] ?? 0;
    });
    return total;
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

    // 各種計算
    final int selectedCount = _selectedQuestionCount();
    final int limit = _isPro ? 300 : 30;
    final bool hasSelection = questionSetSelection.values.any((v) => v);
    final bool overLimit = selectedCount > limit;

    final String infoText = overLimit
        ? (_isPro
        ? '最大 $limit 問まで選択できます。現在 $selectedCount 問選択中です。'
        : '無料プランでは最大 $limit 問まで選択できます。現在 $selectedCount 問選択中です。')
        : '現在 $selectedCount / $limit 問を選択中です。';

    VoidCallback? onSave;
    String btnLabel;
    Color btnColor;

    if (!hasSelection) {
      onSave = null;
      btnLabel = '保存';
      btnColor = Colors.grey;
    } else if (overLimit) {
      if (_isPro) {
        onSave = null;
        btnLabel = '保存';
        btnColor = Colors.grey;
      } else {
        onSave = () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PaywallPage(
              subtitle:
              '暗記プラス Proプランでは、最大300問まで選択できます。効率的に学習を進めましょう！',
            ),
          ),
        );
        btnLabel = 'プランを変更する';
        btnColor = AppColors.blue500;
      }
    } else {
      onSave = _onBack;
      btnLabel = '保存';
      btnColor = AppColors.blue500;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集の選択'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onCancel,
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
                  onTap: () => setState(() => expandedState[fid] = !expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _toggleFolder(fid, folderSel != true),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Icon(
                                folderSel == true
                                    ? Icons.check_box
                                    : (folderSel == false
                                    ? Icons.check_box_outline_blank
                                    : Icons.indeterminate_check_box),
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

                    return StreamBuilder<DocumentSnapshot>(
                      stream: ref
                          .collection('questionSetUserStats')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (ctx, statSnap) {
                        // 1) 初期化
                        final Map<String, int> lvl = {
                          'again': 0,
                          'hard': 0,
                          'good': 0,
                          'easy': 0,
                        };

                        // 2) Firestore データを反映
                        if (statSnap.hasData && statSnap.data!.exists) {
                          final data = statSnap.data!.data() as Map<String, dynamic>;

                          // ── 集計版があれば優先
                          final stats = data['memoryLevelStats'] as Map<String, dynamic>?;
                          if (stats != null && stats.isNotEmpty) {
                            stats.forEach((k, v) {
                              if (lvl.containsKey(k) && v is num) {
                                lvl[k] = v.toInt();
                              }
                            });
                          } else {
                            // ── 旧形式を走査
                            final raw = (data['memoryLevels'] as Map<String, dynamic>? ?? {})
                                .values
                                .whereType<String>();
                            for (final lv in raw) {
                              if (lvl.containsKey(lv)) lvl[lv] = lvl[lv]! + 1;
                            }
                          }
                        }

                        // 3) answered / correct を算出
                        final int correct = lvl['easy']! + lvl['good']! + lvl['hard']!;
                        final int answered = correct + lvl['again']!;
                        final int unanswered = count - answered;
                        final memoryLevels = {
                          ...lvl,
                          'unanswered': max(unanswered, 0),
                        };

                        // 4) カード生成
                        return StudySetSelectableCard(
                          iconData: Icons.quiz_outlined,
                          iconColor: AppColors.blue500,
                          iconBgColor: AppColors.blue100,
                          title: qsInfo['name'] as String,
                          isVerified: false,
                          memoryLevels: memoryLevels,  // ← メーター用
                          correctAnswers: correct,
                          totalAnswers: count,         // ← 正答率用
                          count: count,
                          countSuffix: ' 問',
                          onTap: () => _toggleQuestionSet(fid, id),
                          isSelected: sel,
                          onSelectionChanged: (_) => _toggleQuestionSet(fid, id),
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
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.gray600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      infoText,
                      style: TextStyle(color: AppColors.gray600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(
                  btnLabel,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
