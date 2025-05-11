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

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _fetchData();
  }

  Future<void> _initializeSelections() async {
    final validIds = <String>[];
    for (var id in widget.selectedQuestionSetIds) {
      final doc = await FirebaseFirestore.instance
          .collection('questionSets')
          .doc(id)
          .get();
      final data = doc.data();
      if (doc.exists && (data?['isDeleted'] as bool? ?? false) == false) {
        questionSetSelection[id] = true;
        validIds.add(id);
      }
    }
    setState(() {
      widget.selectedQuestionSetIds
        ..clear()
        ..addAll(validIds);
    });
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      // ユーザーの選択ライセンス取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final userData = userDoc.data() ?? {};
      final rawLicenses = userData['selectedLicenseNames'];
      final selectedLicenses = <String>[];
      if (rawLicenses is List) {
        for (var e in rawLicenses) {
          if (e is String) selectedLicenses.add(e);
        }
      }

      final fetched = <String, Map<String, dynamic>>{};
      final folderState = <String, bool?>{};
      final expandInit = <String, bool>{};
      final processed = <String>{};

      // ① 公式フォルダ
      final officialSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .where('isOfficial', isEqualTo: true)
          .get();
      for (var f in officialSnap.docs) {
        final lic = (f.data()['licenseName'] as String?) ?? '';
        if (selectedLicenses.isEmpty || selectedLicenses.contains(lic)) {
          processed.add(f.id);
          await _collectFolderData(f, fetched, folderState, expandInit);
        }
      }

      // ② 権限フォルダ
      final allFoldersSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .get();
      for (var f in allFoldersSnap.docs) {
        if (processed.contains(f.id)) continue;
        final permSnap = await f.reference
            .collection('permissions')
            .where('userRef',
            isEqualTo: FirebaseFirestore.instance.doc('users/${widget.userId}'))
            .where('role', whereIn: ['owner', 'editor', 'viewer'])
            .get();
        if (permSnap.docs.isNotEmpty) {
          await _collectFolderData(f, fetched, folderState, expandInit);
        }
      }

      setState(() {
        folderData = fetched;
        folderSelection = folderState;
        expandedState = expandInit;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _collectFolderData(
      QueryDocumentSnapshot f,
      Map<String, Map<String, dynamic>> fetched,
      Map<String, bool?> folderState,
      Map<String, bool> expandInit,
      ) async {
    final fid = f.id;
    final folderMap = f.data() as Map<String, dynamic>? ?? {};
    final fname = folderMap['name'] as String? ?? '';

    final qsSnap = await FirebaseFirestore.instance
        .collection('questionSets')
        .where('folderId', isEqualTo: fid)
        .where('isDeleted', isEqualTo: false)
        .get();

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
      'name': fname,
      'questionSets': qsList,
    };
    folderState[fid] = _calcFolderSel(
      qsList.map((e) => e['id'] as String).toList(),
    );
    expandInit.putIfAbsent(fid, () => false);
  }

  bool? _calcFolderSel(List<String> ids) {
    if (ids.isEmpty) return false;
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
            .map((e) => e['id'] as String)
            .toList(),
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
      // ローディング中はスケルトンを 4 枚表示
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
      // データ表示
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
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Container(
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

                    // 統計をストリームで監視
                    return StreamBuilder<DocumentSnapshot>(
                      stream: ref
                          .collection('questionSetUserStats')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (ctx, statSnap) {
                        final base = {
                          'again': 0,
                          'hard': 0,
                          'good': 0,
                          'easy': 0,
                        };
                        int correct = 0, total = 0;

                        if (statSnap.hasData && statSnap.data!.exists) {
                          final raw = (statSnap.data!.data()
                          as Map<String, dynamic>?)?[
                          'memoryLevels'] as Map<String, dynamic>? ??
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
                        count > correct ? count - correct : 0;

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
                          onTap: () => _toggleQuestionSet(fid, id),
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
