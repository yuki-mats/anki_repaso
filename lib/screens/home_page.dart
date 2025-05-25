import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repaso/screens/folder_edit_page.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/screens/question_set_list_page.dart';
import 'package:repaso/screens/study_set_answer_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/folder_add_page.dart';
import 'package:repaso/screens/study_set_edit_page.dart' as EditPage;
import 'package:repaso/screens/study_set_add_page.dart' as AddPage;
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import '../utils/app_colors.dart';
import '../widgets/list_page_widgets/folder_item.dart';
import '../widgets/list_page_widgets/reusable_progress_card.dart';
import '../main.dart';
import '../widgets/list_page_widgets/skeleton_card.dart';
import 'licensee_edit_page.dart';

class FolderListPage extends StatefulWidget {
  const FolderListPage({super.key, required this.title});
  final String title;

  @override
  State<FolderListPage> createState() => FolderListPageState();
}

class FolderListPageState extends State<FolderListPage> with SingleTickerProviderStateMixin {
  List<DocumentSnapshot> folders = [];
  List<DocumentSnapshot> studySets = [];
  late TabController _tabController;
  String? _licenseFilter;           // null = 全部
  bool?   _officialFilter;          // null = 全部, true だけ, false だけ
  final   Set<String> _collapsed = {};  // 折りたたみ状態保持
  String? _sortBy;
  late ScrollController _scrollController;
  bool _showIconBar = true;
  double _lastOffset = 0.0;
  List<FolderItem> _folderItems = [];
  List<String> _selectedLicenseNames = [];
  bool _isLoading = true;
  bool  _selectFolderMode = false;
  String? _selectedFolderId;
  bool _isPro = false;
  late final void Function(CustomerInfo) _customerInfoListener;

  // ソートラベルのマッピング
  final Map<String, String> _sortLabels = {
    'correctRateAsc': '正答率（昇順）',
    'correctRateDesc': '正答率（降順）',
    'attemptCount': '試行回数順',
    'nameAsc': 'フォルダ名（昇順）',
    'nameDesc': 'フォルダ名（降順）',
  };

  String? _studySortBy;
  final Map<String, String> _studySortLabels = {
    'attemptAsc'      : '試行回数（昇順）',
    'attemptDesc'     : '試行回数（降順）',
    'nameAsc'         : '暗記セット名（昇順）',
    'nameDesc'        : '暗記セット名（降順）',
    'correctRateAsc'  : '正答率（昇順）',
    'correctRateDesc' : '正答率（降順）',
  };

  /// 現在選択中のソート項目ラベルを取得
  String get _currentSortLabel => _sortLabels[_sortBy] ?? '並び替え';


