// lib/screens/folder_tab_page.dart
//
// ★ role が viewer または permissions に自分の UID が無い場合は
//   カードをグレー表示しつつタップ遷移は許可。
//   UI／UX そのものは一切変更していません（色分けのみ）.
//
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repaso/screens/folder_add_page.dart';
import 'package:repaso/screens/folder_edit_page.dart';
import 'package:repaso/screens/licensee_edit_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/question_set_list_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/list_page_widgets/folder_item.dart';
import 'package:repaso/widgets/list_page_widgets/reusable_progress_card.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'package:repaso/widgets/list_page_widgets/skeleton_card.dart';
import 'package:repaso/widgets/dialogs/delete_confirmation_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← 追加

class FolderTabPage extends StatefulWidget {
  const FolderTabPage({super.key});

  @override
  State<FolderTabPage> createState() => FolderTabPageState();
}

class FolderTabPageState extends State<FolderTabPage>
    with AutomaticKeepAliveClientMixin {
  /* ──────────────────────────────────────────
   * 状態変数
   * ────────────────────────────────────────── */
  final List<FolderItem> _folderItems = [];
  List<DocumentSnapshot> _studySets = [];
  Map<String, String> _folderRoles = {}; // folderId → role を保持

  String? _licenseFilter; // null = 全部
  bool? _officialFilter;  // null = 全部, true だけ, false だけ
  String? _sortBy = 'nameAsc';

  bool _isLoading = true;
  final Set<String> _collapsed = {}; // 折りたたみ状態保持

  final Map<String, String> _sortLabels = const {
    'correctRateAsc' : '正答率（昇順）',
    'correctRateDesc': '正答率（降順）',
    'nameAsc'        : 'フォルダ名（昇順）',
    'nameDesc'       : 'フォルダ名（降順）',
  };

  late final ScrollController _scrollController;
  bool _showIconBar = true;
  double _lastOffset = 0.0;

  List<String> _selectedLicenseNames = [];

  // ───── ここからローカル永続化用の追加プロパティ ─────
  String? _uid; // 現在ログインユーザーのUID（保存時の名前空間に使用）

  static const _kSortKeyPrefix         = 'folderTab.sort.';          // + uid
  static const _kOfficialKeyPrefix     = 'folderTab.official.';      // + uid
  static const _kLicenseKeyPrefix      = 'folderTab.license.';       // + uid
  static const _kCollapsedKeyPrefix    = 'folderTab.collapsed.';     // + uid
  static const _kScrollOffsetKeyPrefix = 'folderTab.scrollOffset.';  // + uid
  static const _kIconBarKeyPrefix      = 'folderTab.iconBarVisible.';// + uid
  static const _kLastFolderIdPrefix    = 'folderTab.lastFolderId.';  // + uid

  bool _didRestoreScroll = false;
  double _initialSavedOffset = 0.0;
  DateTime _lastOffsetSavedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // 直前に開いたフォルダ復帰用（描画済み判定のためのキー管理）
  final Map<String, GlobalKey> _itemKeys = {};
  String? _lastFolderId; // 直前に開いたフォルダID（復元に使用）
  bool _ensureTried = false; // 多重実行防止
  // ───── 追加ここまで ─────

  /* ──────────────────────────────────────────
   * 初期化 / 後片付け
   * ────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final offset = _scrollController.offset;
        final delta  = offset - _lastOffset;
        if (offset <= 0 && !_showIconBar) {
          setState(() => _showIconBar = true);
          _saveIconBarVisible(true); // ← 追加：表示状態保存
        } else if (delta > 20 && _showIconBar) {
          setState(() => _showIconBar = false);
          _saveIconBarVisible(false); // ← 追加：表示状態保存
        } else if (delta < -10 && !_showIconBar) {
          setState(() => _showIconBar = true);
          _saveIconBarVisible(true); // ← 追加：表示状態保存
        }
        _lastOffset = offset;

        // スクロール位置を間引き保存
        _saveScrollOffset(offset);
      });
    fetchFirebaseData(); // 初回のみスケルトン表示
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ───── ここからローカル永続化用メソッド（UI変更なし） ─────
  Future<void> _loadPrefs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final sort        = prefs.getString('$_kSortKeyPrefix$uid');
    final officialStr = prefs.getString('$_kOfficialKeyPrefix$uid'); // 'null'|'true'|'false'
    final license     = prefs.getString('$_kLicenseKeyPrefix$uid');   // '' or name
    final collapsedList =
        prefs.getStringList('$_kCollapsedKeyPrefix$uid') ?? const <String>[];

    // 追加項目
    _initialSavedOffset = prefs.getDouble('$_kScrollOffsetKeyPrefix$uid') ?? 0.0;
    final iconBarVisible = prefs.getBool('$_kIconBarKeyPrefix$uid');
    _lastFolderId = prefs.getString('$_kLastFolderIdPrefix$uid'); // ← 追加

    setState(() {
      if (sort != null && _sortLabels.containsKey(sort)) {
        _sortBy = sort;
      }
      if (officialStr != null) {
        _officialFilter =
        (officialStr == 'null') ? null : (officialStr == 'true');
      }
      _licenseFilter = (license == null || license.isEmpty) ? null : license;
      _collapsed
        ..clear()
        ..addAll(collapsedList);

      if (iconBarVisible != null) {
        _showIconBar = iconBarVisible;
      }
    });
  }

  Future<void> _savePrefs() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kSortKeyPrefix$_uid', _sortBy ?? 'nameAsc');
    await prefs.setString(
      '$_kOfficialKeyPrefix$_uid',
      _officialFilter == null ? 'null' : (_officialFilter! ? 'true' : 'false'),
    );
    await prefs.setString(
      '$_kLicenseKeyPrefix$_uid',
      _licenseFilter ?? '',
    );
  }

  Future<void> _saveCollapsed() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_kCollapsedKeyPrefix$_uid', _collapsed.toList());
  }

  Future<void> _saveScrollOffset(double offset) async {
    if (_uid == null) return;
    final now = DateTime.now();
    if (now.difference(_lastOffsetSavedAt).inMilliseconds < 300) return; // 300ms間引き
    _lastOffsetSavedAt = now;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_kScrollOffsetKeyPrefix$_uid', offset.clamp(0.0, double.infinity));
  }

  Future<void> _saveIconBarVisible(bool visible) async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kIconBarKeyPrefix$_uid', visible);
  }

  Future<void> _saveLastFolderId(String folderId) async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kLastFolderIdPrefix$_uid', folderId);
    _lastFolderId = folderId; // メモリ上にも保持
  }

  GlobalKey _getItemKey(String id) {
    return _itemKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _scrollToFolderIdIfVisible(String id) {
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.1, // ちょい上めに表示
        curve: Curves.easeOut,
      );
    }
  }

  void _tryRestoreFocusOrOffsetOnce() {
    if (_ensureTried || !_scrollController.hasClients) return;
    _ensureTried = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1) 直前に開いたフォルダへ寄せる（描画済みのときのみ）
      if (_lastFolderId != null) {
        final key = _itemKeys[_lastFolderId!];
        final ctx = key?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 250),
            alignment: 0.1,
            curve: Curves.easeOut,
          );
          return; // フォルダ優先
        }
      }

      // 2) できない場合はスクロールオフセットを復元
      final max = _scrollController.position.maxScrollExtent + 200;
      if (_initialSavedOffset > 0 && _initialSavedOffset < max) {
        _scrollController.jumpTo(_initialSavedOffset);
      }
    });
  }
  // ───── 追加ここまで ─────

  /* ──────────────────────────────────────────
   * 内部ユーティリティ（差分適用）
   * ────────────────────────────────────────── */
  int _indexOfFolder(String id) {
    for (int i = 0; i < _folderItems.length; i++) {
      if (_folderItems[i].folderDoc.id == id) return i;
    }
    return -1;
  }

  void _applyFolderShellDiff({
    required List<FolderItem> newShellItems,
    required Map<String, String> newRoles,
    required bool silent,
  }) {
    // role は常に最新に
    _folderRoles = newRoles;

    if (!silent) {
      // 初回など：丸ごと差し替え（既存の挙動維持）
      _folderItems
        ..clear()
        ..addAll(newShellItems);
      return;
    }

    // 以後：差分反映（追加／更新／削除）
    final oldIds = _folderItems.map((e) => e.folderDoc.id).toSet();
    final newIds = newShellItems.map((e) => e.folderDoc.id).toSet();

    // 削除
    final toRemove = oldIds.difference(newIds);
    if (toRemove.isNotEmpty) {
      _folderItems.removeWhere((e) => toRemove.contains(e.folderDoc.id));
    }

    // 追加＋更新（folderDoc のみ更新。memoryLevels は保持）
    for (final newItem in newShellItems) {
      final idx = _indexOfFolder(newItem.folderDoc.id);
      if (idx == -1) {
        // 追加：シェルを追加（memoryLevels は placeholder のまま）
        _folderItems.add(newItem);
      } else {
        // 更新：folderDoc が変わっていれば差し替え（memoryLevels は現状維持）
        final current = _folderItems[idx];
        if (!identical(current.folderDoc, newItem.folderDoc)) {
          _folderItems[idx] = FolderItem(
            folderDoc: newItem.folderDoc,
            memoryLevels: current.memoryLevels,
          );
        }
      }
    }
  }

  void _applyStatsDiff(List<FolderItem> statsItems) {
    // memoryLevels（および派生値）だけを差し替え
    for (final s in statsItems) {
      final idx = _indexOfFolder(s.folderDoc.id);
      if (idx != -1) {
        final current = _folderItems[idx];
        _folderItems[idx] = FolderItem(
          folderDoc: current.folderDoc, // 既存の Doc は維持
          memoryLevels: s.memoryLevels, // stats を更新
        );
      } else {
        // もし新規（理論上あり得ないが念のため）
        _folderItems.add(s);
      }
    }
  }

  /* ──────────────────────────────────────────
   * Firestore 取得
   * ────────────────────────────────────────── */
  Future<void> fetchFirebaseData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!silent) {
          setState(() => _isLoading = false);
        }
        return;
      }
      final uid     = user.uid;
      _uid = uid; // ← 追加：保存の名前空間として保持
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // ← 追加：ユーザーごとの表示状態を復元（フォルダ取得前でもOK）
      await _loadPrefs(uid);

      // 1) ユーザー選択ライセンス
      final userDoc  = await userRef.get();
      final licenses = List<String>.from(userDoc.data()?['selectedLicenseNames'] ?? []);
      if (mounted) {
        setState(() => _selectedLicenseNames = licenses);
      }

      // 2) 公式フォルダ（licenseName whereIn 30 件ずつ）
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> officialFutures = [];
      if (licenses.isNotEmpty) {
        for (var i = 0; i < licenses.length; i += 30) {
          final chunk = licenses.sublist(i, (i + 30).clamp(0, licenses.length));
          officialFutures.add(
            FirebaseFirestore.instance
                .collection('folders')
                .where('isOfficial', isEqualTo: true)
                .where('licenseName', whereIn: chunk)
                .where('isDeleted', isEqualTo: false)
                .get(),
          );
        }
      }

      // 3) 権限フォルダ & 暗記セット
      final permFuture = FirebaseFirestore.instance
          .collectionGroup('permissions')
          .where('userRef', isEqualTo: userRef)
          .where('role', whereIn: ['owner', 'editor', 'viewer'])
          .get();
      final studyFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('studySets')
          .where('isDeleted', isEqualTo: false)
          .get();

      final results = await Future.wait([
        ...officialFutures,
        permFuture,
        studyFuture,
      ]);

      /* ─── 4) 公式 + 権限フォルダを結合 ─── */
      final folderDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final tmpRoles   = <String, String>{};
      int idx = 0;

      // 4-1) 公式フォルダ
      for (; idx < officialFutures.length; idx++) {
        final snap = results[idx] as QuerySnapshot<Map<String, dynamic>>;
        for (final d in snap.docs) {
          folderDocs[d.id] = d;              // role 無し → none 扱い
        }
      }

      // 4-2) 自分に権限のあるフォルダ
      final permSnap = results[idx++] as QuerySnapshot<Map<String, dynamic>>;
      for (final p in permSnap.docs) {
        final folderRef = p.reference.parent.parent;
        if (folderRef == null) continue;

        final roleStr = (p.data()['role'] ?? 'none') as String;
        tmpRoles[folderRef.id] = roleStr;    // role 保存

        if (folderDocs.containsKey(folderRef.id)) continue;

        final folderSnap = await folderRef.get();
        if (!folderSnap.exists || (folderSnap.data()?['isDeleted'] ?? false)) {
          continue;
        }
        folderDocs[folderSnap.id] = folderSnap;
      }

      // 5) プレースホルダ（シェル）を作成
      const placeholder = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
      final newShellItems = folderDocs.values
          .map((d) => FolderItem(folderDoc: d, memoryLevels: placeholder))
          .toList();
      final studySnap = results.last as QuerySnapshot<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _studySets = studySnap.docs;
          // 差分適用（silent=true の時は既存 UI を保ったまま）
          _applyFolderShellDiff(
            newShellItems: newShellItems,
            newRoles: tmpRoles,
            silent: silent,
          );
          _isLoading = false; // 初回も含めここで解除
        });
      }

      // 6) memoryLevels をバックグラウンドで取得（差分適用）
      Future<FolderItem> _withStats(
          DocumentSnapshot<Map<String, dynamic>> doc) async {
        final stat = await doc.reference
            .collection('folderSetUserStats')
            .doc(uid)
            .get();
        final mem = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
        if (stat.exists) {
          final ml =
              stat.data()?['memoryLevels'] as Map<String, dynamic>? ?? {};
          ml.forEach((_, lvl) {
            if (mem.containsKey(lvl)) mem[lvl] = mem[lvl]! + 1;
          });
        }
        return FolderItem(folderDoc: doc, memoryLevels: mem);
      }

      final updatedItems =
      await Future.wait(folderDocs.values.map(_withStats).toList());

      if (mounted) {
        setState(() {
          _applyStatsDiff(updatedItems); // ← 行単位の差分更新
        });
      }

      // 7) スクロール復元：直前に開いたフォルダ優先 → できなければオフセット（初回のみ）
      if (mounted && !_didRestoreScroll) {
        _didRestoreScroll = true;
        _tryRestoreFocusOrOffsetOnce();
      }
    } catch (e, st) {
      debugPrint('fetchFirebaseData error: $e\n$st');
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  /* ──────────────────────────────────────────
   * ナビゲーション系メソッド
   * ────────────────────────────────────────── */
  void _navigateToQuestionSetsAddPage(
      BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetsAddPage(folderId: folder.id),
      ),
    );
  }

  Future<void> _navigateToQuestionSetsListPage(
      BuildContext context, DocumentSnapshot folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 前回開いたフォルダIDを保存（UIはそのまま）
    unawaited(_saveLastFolderId(folder.id)); // ← 追加

    final permSnap = await folder.reference
        .collection('permissions')
        .where('userRef',
        isEqualTo:
        FirebaseFirestore.instance.collection('users').doc(user.uid))
        .limit(1)
        .get();

    String role = '';
    if (permSnap.docs.isNotEmpty) role = permSnap.docs.first['role'];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QuestionSetsListPage(folder: folder, folderPermission: role),
      ),
    );

    // 戻ってきた直後に該当フォルダへスクロール（描画済みの場合のみ）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFolderIdIfVisible(folder.id);
    });

    // 戻り時はサイレントで差分更新（スケルトンは出さない）
    await fetchFirebaseData(silent: true);
  }

  Future<void> _navigateToAddLicensePage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LicenseeEditPage(initialSelected: _selectedLicenseNames),
      ),
    );
    if (result is List<String>) {
      setState(() => _selectedLicenseNames = result);
      await fetchFirebaseData(); // ライセンス変更は全体更新（既存挙動のまま）
    }
  }

  Future<void> _navigateToFolderAddPage(BuildContext context) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FolderAddPage()),
    );
    if (res == true) fetchFirebaseData();
  }

  Future<void> _navigateToFolderEditPage(
      BuildContext context, DocumentSnapshot folder) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderEditPage(
          initialFolderName: folder['name'],
          folderId: folder.id,
        ),
      ),
    );
    if (res == true) fetchFirebaseData();
  }

  /* ──────────────────────────────────────────
   * フォルダ／資格追加メニュー
   * ────────────────────────────────────────── */
  void showAddOptionsModal(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 180,
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
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.folder_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('フォルダを追加', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToFolderAddPage(context);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.assignment_turned_in_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('資格を登録', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAddLicensePage(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ──────────────────────────────────────────
   * UI 構築
   * ────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ローディングスケルトン（初回のみ）
    if (_isLoading) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, __) => const SkeletonCard(),
              childCount: 5,
            ),
          ),
        ],
      );
    }

    // アイコンバー
    Widget _iconBar(List<String> licenses) => Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        InkWell(
          onTap: () => _showSortModal(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _sortBy!.contains('Asc')
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 18,
                  color: AppColors.gray700,
                ),
                const SizedBox(width: 4),
                Text(
                  _sortLabels[_sortBy]!,
                  style:
                  const TextStyle(fontSize: 13, color: AppColors.gray900),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _showFilterModal(context),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1.0),
            ),
            child: const Icon(Icons.filter_alt_outlined,
                size: 18, color: AppColors.gray600),
          ),
        ),
      ]),
    );

    // フィルタリング
    var items = _folderItems.where((item) {
      final lic = (item.folderDoc['licenseName'] ?? '') as String;
      if (_licenseFilter != null && lic != _licenseFilter) return false;
      final isOfficialVal = item.folderDoc['isOfficial'] ?? false;
      if (_officialFilter != null && isOfficialVal != _officialFilter) {
        return false;
      }
      return true;
    }).toList();

    // ソート
    items.sort((a, b) {
      switch (_sortBy) {
        case 'correctRateAsc':
          return a.rate.compareTo(b.rate);
        case 'correctRateDesc':
          return b.rate.compareTo(a.rate);
        case 'nameAsc':
          return (a.folderDoc['name'] ?? '')
              .compareTo(b.folderDoc['name'] ?? '');
        case 'nameDesc':
          return (b.folderDoc['name'] ?? '')
              .compareTo(a.folderDoc['name'] ?? '');
        default:
          return 0;
      }
    });

    // グループ化
    final groups = <String, List<FolderItem>>{};
    for (var item in items) {
      final key = (item.folderDoc['licenseName'] ?? '') as String;
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedEntries = groups.entries.toList()
      ..sort((a, b) {
        if (a.key.isEmpty && b.key.isEmpty) return 0;
        if (a.key.isEmpty) return 1;
        if (b.key.isEmpty) return -1;
        return a.key.compareTo(b.key);
      });

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _iconBar(_selectedLicenseNames),
            ),
          ),
          ...sortedEntries.map((entry) {
            final lic = entry.key.isEmpty ? 'その他' : entry.key;
            final list = entry.value;
            final isCollapsed = _collapsed.contains(lic);

            return SliverStickyHeader(
              header: Material(
                color: Colors.white,
                child: InkWell(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () => setState(() {
                    isCollapsed ? _collapsed.remove(lic) : _collapsed.add(lic);
                    _saveCollapsed(); // ← 追加：開閉状態を保存
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isCollapsed
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppColors.gray700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lic,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
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
                    final item = list[i];
                    final doc = item.folderDoc;
                    final qCount = doc['questionCount'] as int;

                    // role → 権限判定
                    final role = _folderRoles[doc.id] ?? 'none';
                    final bool editable = role == 'owner' || role == 'editor';

                    return AnimatedSize(
                      key: _getItemKey(doc.id), // ← 追加：各行にキー付与（見た目は不変）
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isCollapsed
                          ? const SizedBox.shrink()
                          : ReusableProgressCard(
                        key: ValueKey(doc
                            .id), // ← 追加：行自体にも安定キーを付与し差分描画を助ける
                        iconData: Icons.folder_outlined,
                        iconColor: Colors.white,
                        iconBgColor: Colors.blue[700]!,
                        title: doc['name'] as String,
                        memoryLevels: item.memoryLevels,
                        correctAnswers: item.correct,
                        totalAnswers: item.total,
                        count: qCount,
                        countSuffix: ' 問',
                        onTap: () => _navigateToQuestionSetsListPage(
                            context, doc),
                        onMorePressed: () =>
                            _showFolderOptionsModal(context, doc),
                        selectionMode: false,
                        cardId: doc.id,
                        selectedId: null,
                        onSelected: null,
                        hasPermission: editable, // ← グレー表示用
                      ),
                    );
                  },
                  childCount: list.length,
                ),
              ),
            );
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  /* ──────────────────────────────────────────
   * Sort / Filter モーダル
   * ────────────────────────────────────────── */
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
            _buildRadio('正答率（昇順）', 'correctRateAsc', setModalState),
            _buildRadio('正答率（降順）', 'correctRateDesc', setModalState),
            _buildRadio('フォルダ名（昇順）', 'nameAsc', setModalState),
            _buildRadio('フォルダ名（降順）', 'nameDesc', setModalState),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(
      String label, String value, void Function(void Function()) setModal) {
    return RadioListTile<String>(
      activeColor: AppColors.blue500,
      title: Text(label),
      value: value,
      groupValue: _sortBy,
      onChanged: (v) {
        if (v == null) return;
        setState(() => _sortBy = v);
        setModal(() => _sortBy = v);
        _savePrefs(); // ← 追加：並び順保存
        Navigator.pop(context);
      },
    );
  }

  void _showFilterModal(BuildContext context) {
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
            const SizedBox(height: 8),
            _buildFilterRadio('全て', null, setModalState),
            _buildFilterRadio('公式問題のみ', true, setModalState),
            _buildFilterRadio('自作のみ', false, setModalState),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRadio(
      String label, bool? value, void Function(void Function()) setModal) {
    return RadioListTile<bool?>(
      activeColor: AppColors.blue500,
      title: Text(label),
      value: value,
      groupValue: _officialFilter,
      onChanged: (v) {
        setState(() => _officialFilter = v);
        setModal(() => _officialFilter = v);
        _savePrefs(); // ← 追加：フィルター保存
        Navigator.pop(context);
      },
    );
  }

  /* ──────────────────────────────────────────
   * フォルダ操作モーダル
   *   ・削除確認を DeleteConfirmationDialog へ変更
   *   ・その他の挙動・UI は一切変更していません
   * ────────────────────────────────────────── */
  Future<void> _showFolderOptionsModal(
      BuildContext context, DocumentSnapshot folder) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ログインしてください。')));
      }
      return;
    }

    /* --- パーミッション取得（無ければ none） --- */
    String role = 'none';
    final permSnap = await folder.reference
        .collection('permissions')
        .where('userRef',
        isEqualTo: FirebaseFirestore.instance.collection('users').doc(uid))
        .limit(1)
        .get();
    if (permSnap.docs.isNotEmpty) {
      role = (permSnap.docs.first.data()['role'] ?? 'none') as String;
    }
    final bool canEdit = role == 'owner' || role == 'editor';

    /* --- ReusableProgressCard と同じ色ロジック --- */
    final Color iconColor = Colors.white;
    final Color iconBgColor =
    canEdit ? Colors.blue[700]! : AppColors.gray500; // グレー版もやや濃いめ

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: canEdit ? 352 : 240,
          child: Column(
            children: [
              /* --- ドラッグハンドル --- */
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
              /* --- タイトル --- */
              ListTile(
                leading: RoundedIconBox(
                  icon: Icons.folder_outlined,
                  iconColor: iconColor,
                  backgroundColor: iconBgColor,
                  borderRadius: 8,
                  size: 38,
                  iconSize: 22,
                ),
                title: Text(
                  folder['name'],
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.gray100),
              const SizedBox(height: 8),

              /* --- 編集可能メニュー --- */
              if (canEdit) ...[
                _folderModalTile(
                  icon: Icons.quiz_outlined,
                  text: '問題集の追加',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToQuestionSetsAddPage(context, folder);
                  },
                ),
                const SizedBox(height: 8),
                _folderModalTile(
                  icon: Icons.edit_outlined,
                  text: 'フォルダ名の編集',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToFolderEditPage(context, folder);
                  },
                ),
                const SizedBox(height: 8),
              ],

              /* --- 学習履歴クリア --- */
              _folderModalTile(
                icon: Icons.restart_alt,
                text: '学習履歴をクリア',
                onTap: () async {
                  Navigator.pop(context);
                  final res = await DeleteConfirmationDialog.show(
                    context,
                    title: '学習履歴をクリア',
                    bulletPoints: const ['フォルダの記憶度', 'フォルダの正答率'],
                    description:
                    '下記の項目を初期化します。\nこのフォルダ配下の問題集の学習履歴は保持されます。',
                    confirmText: 'クリア',
                    cancelText: '戻る',
                  );
                  if (res != null && res.confirmed) {
                    await _clearFolderStudyRecords(context, folder);
                  }
                },
              ),

              /* --- 削除（DeleteConfirmationDialog 版） --- */
              if (canEdit) ...[
                const SizedBox(height: 8),
                _folderModalTile(
                  icon: Icons.delete_outline,
                  text: 'フォルダの削除',
                  onTap: () async {
                    Navigator.pop(context); // まずオプションモーダルを閉じる
                    final res = await DeleteConfirmationDialog.show(
                      context,
                      title: 'フォルダを削除',
                      bulletPoints: const ['フォルダ', '配下の問題集', '配下の問題'],
                      description:
                      'フォルダ配下の問題集および問題も削除されます。\nこの操作は取り消しできません。',
                      confirmText: '削除',
                      cancelText: '戻る',
                      confirmColor: Colors.redAccent,
                    );
                    if (res != null && res.confirmed) {
                      await _softDeleteFolder(folder);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ListTile _folderModalTile({
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

  /* ──────────────────────────────────────────
   * 学習履歴クリア
   * ────────────────────────────────────────── */
  Future<void> _clearFolderStudyRecords(
      BuildContext context, DocumentSnapshot folder) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1) フォルダ自身
      batch.set(
        folder.reference.collection('folderSetUserStats').doc(uid),
        {
          'memoryLevels': <String, String>{},
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // lastStudiedAt を保持
      );

      // 2) 配下の問題集
      final qsSnap = await firestore
          .collection('questionSets')
          .where('folderRef', isEqualTo: folder.reference)
          .where('isDeleted', isEqualTo: false)
          .get();

      for (final qs in qsSnap.docs) {
        batch.set(
          qs.reference.collection('questionSetUserStats').doc(uid),
          {
            'memoryLevels': <String, String>{},
            'attemptCount': 0,
            'correctCount': 0,
            'incorrectCount': 0,
            'memoryLevelStats': {
              'again': 0,
              'hard': 0,
              'good': 0,
              'easy': 0
            },
            'memoryLevelRatios': {
              'again': 0,
              'hard': 0,
              'good': 0,
              'easy': 0
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true), // lastStudiedAt を保持
        );
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('学習履歴をクリアしました。')));
        await fetchFirebaseData(); // 既存挙動：全体更新
      }
    } catch (e, st) {
      debugPrint('clearFolderStudyRecords error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('エラーが発生しました')));
      }
    }
  }

  /* ──────────────────────────────────────────
   * フォルダ削除（soft delete）
   * ────────────────────────────────────────── */
  Future<void> _softDeleteFolder(DocumentSnapshot folder) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final deletedAt = FieldValue.serverTimestamp();

    // フォルダ
    batch.update(folder.reference, {'isDeleted': true, 'deletedAt': deletedAt});

    // 配下の問題集 & 問題
    final qsSnap = await firestore
        .collection('questionSets')
        .where('folderRef', isEqualTo: folder.reference)
        .get();
    for (var qs in qsSnap.docs) {
      batch.update(qs.reference, {'isDeleted': true, 'deletedAt': deletedAt});
      final qSnap = await firestore
          .collection('questions')
          .where('questionSetRef', isEqualTo: qs.reference)
          .get();
      for (var q in qSnap.docs) {
        batch.update(q.reference, {'isDeleted': true, 'deletedAt': deletedAt});
      }
    }
    await batch.commit();
    await fetchFirebaseData(); // 既存挙動：全体更新
  }

  /* ──────────────────────────────────────────
   * AutomaticKeepAliveClientMixin
   * ────────────────────────────────────────── */
  @override
  bool get wantKeepAlive => true;
}
