import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/folder_edit_page.dart';
import 'package:repaso/screens/question_set_list_page.dart';
import 'package:repaso/screens/study_set_answer_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/folder_add_page.dart';
import 'package:repaso/screens/study_set_edit_page.dart' as EditPage;
import 'package:repaso/screens/study_set_add_page.dart' as AddPage;
import 'package:repaso/widgets/list_page_widgets/memory_level_progress_bar.dart';
import 'package:repaso/widgets/common_widgets/question_rate_display.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'package:rxdart/rxdart.dart';
import '../utils/app_colors.dart';
import '../widgets/list_page_widgets/reusable_progress_card.dart';
import 'main.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchFirebaseData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    requestTrackingPermission();
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void fetchFirebaseData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userId = user.uid;

        // Collection Group Query を使用して、ユーザーがアクセス可能なフォルダを取得
        final folderPermissionsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('permissions')
            .where('userRef', isEqualTo: FirebaseFirestore.instance.collection('users').doc(userId))
            .get();

        List<DocumentSnapshot> accessibleFolders = [];

        for (var permission in folderPermissionsSnapshot.docs) {
          final role = permission['role'];

          if (role == 'owner' || role == 'editor' || role == 'viewer') {
            // `permission.ref.parent.parent` を使用してフォルダのドキュメント参照を取得
            final folderRef = permission.reference.parent.parent;
            if (folderRef != null) {
              final folderSnapshot = await folderRef.get();
              if (folderSnapshot.exists) {
                accessibleFolders.add(folderSnapshot);
              }
            }
          }
        }

        // 暗記セットデータを取得
        final studySetSnapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("studySets")
            .where('isDeleted', isEqualTo: false)
            .get();

        setState(() {
          folders = accessibleFolders;
          studySets = studySetSnapshot.docs;
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
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

  Widget buildFolderList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインしてください'));
    }

    final folderPermissionsStream = FirebaseFirestore.instance
        .collectionGroup('permissions')
        .where('userRef',
        isEqualTo:
        FirebaseFirestore.instance.collection('users').doc(user.uid))
        .where('role', whereIn: ['owner', 'editor', 'viewer'])
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: folderPermissionsStream,
      builder: (context, permSnap) {
        if (permSnap.hasError) {
          return Center(child: Text('エラー: ${permSnap.error}'));
        }
        if (!permSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── 各フォルダ DocumentSnapshot の Stream を束ねる ──
        final streams = permSnap.data!.docs
            .map((p) => p.reference.parent.parent!.snapshots())
            .toList();

        // ← ここを追加：権限が一件もなければ即座にメッセージ表示
        if (streams.isEmpty) {
          return const Center(
            child: Text(
              'フォルダがまだありません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return StreamBuilder<List<DocumentSnapshot>>(
          stream: CombineLatestStream.list(streams),
          builder: (context, folderSnap) {
            if (!folderSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = folderSnap.data!
                .where((d) => !(d['isDeleted'] ?? false))
                .toList()
              ..sort((a, b) => (a['name'] ?? '').compareTo(a['name'] ?? ''));

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'フォルダがまだありません',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 80),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? '未設定';
                final qCount = data['questionCount'] ?? 0;
                final isPublic = data['isPublic'] ?? false;

                // ── ユーザー統計を取得 ──
                return StreamBuilder<DocumentSnapshot>(
                  stream: doc.reference
                      .collection('folderSetUserStats')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (ctx, statSnap) {
                    final base = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
                    if (statSnap.hasData && statSnap.data!.exists) {
                      final m = statSnap.data!['memoryLevels'] ?? {};
                      for (var v in m.values) {
                        if (base.containsKey(v)) base[v] = base[v]! + 1;
                      }
                    }
                    final correct =
                        base['easy']! + base['good']! + base['hard']!;
                    final total = correct + base['again']!;
                    base['unanswered'] =
                    qCount > correct ? qCount - correct : 0;

                    return ReusableProgressCard(
                      iconData: Icons.folder_outlined,
                      iconColor: AppColors.blue500,
                      iconBgColor: AppColors.blue100,
                      title: name,
                      isVerified: isPublic,
                      memoryLevels: base,
                      correctAnswers: correct,
                      totalAnswers: total,
                      count: qCount,
                      countSuffix: ' 問',
                      onTap: () => navigateToQuestionSetsListPage(doc),
                      onMorePressed: () =>
                          showFolderOptionsModal(context, doc),
                    );
                  },
                );
              },
            );
          },
        );
      },
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

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data() as Map<String, dynamic>;

            // ── メモリーレベル統計値を取得 ──
            final stats = d['memoryLevelStats'] ?? {};
            final again = stats['again'] ?? 0;
            final hard  = stats['hard']  ?? 0;
            final good  = stats['good']  ?? 0;
            final easy  = stats['easy']  ?? 0;

            final correct = hard + good + easy;
            final total   = again + correct;
            final attempts = d['totalAttemptCount'] ?? 0;
            final unanswered =
            attempts > total ? attempts - total : 0;

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
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ホーム',),
              Row(
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    color: AppColors.gray700,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.blue700,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            unselectedLabelColor: Colors.black54,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.blue700, width: 2),
              insets: EdgeInsets.symmetric(horizontal: 16.0),
            ),
            tabs: const [
              Tab(child: Center(child: Text('フォルダ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))),
              Tab(child: Center(child: Center(child: Text('暗記セット',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))))),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            buildFolderList(),
            buildStudySetList(),
          ],
        ),
        backgroundColor: Colors.white,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
          child: FloatingActionButton(
            onPressed: () {
              if (_tabController.index == 0) {
                navigateToFolderAddPage(context);
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