  @override
  void initState() {
    super.initState();
    _sortBy = 'nameAsc';
    _studySortBy = 'attemptAsc';

    // スクロール検知用コントローラ
    _scrollController = ScrollController()
      ..addListener(() {
        final offset = _scrollController.offset;
        final delta = offset - _lastOffset;

        // トップに戻ったら必ず表示
        if (offset <= 0 && !_showIconBar) {
          setState(() => _showIconBar = true);

          // 20px以上スクロールダウンで非表示
        } else if (delta > 20 && _showIconBar) {
          setState(() => _showIconBar = false);

          // 10px以上スクロールアップで表示
        } else if (delta < -10 && !_showIconBar) {
          setState(() => _showIconBar = true);
        }

        _lastOffset = offset;
      });

    // Firebase からのデータ取得
    fetchFirebaseData();

    // キーボードを閉じる
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });

    // ATTトラッキング許可リクエスト
    requestTrackingPermission();

    // タブコントローラ初期化
    _tabController = TabController(length: 2, vsync: this);

    // 再度キーボード閉じ＆トラッキング許可（重複でも問題なし）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    requestTrackingPermission();

    // ── ★ RevenueCat の購読状態取得＋リスナー登録 ──

    // 1) 一度だけ現在の購読状態を取得
    Purchases.getCustomerInfo().then((info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      setState(() => _isPro = active);
    });

    // 2) 更新ごとに購読状態を反映するリスナーを定義
    _customerInfoListener = (CustomerInfo info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      if (_isPro != active) {
        setState(() => _isPro = active);
      }
    };

    // 3) リスナーを登録
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
    // ── ★ ここまで ──
  }



  @override
  void dispose() {
    // RevenueCat のリスナー解除
    Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);

    // タブコントローラ・スクロールコントローラ破棄
    _tabController.dispose();
    _scrollController.dispose();

    super.dispose();
  }


  Future<void> fetchFirebaseData() async {
    setState(() => _isLoading = true);

    try {
      /* 0) 認証 */
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final uid     = user.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      /* 1) 選択ライセンス */
      final userDoc  = await userRef.get();
      final licenses = List<String>.from(userDoc.data()?['selectedLicenseNames'] ?? []);
      setState(() => _selectedLicenseNames = licenses);

      /* 2) 公式フォルダ (30 件ずつ whereIn) */
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> officialFutures = [];
      if (licenses.isNotEmpty) {
        for (var i = 0; i < licenses.length; i += 30) {
          final chunk = licenses.sublist(
            i,
            i + 30 > licenses.length ? licenses.length : i + 30,
          );
          officialFutures.add(
            FirebaseFirestore.instance
                .collection('folders')
                .where('isOfficial',  isEqualTo: true)
                .where('licenseName', whereIn: chunk)
                .where('isDeleted',   isEqualTo: false)
                .get(),
          );
        }
      }

      /* 3) 権限フォルダ & 暗記セット */
      final permFuture  = FirebaseFirestore.instance
          .collectionGroup('permissions')
          .where('userRef', isEqualTo: userRef)
          .where('role',    whereIn: ['owner', 'editor', 'viewer'])
          .get();

      final studyFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('studySets')
          .where('isDeleted', isEqualTo: false)
          .get();

      /* 4) 並列実行 */
      final List<dynamic> results = await Future.wait([
        ...officialFutures,
        permFuture,
        studyFuture,
      ]);

      /* 5) 公式フォルダを結合 */
      final folderDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      int idx = 0;
      for (; idx < officialFutures.length; idx++) {
        final QuerySnapshot<Map<String, dynamic>> snap =
        results[idx] as QuerySnapshot<Map<String, dynamic>>;
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
          folderDocs[d.id] = d;
        }
      }

      /* 6) 権限フォルダを追加 */
      final QuerySnapshot<Map<String, dynamic>> permSnap =
      results[idx++] as QuerySnapshot<Map<String, dynamic>>;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> p in permSnap.docs) {
        final folderRef = p.reference.parent.parent;
        if (folderRef == null || folderDocs.containsKey(folderRef.id)) continue;

        final DocumentSnapshot<Map<String, dynamic>> folderSnap = await folderRef.get();
        if (!folderSnap.exists || (folderSnap.data()?['isDeleted'] ?? false)) continue;

        folderDocs[folderSnap.id] = folderSnap;
      }

      /* 7-A) フォルダ本体だけ先に UI へ */
      final placeholder = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
      final initialItems = folderDocs.values
          .map((doc) => FolderItem(folderDoc: doc, memoryLevels: placeholder))
          .toList();

      final QuerySnapshot<Map<String, dynamic>> studySnap =
      results.last as QuerySnapshot<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _folderItems = initialItems;
          studySets    = studySnap.docs;
          _isLoading   = false;   // スピナー停止
        });
      }

      /* 7-B) 記憶度をバックグラウンドで取得し上書き */
      Future<FolderItem> _withStats(DocumentSnapshot<Map<String, dynamic>> doc) async {
        final stat = await doc.reference
            .collection('folderSetUserStats')
            .doc(uid)
            .get();

        final mem = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
        if (stat.exists) {
          final ml = stat.data()?['memoryLevels'] as Map<String, dynamic>? ?? {};
          ml.forEach((_, lvl) {
            if (mem.containsKey(lvl)) mem[lvl] = mem[lvl]! + 1;
          });
        }
        return FolderItem(folderDoc: doc, memoryLevels: mem);
      }

      final updatedItems = await Future.wait(folderDocs.values.map(_withStats));
      if (mounted) {
        setState(() => _folderItems = updatedItems);
      }
    } catch (e, st) {
      debugPrint('fetchFirebaseData error: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- フォルダ関連遷移 ---
  void navigateToQuestionSetsAddPage(BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsAddPage(folderId: folder.id),
      ),
    );
  }

  void navigateToQuestionSetsListPage(DocumentSnapshot folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final permissionSnapshot = await folder.reference
          .collection('permissions')
          .where('userRef', isEqualTo: FirebaseFirestore.instance.collection('users').doc(user.uid))
          .get();

      String folderPermission = '';
      if (permissionSnapshot.docs.isNotEmpty) {
        folderPermission = permissionSnapshot.docs.first['role'];
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionSetsListPage(
            folder: folder,
            folderPermission: folderPermission, // 権限を渡す
          ),
        ),
      );

      // 戻り値の処理など
      if (result == true) {
        fetchFirebaseData();
      }
    }
  }

  Future<void> navigateToAddLicensePage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LicenseeEditPage(
          initialSelected: _selectedLicenseNames,
        ),
      ),
    );
    if (result is List<String>) {
      setState(() {
        _selectedLicenseNames = result;
      });
      fetchFirebaseData();
    }
  }

  void navigateToFolderAddPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FolderAddPage()),
    );

    if (result == true) {
      fetchFirebaseData();
    }
  }
