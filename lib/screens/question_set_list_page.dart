import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/question_list_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/question_set_edit_page.dart';
import 'package:repaso/services/question_count_update.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import '../utils/app_colors.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';
import '../widgets/list_page_widgets/folder_selection_page.dart';
import '../widgets/list_page_widgets/reusable_progress_card.dart';
import 'learning_analytics_page.dart';
import 'question_add_page.dart';
import 'answer_page.dart';

class QuestionSetsListPage extends StatefulWidget {
  final DocumentSnapshot folder;
  final String folderPermission;

  const QuestionSetsListPage({
    Key? key,
    required this.folder,
    required this.folderPermission,
  }) : super(key: key);

  @override
  _QuestionSetListPageState createState() => _QuestionSetListPageState();
}

class _QuestionSetListPageState extends State<QuestionSetsListPage>
    with AutomaticKeepAliveClientMixin {
  /* ───────── 複数選択ステート ───────── */
  static const int _maxSelection = 100;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  /* ───────── キャッシュ ───────── */
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedQuestionSets;

  /* ───────── ナビゲーション系メソッド（省略なし） ───────── */
  void navigateToQuestionSetAddPage(BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuestionSetsAddPage(folderId: folder.id)),
    );
  }

  void navigateToLearningAnalyticsPage(
      BuildContext context, DocumentSnapshot questionSet) async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetRef', isEqualTo: questionSet.reference)
          .get();
      if (qs.docs.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('この問題セットには質問がありません。')));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LearningAnalyticsPage(questionRefs: qs.docs.map((e) => e.reference).toList()),
        ),
      );
    } catch (e) {
      debugPrint('navigateToLearningAnalyticsPage error: $e');
    }
  }

  void navigateToQuestionListPage(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionListPage(
          folder: folder,
          questionSet: questionSet,
          questionSetName: questionSet['name'],
        ),
      ),
    );
  }

  void navigateToQuestionAddPage(
      BuildContext context, DocumentReference folderRef, DocumentReference qsRef) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionAddPage(folderId: folderRef.id, questionSetId: qsRef.id),
      ),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  void navigateToQuestionSetsEditPage(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetEditPage(
          initialQuestionSetName: questionSet['name'],
          folderId: folder.id,
          questionSetId: questionSet.id,
        ),
      ),
    );
    if (result == true && mounted) setState(() {});
  }

  void navigateToAnswerPage(BuildContext context, DocumentReference folderRef,
      DocumentReference qsRef, String qsName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnswerPage(
          folderId: folderRef.id,
          questionSetId: qsRef.id,
          questionSetName: qsName,
        ),
      ),
    );
  }

  /* ───────── 選択モードハンドラ ───────── */
  void _toggleSelection(String qsId) {
    setState(() {
      if (_selectedIds.contains(qsId)) {
        _selectedIds.remove(qsId);
      } else {
        if (_selectedIds.length >= _maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('一度に選択できるのは 100 件までです')),
          );
          return;
        }
        _selectedIds.add(qsId);
        _selectionMode = true;
      }
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  /// ───────── 複数選択用モーダル表示 ─────────
  void _showBulkActionModal() {
    if (_selectedIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _BulkActionSheet(
        selectedCount: _selectedIds.length,
        onMoveTap: () {
          Navigator.pop(context);
          _moveSelected();
        },
        onClearTap: () {
          Navigator.pop(context);
          _clearMemoryLevels(_selectedIds.toList());
        },
        onDeleteTap: () {
          Navigator.pop(context);
          _deleteQuestionSets(_selectedIds.toList());
        },
      ),
    );
  }

  /// ───────── すべて選択 / 解除 ─────────
  void _toggleSelectAll() {
    if (_cachedQuestionSets == null) return;

    setState(() {
      final allIds = _cachedQuestionSets!.map((e) => e.id).toSet();

      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds.take(_maxSelection));
        _selectionMode = true;
      }
    });
  }

  /// ───────── 複数選択アクション ─────────
  Future<void> _moveSelected() async {
    if (_selectedIds.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderSelectionPage(
          questionSetIds: _selectedIds.toList(),
        ),
      ),
    );

    if (result == true && mounted) {
      _cancelSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フォルダを移動しました。')),
      );
    }
  }

  /// 複数選択ボタン → 削除
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await _deleteQuestionSets(_selectedIds.toList());
  }

  /* ───────── ナビゲーション系メソッド ───────── */
  void _navigateToFolderMove(BuildContext context, DocumentSnapshot qs) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderSelectionPage(
          questionSetIds: [qs.id],
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フォルダを移動しました。')),
      );
    }
  }

  /* ───────── オプションモーダル ───────── */
  void showQuestionSetOptionsModal(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot qs) {
    final bool isViewer =
        widget.folderPermission != 'owner' && widget.folderPermission != 'editor';
    final bool canEdit = !isViewer;
    final Color iconBgColor = canEdit ? Colors.blue[700]! : Colors.grey[500]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _OptionSheet(
        folder: folder,
        questionSet: qs,
        canEdit: canEdit,
        iconBgColor: iconBgColor,
        onListTap: () {
          Navigator.pop(context);
          navigateToQuestionListPage(context, folder, qs);
        },
        onGraphTap: () {
          Navigator.pop(context);
          navigateToLearningAnalyticsPage(context, qs);
        },
        onClearTap: () async {
          Navigator.pop(context);
          await _clearMemoryLevels([qs.id]);
        },
        onMoveTap: canEdit
            ? () {
          Navigator.pop(context);
          _navigateToFolderMove(context, qs);
        }
            : null,
        onAddTap: canEdit
            ? () {
          Navigator.pop(context);
          navigateToQuestionAddPage(
              context, widget.folder.reference, qs.reference);
        }
            : null,
        onRenameTap: canEdit
            ? () {
          Navigator.pop(context);
          navigateToQuestionSetsEditPage(context, folder, qs);
        }
            : null,
        onDeleteTap: canEdit
            ? () async {
          Navigator.pop(context);
          await _deleteQuestionSets([qs.id]);
        }
            : null,
      ),
    );
  }

  /// 選択された questionSetId 群の学習履歴をまとめて初期化する
  Future<void> _clearMemoryLevels(List<String> questionSetIds) async {
    if (questionSetIds.isEmpty) return;

    final res = await DeleteConfirmationDialog.show(
      context,
      title: '学習履歴をクリア',
      bulletPoints: const ['問題集の記憶度', '問題集の正答率'],
      description:
      '選択した ${questionSetIds.length} 件の問題集の記憶度が初期化されます。\n上位フォルダの正答率・記憶度にも反映されます。',
      confirmText: 'クリア',
      cancelText: '戻る',
      showCheckbox: false,
    );
    if (res == null || !res.confirmed) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final firestore = FirebaseFirestore.instance;

      final folderStatRef = firestore
          .collection('folders')
          .doc(widget.folder.id)
          .collection('folderSetUserStats')
          .doc(uid);

      final batch = firestore.batch();
      final Map<String, dynamic> delPayload = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final qsId in questionSetIds) {
        final qsRef = firestore.collection('questionSets').doc(qsId);

        // 1) questionSetUserStats を初期化
        batch.set(
          qsRef.collection('questionSetUserStats').doc(uid),
          {
            'memoryLevels': <String, String>{},
            'attemptCount': 0,
            'correctCount': 0,
            'incorrectCount': 0,
            'memoryLevelStats': {
              'again': 0,
              'hard': 0,
              'good': 0,
              'easy': 0,
            },
            'memoryLevelRatios': {
              'again': 0,
              'hard': 0,
              'good': 0,
              'easy': 0,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 2) folderStat の memoryLevels.* を削除
        final qSnap = await firestore
            .collection('questions')
            .where('questionSetRef', isEqualTo: qsRef)
            .get();
        for (final q in qSnap.docs) {
          delPayload['memoryLevels.${q.id}'] = FieldValue.delete();
        }
      }

      // 3) フォルダ統計反映
      batch.set(folderStatRef, {'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true)); // ドキュメントが無い場合は生成だけして…
      if (delPayload.length > 1) batch.update(folderStatRef, delPayload);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${questionSetIds.length} 件の記憶度をクリアしました。')),
        );
        _cancelSelection();
      }
    } catch (e) {
      debugPrint('clearMemoryLevels error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エラーが発生しました')),
        );
      }
    }
  }

  /// ───────── 問題集削除（単一／複数共通） ─────────
  Future<void> _deleteQuestionSets(List<String> questionSetIds) async {
    if (questionSetIds.isEmpty) return;

    final res = await DeleteConfirmationDialog.show(
      context,
      title: '問題集を削除',
      bulletPoints: const ['問題集本体', '配下の問題'],
      description:
      '選択した ${questionSetIds.length} 件の問題集と配下の問題が削除されます。\nこの操作は取り消しできません。',
      confirmText: '削除',
      cancelText: '戻る',
      showCheckbox: false,
      confirmColor: Colors.redAccent,
    );
    if (res == null || !res.confirmed) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      for (final qsId in questionSetIds) {
        final batch = firestore.batch();
        final qsRef = firestore.collection('questionSets').doc(qsId);

        /* ---------- 1) questionSet 本体 ---------- */
        batch.update(qsRef, {
          'isDeleted': true,
        });

        /* ---------- 2) 配下 questions の論理削除 ---------- */
        final qsnap = await firestore
            .collection('questions')
            .where('questionSetRef', isEqualTo: qsRef)
            .get();
        for (var q in qsnap.docs) {
          batch.update(q.reference, {
            'isDeleted': true,
          });
        }

        /* ---------- 3) 上位フォルダ memoryLevels 同期 ---------- */
        if (uid != null && qsnap.docs.isNotEmpty) {
          final folderStatRef = firestore
              .collection('folders')
              .doc(widget.folder.id)
              .collection('folderSetUserStats')
              .doc(uid);

          // ドキュメントが存在しない場合でも失敗しないように、まず merge:true で作成
          batch.set(folderStatRef, {
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          final Map<String, dynamic> delPayload = {};
          for (final q in qsnap.docs) {
            delPayload['memoryLevels.${q.id}'] = FieldValue.delete();
          }
          if (delPayload.isNotEmpty) batch.update(folderStatRef, delPayload);
        }

        await batch.commit();                  // ← ここで確定（500 書込回避のためセット毎コミット）

        /* ---------- 4) 質問数カウント再集計 ---------- */
        await questionCountsUpdate(widget.folder.id, qsId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${questionSetIds.length} 件を削除しました。')),
        );
        _cancelSelection();
      }
    } catch (e) {
      debugPrint('deleteQuestionSets error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました')),
        );
      }
    }
  }

  Widget _hitBoxIcon({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(icon, size: 24, color: Colors.black54),
        ),
      ),
    );
  }

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final bool canEditFolder =
        widget.folderPermission == 'owner' || widget.folderPermission == 'editor';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            _selectionMode ? Icons.close : Icons.arrow_back_ios,
            size: 20,
          ),
          onPressed:
          _selectionMode ? _cancelSelection : () => Navigator.pop(context, true),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectionMode
              ? Text(
            '${_selectedIds.length} 件選択中',
            key: const ValueKey('sel'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          )
              : Text(
            widget.folder['name'],
            key: const ValueKey('title'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        centerTitle: true,
        actions: _selectionMode
            ? [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _hitBoxIcon(
                  icon: Icons.select_all,
                  onTap: _toggleSelectAll,
                ),
                _hitBoxIcon(
                  icon: Icons.more_horiz_outlined,
                  onTap: _selectedIds.isEmpty ? null : _showBulkActionModal,
                ),
              ],
            ),
          ),
        ]
            : canEditFolder
            ? [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _hitBoxIcon(
              icon: Icons.check_box_outlined,
              onTap: _enterSelectionMode,
            ),
          ),
        ]
            : [],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.gray100),
        ),
      ),
      body: _buildBody(canEditFolder),
      floatingActionButton: canEditFolder && !_selectionMode
          ? Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 16),
        child: FloatingActionButton(
          onPressed: () => navigateToQuestionSetAddPage(context, widget.folder),
          backgroundColor: Colors.blue[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          child: const Icon(Icons.add, color: Colors.white, size: 40),
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody(bool canEditFolder) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('questionSets')
          .where('folderId', isEqualTo: widget.folder.id)
          .where('isDeleted', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasData) _cachedQuestionSets = snap.data!.docs;
        final docs = _cachedQuestionSets;

        if (docs == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              '問題集がありません。\n\n早速、右下をタップし作成しよう！',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          );
        }

        docs.sort((a, b) => (a.data()['name'] ?? '').compareTo(b.data()['name'] ?? ''));

        // ・・・中略（docs.sort の後）

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 140),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final qs = docs[index];
            final data = qs.data();
            final questionCount = data['questionCount'] ?? 0;

            return StreamBuilder<DocumentSnapshot>(
              stream: qs.reference
                  .collection('questionSetUserStats')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (ctx, statSnap) {
                final base = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
                int correct = 0, total = 0;

                if (statSnap.hasData && statSnap.data!.exists) {
                  final Map<String, dynamic>? docMap =
                  statSnap.data!.data() as Map<String, dynamic>?;

                  // 1) 数値カウントがある場合はそれを優先
                  final Map<String, dynamic>? memoryLevelStats =
                  docMap?['memoryLevelStats'] as Map<String, dynamic>?;
                  if (memoryLevelStats != null && memoryLevelStats.isNotEmpty) {
                    memoryLevelStats.forEach((k, v) {
                      if (base.containsKey(k) && v is num) {
                        base[k] = v.toInt();
                      }
                    });
                  } else {
                    // 2) なければ questionId→level のマップから集計
                    final Map<String, dynamic>? memoryLevels =
                    docMap?['memoryLevels'] as Map<String, dynamic>?;
                    if (memoryLevels != null && memoryLevels.isNotEmpty) {
                      for (final lv in memoryLevels.values) {
                        if (lv is String && base.containsKey(lv)) {
                          base[lv] = base[lv]! + 1;
                        }
                      }
                    }
                  }

                  correct = base['easy']! + base['good']! + base['hard']!;
                  total = correct + base['again']!;
                }

                base['unanswered'] = questionCount > correct ? questionCount - correct : 0;

                final bool selected = _selectedIds.contains(qs.id);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_selectionMode)
                      GestureDetector(
                        onTap: () => _toggleSelection(qs.id),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          alignment: Alignment.center, // ★ 縦中央にする
                          width: 28,                   // ★ QuestionListPage と同じサイズ
                          height: 28,                  // ★ QuestionListPage と同じサイズ
                          margin: const EdgeInsets.only(left: 16,), // ★ topを削除
                          decoration: BoxDecoration(
                            color: selected ? Colors.blue[700] : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? Colors.blue[700]! : AppColors.gray300,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // 右側：カード本体（UIは既存のまま）※ selectionMode は常に false で渡す
                    Expanded(
                      child: ReusableProgressCard(
                        iconData: Icons.dehaze_rounded,
                        iconColor: Colors.white,
                        iconBgColor: Colors.blue[700]!,
                        title: data['name'] ?? '未設定',
                        memoryLevels: base,
                        correctAnswers: correct,
                        totalAnswers: total,
                        count: questionCount,
                        countSuffix: ' 問',
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(qs.id);
                          } else {
                            navigateToAnswerPage(
                              context,
                              widget.folder.reference,
                              qs.reference,
                              data['name'] ?? '',
                            );
                          }
                        },
                        onMorePressed: _selectionMode
                            ? () {} // 選択モード中は無効化（見た目は変えない）
                            : () => showQuestionSetOptionsModal(context, widget.folder, qs),
                        selectionMode: _selectionMode,
                        cardId: qs.id,
                        selectedId: null,
                        onSelected: null,
                        hasPermission: canEditFolder,
                      ),
                    ),
                  ],
                );
                // ====== 置き換えここまで ======
              },
            );
          },
        );
      },
    );
  }

  /* AutomaticKeepAliveClientMixin */
  @override
  bool get wantKeepAlive => true;
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({
    Key? key,
    required this.folder,
    required this.questionSet,
    required this.canEdit,
    required this.iconBgColor,
    required this.onListTap,
    required this.onGraphTap,
    required this.onClearTap,
    this.onMoveTap, // ★ 追加
    this.onAddTap,
    this.onRenameTap,
    this.onDeleteTap,
  }) : super(key: key);

  final DocumentSnapshot folder;
  final DocumentSnapshot questionSet;
  final bool canEdit;
  final Color iconBgColor;
  final VoidCallback onListTap;
  final VoidCallback onGraphTap;
  final VoidCallback onClearTap;
  final VoidCallback? onMoveTap; // ★ 追加
  final VoidCallback? onAddTap;
  final VoidCallback? onRenameTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: canEdit ? 560 : 420, // ★ 高さ調整
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: RoundedIconBox(
                icon: Icons.dehaze_rounded,
                backgroundColor: iconBgColor,
                iconColor: Colors.white,
                borderRadius: 8,
                size: 34,
                iconSize: 22,
              ),
              title: Text(
                questionSet['name'],
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.gray100),
            const SizedBox(height: 16),
            _buildItem(Icons.list, '問題の一覧', onListTap),
            const SizedBox(height: 8),
            _buildItem(Icons.show_chart_rounded, 'グラフの確認', onGraphTap),
            const SizedBox(height: 8),
            _buildItem(Icons.restart_alt, '学習履歴をクリア', onClearTap),
            if (canEdit) ...[
              const SizedBox(height: 8),
              _buildItem(Icons.drive_file_move_outline, 'フォルダへ移動', onMoveTap), // ★ 追加
              const SizedBox(height: 8),
              _buildItem(Icons.add, '問題の追加', onAddTap),
              const SizedBox(height: 8),
              _buildItem(Icons.edit_outlined, '名前を変更', onRenameTap),
              const SizedBox(height: 8),
              _buildItem(Icons.delete_outline, '削除する', onDeleteTap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, VoidCallback? onTap) {
    return ListTile(
      enabled: onTap != null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(icon, size: 22, color: AppColors.gray600),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}

class _BulkActionSheet extends StatelessWidget {
  const _BulkActionSheet({
    Key? key,
    required this.selectedCount,
    required this.onMoveTap,
    required this.onClearTap,
    required this.onDeleteTap,
  }) : super(key: key);

  final int selectedCount;
  final VoidCallback onMoveTap;
  final VoidCallback onClearTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 420, // _OptionSheet の canEdit==false 相当
        child: Column(
          children: [
            // ───── ドラッグハンドル ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // ───── ヘッダー ─────
            ListTile(
              leading: RoundedIconBox(
                icon: Icons.check_box_outlined,
                backgroundColor: Colors.blue[700]!,
                iconColor: Colors.white,
                borderRadius: 8,
                size: 34,
                iconSize: 22,
              ),
              title: Text(
                '$selectedCount 件選択中',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.gray100),
            const SizedBox(height: 16),
            // ───── アクション ─────
            _buildItem(Icons.drive_file_move_outline, 'フォルダへ移動', onMoveTap),
            const SizedBox(height: 8),
            _buildItem(Icons.restart_alt, '学習履歴をクリア', onClearTap),
            const SizedBox(height: 8),
            _buildItem(Icons.delete_outline, '削除する', onDeleteTap),
          ],
        ),
      ),
    );
  }

  // _OptionSheet と同じ見た目のアイテム
  Widget _buildItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(icon, size: 22, color: AppColors.gray600),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}
