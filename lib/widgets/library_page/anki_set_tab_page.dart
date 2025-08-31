import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/study_set_answer_page.dart';
import 'package:repaso/screens/study_set_edit_page.dart' as EditPage;
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/list_page_widgets/reusable_progress_card.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← 追加（ローカル永続化）

import '../dialogs/delete_confirmation_dialog.dart';

class AnkiSetTabPage extends StatefulWidget {
  const AnkiSetTabPage({super.key});

  @override
  State<AnkiSetTabPage> createState() => _AnkiSetTabPageState();
}

class _AnkiSetTabPageState extends State<AnkiSetTabPage>
    with AutomaticKeepAliveClientMixin {
  String _studySortBy = 'attemptAsc';
  final Map<String, String> _studySortLabels = const {
    'attemptAsc': '試行回数（昇順）',
    'attemptDesc': '試行回数（降順）',
    'nameAsc': '暗記セット名（昇順）',
    'nameDesc': '暗記セット名（降順）',
    'correctRateAsc': '正答率（昇順）',
    'correctRateDesc': '正答率（降順）',
  };

  // ───────── ここから：ローカル永続化用の追加プロパティ（UI変更なし） ─────────
  String? _uid; // 現在ユーザーのUID（キーの名前空間用）

  static const _kSortKeyPrefix        = 'ankiTab.sort.';           // + uid
  static const _kScrollOffsetPrefix   = 'ankiTab.scrollOffset.';   // + uid
  static const _kLastStudySetIdPrefix = 'ankiTab.lastStudySetId.'; // + uid

  final ScrollController _listController = ScrollController();
  bool _didAttachScrollListener = false;
  bool _didRestoreScroll = false;
  double _initialSavedOffset = 0.0;
  DateTime _lastOffsetSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  // ───────── 追加ここまで ─────────

  /* ───────── 学習記録クリア ───────── */
  Future<void> _clearStudySetRecords(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> studySetRef, {
        required bool deleteDailyStats,
      }) async {
    final firestore = FirebaseFirestore.instance;
    final batch     = firestore.batch();

    /* ---------- 1) 日次サブコレクション ---------- */
    if (deleteDailyStats) {
      final dailyStatsSnap =
      await studySetRef.collection('studySetDailyStats').get();
      for (final d in dailyStatsSnap.docs) {
        batch.delete(d.reference);
      }
    }

    /* ---------- 2) studySets ドキュメント本体 ---------- */
    final Map<String, dynamic> updateData = {
      // 記憶度・正答率などを初期化
      'memoryLevelStats': {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      'memoryLevelRatios': {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      'totalAttemptCount': 0,
      'studyStreakCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 日次データもクリアする場合のみ最終学習日を削除
    if (deleteDailyStats) {
      updateData['lastStudiedDate'] = FieldValue.delete();
    }

    batch.update(studySetRef, updateData);

    /* ---------- 3) コミット ---------- */
    await batch.commit();

    /* ---------- 4) トースト ---------- */
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleteDailyStats
              ? '学習記録をクリアしました（連続学習履歴も削除）'
              : '学習記録をクリアしました（連続学習履歴は保持）',
        ),
      ),
    );
  }

  // ───────── ここから：ローカル永続化メソッド（UIは一切変更しない） ─────────
  Future<void> _ensureUidAndLoadPrefsOnce() async {
    _uid ??= FirebaseAuth.instance.currentUser?.uid;
    if (_uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    // sort
    final savedSort = prefs.getString('$_kSortKeyPrefix$_uid');
    if (savedSort != null && _studySortLabels.containsKey(savedSort)) {
      _studySortBy = savedSort;
    }

    // scroll offset
    _initialSavedOffset = prefs.getDouble('$_kScrollOffsetPrefix$_uid') ?? 0.0;
  }

  Future<void> _saveSortPref() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kSortKeyPrefix$_uid', _studySortBy);
  }

  Future<void> _saveScrollOffset(double offset) async {
    if (_uid == null) return;
    // 300msに1回程度に間引き
    final now = DateTime.now();
    if (now.difference(_lastOffsetSavedAt).inMilliseconds < 300) return;
    _lastOffsetSavedAt = now;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_kScrollOffsetPrefix$_uid', offset.clamp(0.0, double.infinity));
  }

  Future<void> _saveLastStudySetId(String id) async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kLastStudySetIdPrefix$_uid', id);
  }
  // ───────── 追加ここまで ─────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインしてください'));
    }

    // ユーザーごとの保存値を先に読んでおく（非同期だが軽量）
    // build直後のフレームでスクロール復元に使う
    // ignore: discarded_futures
    _ensureUidAndLoadPrefsOnce().then((_) {
      if (!_didAttachScrollListener) {
        _didAttachScrollListener = true;
        _listController.addListener(() {
          // スクロール位置を間引き保存（UIは変更しない）
          _saveScrollOffset(_listController.offset);
        });
      }
    });

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('studySets')
        .where('isDeleted', isEqualTo: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
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
          return const Center(
            child: Text('暗記セットがまだありません',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        // 初回描画後にスクロール復元（UIはそのまま）
        if (!_didRestoreScroll) {
          _didRestoreScroll = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_initialSavedOffset > 0 &&
                _initialSavedOffset < _listController.position.maxScrollExtent + 200) {
              // 多少の件数変化でも違和感が少ない jumpTo を使用
              _listController.jumpTo(_initialSavedOffset);
            }
          });
        }

        return Column(
          children: [
            /* ───────── ソートバー ───────── */
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: InkWell(
                onTap: () => _showSortModal(context),
                child: Row(
                  children: [
                    Icon(
                      _studySortBy.contains('Asc')
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                      color: AppColors.gray700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _studySortLabels[_studySortBy]!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.gray900),
                    ),
                  ],
                ),
              ),
            ),

            /* ───────── 並び替え後リスト ───────── */
            Expanded(
              child: Builder(
                builder: (_) {
                  final list = docs.toList();
                  list.sort((a, b) {
                    final da = a.data()! as Map<String, dynamic>;
                    final db = b.data()! as Map<String, dynamic>;
                    final countA = da['totalAttemptCount'] as int? ?? 0;
                    final countB = db['totalAttemptCount'] as int? ?? 0;
                    final statsA =
                        da['memoryLevelStats'] as Map<String, dynamic>? ?? {};
                    final statsB =
                        db['memoryLevelStats'] as Map<String, dynamic>? ?? {};
                    final correctA = (statsA['hard'] ?? 0) +
                        (statsA['good'] ?? 0) +
                        (statsA['easy'] ?? 0);
                    final correctB = (statsB['hard'] ?? 0) +
                        (statsB['good'] ?? 0) +
                        (statsB['easy'] ?? 0);
                    final rateA = countA > 0 ? correctA / countA : 0;
                    final rateB = countB > 0 ? correctB / countB : 0;
                    final nameA = (da['name'] ?? '') as String;
                    final nameB = (db['name'] ?? '') as String;

                    switch (_studySortBy) {
                      case 'attemptAsc':
                        return countA.compareTo(countB);
                      case 'attemptDesc':
                        return countB.compareTo(countA);
                      case 'nameAsc':
                        return nameA.compareTo(nameB);
                      case 'nameDesc':
                        return nameB.compareTo(nameA);
                      case 'correctRateAsc':
                        return rateA.compareTo(rateB);
                      case 'correctRateDesc':
                        return rateB.compareTo(rateA);
                      default:
                        return 0;
                    }
                  });

                  return ListView.builder(
                    controller: _listController, // ← 追加（見た目は変わらない）
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final doc = list[i];
                      final d = doc.data()! as Map<String, dynamic>;
                      final stats = d['memoryLevelStats'] ?? {};
                      final again = stats['again'] ?? 0;
                      final hard = stats['hard'] ?? 0;
                      final good = stats['good'] ?? 0;
                      final easy = stats['easy'] ?? 0;
                      final correct = hard + good + easy;
                      final total = again + correct;
                      final attempts = d['totalAttemptCount'] ?? 0;
                      final unanswered =
                      attempts > total ? attempts - total : 0;

                      final levels = <String, int>{
                        'again': again,
                        'hard': hard,
                        'good': good,
                        'easy': easy,
                        'unanswered': unanswered,
                      };

                      return ReusableProgressCard(
                        iconData       : Icons.rule_rounded,
                        iconColor      : Colors.white,
                        iconSize       : 18,
                        iconBgColor    : Colors.blue[700]!,
                        title          : d['name'] ?? '未設定',
                        memoryLevels   : levels,
                        correctAnswers : correct,
                        totalAnswers   : total,
                        count          : attempts,
                        countSuffix    : ' 回',
                        selectionMode  : false,
                        cardId         : doc.id,
                        selectedId     : null,
                        onSelected     : null,
                        onTap          : () {
                          _saveLastStudySetId(doc.id); // ← 追加（前回の続き用）
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudySetAnswerPage(studySetId: doc.id),
                            ),
                          );
                        },
                        onMorePressed  : () =>
                            _showStudySetOptions(context, doc),
                        hasPermission  : true, // ← 既存通り
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /* ───────── ソートモーダル ───────── */
  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ..._studySortLabels.entries.map(
                  (e) => RadioListTile<String>(
                activeColor: AppColors.blue500,
                title: Text(e.value),
                value: e.key,
                groupValue: _studySortBy,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _studySortBy = v);
                  setModalState(() => _studySortBy = v);
                  _saveSortPref(); // ← 追加（選択時に保存）
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /* ───────── オプションモーダル ───────── */
  void _showStudySetOptions(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final init = EditPage.StudySet(
      id: doc.id,
      name: data['name'] ?? '未設定',
      questionSetIds: List<String>.from(data['questionSetIds'] ?? []),
      numberOfQuestions: data['numberOfQuestions'] ?? 0,
      selectedQuestionOrder: data['selectedQuestionOrder'] ?? 'random',
      correctRateRange: RangeValues(
        (data['correctRateRange']?['start'] ?? 0).toDouble(),
        (data['correctRateRange']?['end'] ?? 100).toDouble(),
      ),
      isFlagged: data['isFlagged'] ?? false,
      correctChoiceFilter: data['correctChoiceFilter'] ?? 'all',
      selectedMemoryLevels: data.containsKey('selectedMemoryLevels')
          ? List<String>.from(data['selectedMemoryLevels'])
          : ['again', 'hard', 'good', 'easy'],
    );

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 340,
          child: Column(
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
              ListTile(
                leading: RoundedIconBox(
                  icon: Icons.rule_rounded,
                  iconColor: Colors.white,
                  backgroundColor: Colors.blue[800],
                  borderRadius: 8,
                  size: 34,
                  iconSize: 24,
                ),
                title: Text(
                  data['name'] ?? '未設定',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.gray100),
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.edit_outlined,
                text: '暗記セットの編集',
                onTap: () async {
                  Navigator.pop(context);
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditPage.StudySetEditPage(
                        userId: userId,
                        studySetId: doc.id,
                        initialStudySet: init,
                      ),
                    ),
                  );
                  if (res == true && mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.restart_alt,
                text: '学習データをクリア',
                onTap: () async {
                  Navigator.pop(context);

                  // 汎用ダイアログ呼び出し（UI変更なし）
                  final res = await DeleteConfirmationDialog.show(
                    context,
                    title: '学習データをクリア',
                    bulletPoints: const ['記憶度', '正答率'],
                    description: '本暗記セットの下記項目が初期化されます',
                    confirmText: 'クリア',
                    cancelText: 'キャンセル',
                    showCheckbox: true,
                    checkboxLabel: '日次データもクリアする',
                  );

                  // 結果判定
                  if (res != null && res.confirmed) {
                    await _clearStudySetRecords(
                      context,
                      doc.reference as DocumentReference<Map<String, dynamic>>,
                      deleteDailyStats: res.checked,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.delete_outline,
                text: '暗記セットの削除',
                onTap: () async {
                  Navigator.pop(context);

                  // 共通ダイアログを使用
                  final res = await DeleteConfirmationDialog.show(
                    context,
                    title: '暗記セットを削除',
                    bulletPoints: const ['暗記セット本体', '関連する学習データ'],
                    description: '削除すると以下のデータを復元できません',
                    confirmText: '削除',
                    cancelText: 'キャンセル',
                    showCheckbox: false, // ✔︎ チェックボックス不要
                    confirmColor: Colors.redAccent,
                  );

                  if (res != null && res.confirmed) {
                    await doc.reference.update({
                      'isDeleted': true,
                      'deletedAt': FieldValue.serverTimestamp(),
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  ListTile _optionTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Icon(icon, size: 22, color: AppColors.gray600),
        ),
        title: Text(text, style: const TextStyle(fontSize: 16)),
        onTap: onTap,
      );

  @override
  bool get wantKeepAlive => true;
}