// --- 暗記セット追加 ---
  void navigateToAddStudySetPage(BuildContext context) async {
    final studySet = AddPage.StudySet(
      name: '',
      questionSetIds: [],
      numberOfQuestions: 10,
      selectedQuestionOrder: 'random',
      correctRateRange: const RangeValues(0, 100),
      isFlagged: false,
      memoryLevelStats: {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      memoryLevelRatios: {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      totalAttemptCount: 0,
      studyStreakCount: 0,
      lastStudiedDate: "",
      selectedMemoryLevels: ['again', 'hard', 'good', 'easy'],
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPage.StudySetAddPage(studySet: studySet),
      ),
    );

    // 結果を確認してリストを更新
    if (result == true) {
      fetchFirebaseData(); // Firebaseデータを再取得してリストを更新
    }
  }


  // --- 暗記セット編集 ---
  void navigateToEditStudySetPage(BuildContext context, String userId, String studySetId, EditPage.StudySet initialStudySet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPage.StudySetEditPage(
          userId: userId,
          studySetId: studySetId,
          initialStudySet: initialStudySet,
        ),
      ),
    );

    // 結果を受け取ってリストを更新
    if (result == true) {
      fetchFirebaseData();
    }
  }

  // ── ★ 追加：共通の追加メニュー ──
  void _showAddOptionsModal(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft : Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 180,
            child: Column(
              children: [
                // ドラッグハンドル
                Center(
                  child: Container(
                    width : 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ──── ① フォルダ追加 ────
                ListTile(
                  leading: Container(
                    width : 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.folder_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title : const Text('フォルダを追加', style: TextStyle(fontSize: 16)),
                  onTap : () {
                    Navigator.pop(context);
                    navigateToFolderAddPage(context);
                  },
                ),
                const SizedBox(height: 8),
                // ──── ② 資格（ライセンス）追加 ────
                ListTile(
                  leading: Container(
                    width : 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.assignment_turned_in_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title : const Text('資格を登録', style: TextStyle(fontSize: 16)),
                  onTap : () {
                    Navigator.pop(context);
                    navigateToAddLicensePage(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  // --- フォルダ編集 ---
  void navigateToFolderEditPage(BuildContext context, DocumentSnapshot folder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderEditPage(
          initialFolderName: folder['name'],
          folderId: folder.id,
        ),
      ),
    );

    if (result == true) {
      fetchFirebaseData();
    }
  }

  // --- フォルダ操作用モーダル ---
  void showFolderOptionsModal(BuildContext context, DocumentSnapshot folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください。')),
      );
      return;
    }

    // ユーザーの権限を取得
    final permissionSnapshot = await folder.reference
        .collection('permissions')
        .where('userRef',
        isEqualTo: FirebaseFirestore.instance.collection('users').doc(user.uid))
        .get();

    if (permissionSnapshot.docs.isNotEmpty) {
      final role = permissionSnapshot.docs.first['role'];

      if (role == 'viewer') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('編集権限がありません。')),
        );
        return;
      }
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          // 高さを項目数に合わせて調整（今回は 280 に設定）
          child: Container(
            height: 280,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0),
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
                  leading: const RoundedIconBox(
                    icon: Icons.folder_outlined, // フォルダアイコン
                    iconColor: AppColors.blue500, // アイコンの色
                    backgroundColor: AppColors.blue100,
                    borderRadius: 8,
                    size: 38,
                    iconSize: 22,
                  ),
                  title: Text(
                    folder['name'],
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.gray100),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.quiz_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('問題集の追加', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToQuestionSetsAddPage(context, folder);
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
                    child: const Icon(Icons.edit_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('フォルダ名の編集', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToFolderEditPage(context, folder);
                  },
                ),
                const SizedBox(height: 8),
                // ↓ フォルダ削除オプションを追加 ↓
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('フォルダの削除', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // 削除確認ダイアログを表示
                    bool? confirmDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                        title: const Text(
                          '本当に削除しますか？',
                          style: TextStyle(color: Colors.black87, fontSize: 18),
                        ),
                        content: const Text('フォルダの配下の問題集および問題も削除されます。この操作は取り消しできません。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('戻る', style: TextStyle(color: Colors.black87)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmDelete == true) {
                      FirebaseFirestore firestore = FirebaseFirestore.instance;
                      WriteBatch batch = firestore.batch();
                      final deletedAt = FieldValue.serverTimestamp();

                      // フォルダ自体をソフトデリート
                      batch.update(folder.reference, {
                        'isDeleted': true,
                        'deletedAt': deletedAt,
                      });

                      // フォルダ内の問題集を取得し、ソフトデリート
                      QuerySnapshot qsSnapshot = await firestore
                          .collection('questionSets')
                          .where('folderRef', isEqualTo: folder.reference)
                          .get();
                      for (var qsDoc in qsSnapshot.docs) {
                        batch.update(qsDoc.reference, {
                          'isDeleted': true,
                          'deletedAt': deletedAt,
                        });
                        // 各問題集に紐づく問題もソフトデリート
                        QuerySnapshot questionsSnapshot = await firestore
                            .collection('questions')
                            .where('questionSetRef', isEqualTo: qsDoc.reference)
                            .get();
                        for (var questionDoc in questionsSnapshot.docs) {
                          batch.update(questionDoc.reference, {
                            'isDeleted': true,
                            'deletedAt': deletedAt,
                          });
                        }
                      }

                      await batch.commit();

                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> deleteStudySet(BuildContext context, DocumentSnapshot studySetDoc) async {
    try {
      // studySet ドキュメントをソフトデリートする（isDeleted を true に更新）
      await studySetDoc.reference.update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(), // 必要に応じて削除日時も記録
      });

      // UI を更新
      if (mounted) {
        setState(() {
          fetchFirebaseData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暗記セットが削除されました')),
        );
      }
    } catch (e) {
      print("Error deleting study set: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました')),
        );
      }
    }
  }


  // --- 暗記セット操作用モーダル ---
  void showStudySetOptionsModal(BuildContext context, DocumentSnapshot studySetDoc) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください。')),
      );
      return;
    }

    final studySetId = studySetDoc.id;
    final data = studySetDoc.data() as Map<String, dynamic>? ?? {};

    final initialStudySet = EditPage.StudySet(
      id: studySetDoc.id,
      name: data['name'] ?? '未設定',
      questionSetIds: List<String>.from(data['questionSetIds'] ?? []),
      numberOfQuestions: data['numberOfQuestions'] ?? 0,
      selectedQuestionOrder: data['selectedQuestionOrder'] ?? 'random',
      correctRateRange: RangeValues(
        (data['correctRateRange']?['start'] ?? 0).toDouble(),
        (data['correctRateRange']?['end'] ?? 100).toDouble(),
      ),
      isFlagged: data['isFlagged'] ?? false,
      selectedMemoryLevels: data.containsKey('selectedMemoryLevels')
          ? List<String>.from(data['selectedMemoryLevels'])
          : ['again', 'hard', 'good', 'easy'],
    );

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 220,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0),
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
                  leading: const RoundedIconBox(
                    icon: Icons.school_outlined,
                    iconColor: AppColors.blue600,
                    backgroundColor: AppColors.blue100,
                    borderRadius: 8,
                    size: 34,
                    iconSize: 24,
                  ),
                  title: Text(
                    studySetDoc['name'] ?? '未設定',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.gray100),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('暗記セットの編集', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToEditStudySetPage(context, userId, studySetId, initialStudySet);
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
                    child: const Icon(Icons.delete_outline,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('暗記セットの削除', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // 確認ダイアログを表示し、削除実行
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                        ),
                        title: const Text('本当に削除しますか？',
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18))
                        ,
                        content: const Text('削除した暗記セットを復元することはできません。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('戻る', style: TextStyle(color: Colors.black87)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (shouldDelete == true) {
                      await deleteStudySet(context, studySetDoc);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Offerings?> _fetchOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Offerings取得エラー: $e');
      return null;
    }
  }

  /// 月額 Pro を購入
  Future<void> _purchaseMonthly(BuildContext context) async {
    final offerings = await _fetchOfferings();
    final pkg = offerings?.current?.monthly;
    if (pkg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入プランが見つかりません')),
      );
      return;
    }
    try {
      final result = await Purchases.purchasePackage(pkg);
      final isActive = result.entitlements.active['Pro']?.isActive ?? false;
      if (isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pro 購読が有効になりました！')),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('購入エラー: $e');
    }
  }

  Widget buildFolderList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインしてください'));
    }

    // ───────── アイコンバー用ヘルパー ─────────
    Widget _buildIconBar(List<String> allLicenses) => Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx2, setModalState) {
                    // ラジオボタン項目を返すヘルパー
                    Widget _buildSortOption(String label, String value) {
                      return RadioListTile<String>(
                        activeColor: AppColors.blue500,
                        title: Text(label),
                        value: value,
                        groupValue: _sortBy,
                        onChanged: (v) {
                          if (v == null) return;
                          // 外側とモーダル内の両方で更新
                          setState(() => _sortBy = v);
                          setModalState(() => _sortBy = v);
                          Navigator.pop(ctx);
                        },
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Center(
                            child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.gray200,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        _buildSortOption('正答率（昇順）', 'correctRateAsc'),
                        _buildSortOption('正答率（降順）', 'correctRateDesc'),
                        _buildSortOption('フォルダ名（昇順）','nameAsc'),
                        _buildSortOption('フォルダ名（降順）','nameDesc'),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Icon(
                    _sortBy == null
                        ? Icons.sort
                        : (_sortBy!.contains('Asc') ? Icons.arrow_upward : Icons.arrow_downward),
                    size: 18,
                    color: AppColors.gray700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentSortLabel,
                    style: const TextStyle(fontSize: 13, color: AppColors.gray900),
                  ),
                ],
              ),
            ),
          ),
          // ── 中央の空間 ──
          const Spacer(),
          // ── 右端：漏斗アイコン ──
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx2, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 上部のドラッグ用ハンドル
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        RadioListTile<bool?>(
                          activeColor: AppColors.blue500,
                          title: const Text('全て'),
                          value: null,
                          groupValue: _officialFilter,
                          onChanged: (v) {
                            setState(() => _officialFilter = v);
                            setModalState(() => _officialFilter = v);
                            Navigator.pop(ctx);
                          },
                        ),
                        RadioListTile<bool?>(
                          activeColor: AppColors.blue500,
                          title: const Text('公式問題のみ'),
                          value: true,
                          groupValue: _officialFilter,
                          onChanged: (v) {
                            setState(() => _officialFilter = v);
                            setModalState(() => _officialFilter = v);
                            Navigator.pop(ctx);
                          },
                        ),
                        RadioListTile<bool?>(
                          activeColor: AppColors.blue500,
                          title: const Text('自作のみ'),
                          value: false,
                          groupValue: _officialFilter,
                          onChanged: (v) {
                            setState(() => _officialFilter = v);
                            setModalState(() => _officialFilter = v);
                            Navigator.pop(ctx);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(3.0),      // 円の内側余白
              decoration: BoxDecoration(
                color: Colors.white,                   // 背景色
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gray200,            // 枠線の色
                  width: 1.0,                          // 枠線の太さ
                ),
              ),
              child: Icon(
                MdiIcons.filterOutline,
                size: 18,
                color: AppColors.gray600,
              ),
            ),
          ),
        ],
      ),
    );

    // ───────── ロード中はスケルトンスクリーン ─────────
    if (_isLoading) {
      final licenses = _folderItems
          .map((e) => (e.folderDoc['licenseName'] ?? '') as String)
          .toSet()
          .toList();

      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, __) => const SkeletonCard(),
                childCount: 5,
              ),
            ),
          ],
        ),
      );
    }

    // ───────── フォルダ一覧フィルタ＆ソート ─────────
    final licenses = _folderItems
        .map((e) => (e.folderDoc['licenseName'] ?? '') as String)
        .toSet()
        .toList();

    var items = _folderItems.where((item) {
      final lic = (item.folderDoc['licenseName'] ?? '') as String;
      if (_licenseFilter != null && lic != _licenseFilter) return false;
      final isOfficialVal = item.folderDoc['isOfficial'] ?? false;                // ★ 修正ポイント
      if (_officialFilter != null && isOfficialVal != _officialFilter) return false; // ★ 修正ポイント
      return true;
    }).toList();

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildIconBar(licenses),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: const Center(
                child: Text(
                  '該当フォルダがありません',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ───────── ソート ─────────
    switch (_sortBy) {
      case 'correctRateAsc':
        items.sort((a, b) => a.rate.compareTo(b.rate));
        break;
      case 'correctRateDesc':
        items.sort((a, b) => b.rate.compareTo(a.rate));
        break;
      case 'attemptCount':
        items.sort((a, b) {
          final aCount = a.folderDoc['questionCount'] as int;
          final bCount = b.folderDoc['questionCount'] as int;
          return bCount.compareTo(aCount);
        });
        break;
      case 'nameAsc':
        items.sort((a, b) {
          final aName = (a.folderDoc['name'] ?? '') as String;
          final bName = (b.folderDoc['name'] ?? '') as String;
          return aName.compareTo(bName);
        });
        break;
      case 'nameDesc':
        items.sort((a, b) {
          final aName = (a.folderDoc['name'] ?? '') as String;
          final bName = (b.folderDoc['name'] ?? '') as String;
          return bName.compareTo(aName);
        });
        break;
      default:
      // デフォルトの名称順（昇順）
        items.sort((a, b) {
          final aName = (a.folderDoc['name'] ?? '') as String;
          final bName = (b.folderDoc['name'] ?? '') as String;
          return aName.compareTo(bName);
        });
    }

    // ───────── グループ化 ─────────
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

    // ───────── UI描画 ─────────
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildIconBar(licenses),
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
                    isCollapsed
                        ? _collapsed.remove(lic)
                        : _collapsed.add(lic);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isCollapsed
                          ? const SizedBox.shrink()
                          : ReusableProgressCard(
                        iconData: Icons.folder_outlined,
                        iconColor: AppColors.blue500,
                        iconBgColor: AppColors.blue100,
                        title: doc['name'] as String,
                        isVerified: doc['isOfficial'] ?? false, // ★ 修正ポイント
                        memoryLevels: item.memoryLevels,
                        correctAnswers: item.correct,
                        totalAnswers: item.total,
                        count: qCount,
                        countSuffix: ' 問',
                        onTap: () => navigateToQuestionSetsListPage(doc),
                        onMorePressed: () => showFolderOptionsModal(context, doc),
                        selectionMode : false,
                        cardId        : doc.id,
                        selectedId    : null,
                        onSelected    : null,
                      ),
                    );
                  },
                  childCount: list.length,
                ),
              ),
            );
          }).toList(),
          SliverToBoxAdapter(
            child: const SizedBox(height: 100),
          ),
        ],
      ),
    );
  }


  Widget buildStudySetList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('ログインしてください'));

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
        if (docs.isEmpty) return const Center(
          child: Text(
            '暗記セットがまだありません',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        );

        // ───────── ソートバー ─────────
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx2, setModalState) {
                        Widget _buildSortOption(String label, String value) {
                          return RadioListTile<String>(
                            activeColor: AppColors.blue500,
                            title: Text(label),
                            value: value,
                            groupValue: _studySortBy,
                            onChanged: (v) {
                              if (v == null) return;
                              setState(()    => _studySortBy = v);
                              setModalState(() => _studySortBy = v);
                              Navigator.pop(ctx);
                            },
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            _buildSortOption('試行回数（昇順）', 'attemptAsc'),
                            _buildSortOption('試行回数（降順）', 'attemptDesc'),
                            _buildSortOption('暗記セット名（昇順）', 'nameAsc'),
                            _buildSortOption('暗記セット名（降順）', 'nameDesc'),
                            _buildSortOption('正答率（昇順）', 'correctRateAsc'),
                            _buildSortOption('正答率（降順）', 'correctRateDesc'),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(
                      _studySortBy!.contains('Asc')
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                      color: AppColors.gray700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _studySortLabels[_studySortBy]!,
                      style: const TextStyle(fontSize: 13, color: AppColors.gray900),
                    ),
                  ],
                ),
              ),
            ),

            // ───────── 並び替え後のリスト ─────────
            Expanded(
              child: Builder(
                builder: (_) {
                  final list = docs.toList();
                  list.sort((a, b) {
                    final da = a.data()! as Map<String, dynamic>;
                    final db = b.data()! as Map<String, dynamic>;
                    final aCount = da['totalAttemptCount'] as int? ?? 0;
                    final bCount = db['totalAttemptCount'] as int? ?? 0;
                    final statsA = da['memoryLevelStats'] as Map<String, dynamic>? ?? {};
                    final statsB = db['memoryLevelStats'] as Map<String, dynamic>? ?? {};
                    final correctA = (statsA['hard'] ?? 0) + (statsA['good'] ?? 0) + (statsA['easy'] ?? 0);
                    final correctB = (statsB['hard'] ?? 0) + (statsB['good'] ?? 0) + (statsB['easy'] ?? 0);
                    final rateA = aCount > 0 ? correctA / aCount : 0;
                    final rateB = bCount > 0 ? correctB / bCount : 0;
                    final nameA = (da['name'] ?? '') as String;
                    final nameB = (db['name'] ?? '') as String;

                    switch (_studySortBy) {
                      case 'attemptAsc':      return aCount.compareTo(bCount);
                      case 'attemptDesc':     return bCount.compareTo(aCount);
                      case 'nameAsc':         return nameA.compareTo(nameB);
                      case 'nameDesc':        return nameB.compareTo(nameA);
                      case 'correctRateAsc':  return rateA.compareTo(rateB);
                      case 'correctRateDesc': return rateB.compareTo(rateA);
                      default:                return 0;
                    }
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final doc = list[i];
                      final d = doc.data() as Map<String, dynamic>;
                      final stats = d['memoryLevelStats'] ?? {};
                      final again = stats['again'] ?? 0;
                      final hard  = stats['hard']  ?? 0;
                      final good  = stats['good']  ?? 0;
                      final easy  = stats['easy']  ?? 0;
                      final correct = hard + good + easy;
                      final total   = again + correct;
                      final attempts = d['totalAttemptCount'] ?? 0;
                      final unanswered = attempts > total ? attempts - total : 0;
                      final levels = <String, int>{
                        'again'     : again,
                        'hard'      : hard,
                        'good'      : good,
                        'easy'      : easy,
                        'unanswered': unanswered,
                      };

                      return ReusableProgressCard(
                        iconData       : Icons.school_outlined,
                        iconColor      : AppColors.blue600,
                        iconBgColor    : AppColors.blue100,
                        title          : d['name'] ?? '未設定',
                        isVerified     : false,
                        memoryLevels   : levels,
                        correctAnswers : correct,
                        totalAnswers   : total,
                        count          : attempts,
                        countSuffix    : ' 回',
                        selectionMode : false,
                        cardId        : doc.id,
                        selectedId    : null,
                        onSelected    : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudySetAnswerPage(studySetId: doc.id),
                            ),
                          );

                        },
                        onMorePressed: () => showStudySetOptionsModal(context, doc),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text('ログインしてください')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title),
              const Icon(
                Icons.notifications_none_outlined,
                color: AppColors.gray600,
                size: 23,
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFEEEEEE),
                    width: 0.1,
                  ),
                ),
              ),
              height: 32,
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 36),
                indicatorWeight: 2.5,
                indicatorColor: AppColors.blue500,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 16),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                tabs: const [
                  Tab(text: 'フォルダ'),
                  Tab(text: '暗記セット'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            buildFolderList(),
            buildStudySetList(),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
          child: FloatingActionButton(
            onPressed: () {
              if (_tabController.index == 0) {
                _showAddOptionsModal(context);
              } else if (_tabController.index == 1) {
                navigateToAddStudySetPage(context);
              }
            },
            backgroundColor: AppColors.blue500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 40),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

