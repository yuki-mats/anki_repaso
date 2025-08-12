// lib/widgets/list_page_widgets/question_set_move_picker.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../utils/app_colors.dart';
import '../list_page_widgets/rounded_icon_box.dart';
import '../study_set_selectable_card.dart';

/// QuestionListPage からの「フォルダ/問題集へ移動」で使う、
/// フォルダは選択不可・問題集のみ単一選択のピッカー。
///
/// 戻り値（Navigator.pop）:
///  {
///    'questionSetId'  : String,
///    'questionSetRef' : DocumentReference,
///    'folderId'       : String,
///    'questionSetName': String,
///  }
class QuestionSetMovePickerPage extends StatefulWidget {
  final String userId;

  const QuestionSetMovePickerPage({Key? key, required this.userId})
      : super(key: key);

  @override
  State<QuestionSetMovePickerPage> createState() =>
      _QuestionSetMovePickerPageState();
}

class _QuestionSetMovePickerPageState extends State<QuestionSetMovePickerPage> {
  // フォルダID -> { name, questionSets: [ {id, name, ref, count} ] }
  Map<String, Map<String, dynamic>> folderData = {};
  // フォルダの展開状態
  Map<String, bool> expandedState = {};
  // 単一選択：選択中の QuestionSetId
  String? selectedQuestionSetId;
  String? selectedFolderId;
  DocumentReference? selectedQuestionSetRef;
  String? selectedQuestionSetName;

  bool isLoading = true;

  static const int _batchSize = 30;
  static const int _visibleItemCount = 6;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ─────────────────────────────────────────────────────────────
  // 権限（owner / editor）のみ許可
  // ─────────────────────────────────────────────────────────────
  Future<bool> _hasOwnerOrEditorPermission(
      DocumentReference<Map<String, dynamic>> folderRef,
      ) async {
    final snap = await folderRef
        .collection('permissions')
        .where(
      'userRef',
      isEqualTo:
      FirebaseFirestore.instance.doc('users/${widget.userId}'),
    )
        .where('role', whereIn: <String>['owner', 'editor'])
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));
    return snap.docs.isNotEmpty;
  }

  // フォルダ & 配下の questionSets を収集（owner/editor のみ）
  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    try {
      final fetched = <String, Map<String, dynamic>>{};
      final expandInit = <String, bool>{};
      final processedIds = <String>{};

      // ① 公式フォルダ（※ owner/editor 権限がある場合のみ許可）
      final officialSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .where('isOfficial', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));

      for (final f in officialSnap.docs) {
        final ok = await _hasOwnerOrEditorPermission(f.reference);
        if (!ok) continue; // viewer / 無権限は除外
        processedIds.add(f.id);
        await _collectFolderData(f, fetched, expandInit);
      }

      // ② 権限付きフォルダ（owner/editor のみ）
      final allFoldersSnap = await FirebaseFirestore.instance
          .collection('folders')
          .where('isDeleted', isEqualTo: false)
          .get(const GetOptions(source: Source.serverAndCache));

      for (final f in allFoldersSnap.docs) {
        if (processedIds.contains(f.id)) continue;
        final ok = await _hasOwnerOrEditorPermission(f.reference);
        if (!ok) continue; // viewer / 無権限は除外
        await _collectFolderData(f, fetched, expandInit);
      }

      setState(() {
        folderData = fetched;
        expandedState = expandInit;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('QuestionSetMovePickerPage _fetchData error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _collectFolderData(
      QueryDocumentSnapshot<Map<String, dynamic>> f,
      Map<String, Map<String, dynamic>> fetched,
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

      qsList.add({
        'id': id,
        'name': name,
        'ref': dq.reference,
        'count': count,
      });
    }

    // 名前順で並べる
    qsList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    fetched[fid] = {
      'name': folderName,
      'questionSets': qsList,
    };
    expandInit.putIfAbsent(fid, () => false);
  }

  void _toggleFolderOpen(String fid) {
    setState(() => expandedState[fid] = !(expandedState[fid] ?? false));
  }

  void _selectQuestionSet({
    required String fid,
    required String qsId,
    required DocumentReference qsRef,
    required String qsName,
  }) {
    setState(() {
      selectedQuestionSetId = qsId;
      selectedFolderId = fid;
      selectedQuestionSetRef = qsRef;
      selectedQuestionSetName = qsName;
    });
  }

  @override
  Widget build(BuildContext context) {
    // スクロール挙動：項目が少なければ固定
    final totalItems = folderData.entries.fold<int>(
      0,
          (sum, entry) => sum + 1 + (entry.value['questionSets'] as List).length,
    );
    final physics = totalItems <= _visibleItemCount
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('移動先の問題集を選択'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.gray100),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        physics: physics,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ...folderData.entries.map((entry) {
            final fid = entry.key;
            final info = entry.value;
            final expanded = expandedState[fid] ?? false;

            return SliverStickyHeader(
              header: Material(
                color: Colors.white,
                child: InkWell(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () => _toggleFolderOpen(fid), // 開閉のみ
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 0, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 左：開閉アイコン（白い「＋ / −」 on 青背景）
                        Container(
                          alignment: Alignment.center,
                          width: 28,
                          height: 28,
                          margin:
                          const EdgeInsets.only(left: 16, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            expanded ? Icons.remove : Icons.add,
                            size: 18,
                            color: Colors.white, // ← 白
                          ),
                        ),
                        // フォルダアイコン
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: RoundedIconBox(
                            icon: expanded
                                ? MdiIcons.folderOpenOutline
                                : MdiIcons.folderOutline,
                            size: 28.0,
                            iconSize: 18.0,
                            iconColor: Colors.white,
                            backgroundColor: Colors.blue[800]!,
                          ),
                        ),
                        // フォルダ名
                        Expanded(
                          child: Text(
                            info['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
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
                    final ref =
                    qsInfo['ref'] as DocumentReference<Object?>;
                    final name = qsInfo['name'] as String;
                    final sel = selectedQuestionSetId == id;

                    return StreamBuilder<DocumentSnapshot>(
                      stream: ref
                          .collection('questionSetUserStats')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (ctx, statSnap) {
                        // 集計値（SetQuestionSetPage と同等）
                        final Map<String, int> lvl = {
                          'again': 0,
                          'hard': 0,
                          'good': 0,
                          'easy': 0,
                        };
                        if (statSnap.hasData && statSnap.data!.exists) {
                          final data = statSnap.data!.data()
                          as Map<String, dynamic>;
                          final stats = data['memoryLevelStats']
                          as Map<String, dynamic>?;
                          if (stats != null && stats.isNotEmpty) {
                            stats.forEach((k, v) {
                              if (lvl.containsKey(k) && v is num) {
                                lvl[k] = v.toInt();
                              }
                            });
                          } else {
                            final raw =
                            (data['memoryLevels'] as Map<String,
                                dynamic>? ??
                                {})
                                .values
                                .whereType<String>();
                            for (final lv in raw) {
                              if (lvl.containsKey(lv)) {
                                lvl[lv] = lvl[lv]! + 1;
                              }
                            }
                          }
                        }
                        final int correct =
                            lvl['easy']! + lvl['good']! + lvl['hard']!;
                        final int answered = correct + lvl['again']!;
                        final int unanswered = count - answered;
                        final memoryLevels = {
                          ...lvl,
                          'unanswered': max(unanswered, 0),
                        };

                        // 行：左の単一選択（チェック） + カード本体
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _selectQuestionSet(
                                fid: fid,
                                qsId: id,
                                qsRef: ref,
                                qsName: name,
                              ),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                alignment: Alignment.center,
                                width: 28,
                                height: 28,
                                margin:
                                const EdgeInsets.only(left: 16.0),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.blue[700]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: sel
                                        ? Colors.blue[700]!
                                        : AppColors.gray300,
                                    width: 2,
                                  ),
                                ),
                                child: sel
                                    ? const Icon(Icons.check,
                                    size: 18, color: Colors.white)
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: StudySetSelectableCard(
                                iconData: Icons.dehaze_rounded,
                                iconColor: Colors.white,
                                iconBgColor: Colors.blue[800]!,
                                title: name,
                                isVerified: false,
                                memoryLevels: memoryLevels,
                                correctAnswers: correct,
                                totalAnswers: count,
                                count: count,
                                countSuffix: ' 問',
                                onTap: () => _selectQuestionSet(
                                  fid: fid,
                                  qsId: id,
                                  qsRef: ref,
                                  qsName: name,
                                ),
                                isSelected: sel,
                                onSelectionChanged: (_) =>
                                    _selectQuestionSet(
                                      fid: fid,
                                      qsId: id,
                                      qsRef: ref,
                                      qsName: name,
                                    ),
                              ),
                            ),
                          ],
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
        padding:
        const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
        child: ElevatedButton(
          onPressed: (selectedQuestionSetId == null ||
              selectedQuestionSetRef == null ||
              selectedFolderId == null)
              ? null
              : () {
            Navigator.pop(context, {
              'questionSetId': selectedQuestionSetId,
              'questionSetRef': selectedQuestionSetRef,
              'folderId': selectedFolderId,
              'questionSetName': selectedQuestionSetName ?? '',
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: (selectedQuestionSetId == null)
                ? Colors.grey
                : Colors.blue[800],
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          child: const Text(
            'ここに移動',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
