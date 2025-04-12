import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/folder_edit_page.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_list_page.dart';
import 'package:repaso/study_set_add_page.dart' as AddPage; // 新しい暗記セット用
import 'package:repaso/study_set_answer_page.dart';
import 'package:repaso/study_set_edit_page.dart' as EditPage; // 既存暗記セット編集用
import 'package:repaso/widgets/list_page_widgets/memory_level_progress_bar.dart';
import 'package:repaso/widgets/answer_page_widgets/question_rate_display.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'package:rxdart/rxdart.dart';
import 'utils/app_colors.dart';
import 'folder_add_page.dart';
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
                    maxLines: 2,
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
                    maxLines: 2,
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

    // 1) ログイン中ユーザーがアクセス権を持つフォルダの permissions を監視
    final folderPermissionsStream = FirebaseFirestore.instance
        .collectionGroup('permissions')
        .where('userRef',
        isEqualTo: FirebaseFirestore.instance.collection('users').doc(user.uid))
        .where('role', whereIn: ['owner', 'editor', 'viewer'])
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: folderPermissionsStream,
      builder: (context, permissionsSnapshot) {
        if (permissionsSnapshot.hasError) {
          print('Error in folderPermissionsStream: ${permissionsSnapshot.error}');
          return Center(
              child: Text('エラーが発生しました: ${permissionsSnapshot.error}'));
        }
        if (!permissionsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final permissionsDocs = permissionsSnapshot.data!.docs;
        if (permissionsDocs.isEmpty) {
          return const Center(child: Text('フォルダがありません'));
        }

        // 2) 各 permission ドキュメントから親フォルダの参照を取得し、そのスナップショットの Stream をリストに格納
        List<Stream<DocumentSnapshot>> folderStreams = [];
        for (var permission in permissionsDocs) {
          final folderRef = permission.reference.parent.parent;
          if (folderRef != null) {
            folderStreams.add(folderRef.snapshots());
          }
        }

        // CombineLatestStreamで全てのフォルダのスナップショットを一括で監視
        return StreamBuilder<List<DocumentSnapshot>>(
          stream: CombineLatestStream.list(folderStreams),
          builder: (context, folderSnapshots) {
            if (folderSnapshots.hasError) {
              print('Error in combined folder stream: ${folderSnapshots.error}');
              return Center(child: Text('エラー: ${folderSnapshots.error}'));
            }
            if (!folderSnapshots.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            List<DocumentSnapshot> folders = folderSnapshots.data!;

            // 削除済みのフォルダを除外
            folders = folders.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              return !(data['isDeleted'] ?? false);
            }).toList();

            // フォルダ名で昇順ソート
            folders.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};
              final aName = aData['name'] ?? '';
              final bName = bData['name'] ?? '';
              return aName.compareTo(bName);
            });

            // ソート結果の確認用print
            print("Sorted Folders:");
            for (var folder in folders) {
              final data = folder.data() as Map<String, dynamic>? ?? {};
              print(data['name']);
            }

            return ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folderDoc = folders[index];
                final folderData = folderDoc.data() as Map<String, dynamic>? ?? {};
                final folderName = folderData['name'] ?? '未設定';
                final questionCount = folderData['questionCount'] ?? 0;
                final isPublic = folderData['isPublic'] ?? false;

                // --- フォルダユーザーステータスも購読 ---
                final folderUserStatsStream = folderDoc.reference
                    .collection('folderSetUserStats')
                    .doc(user.uid)
                    .snapshots();

                return StreamBuilder<DocumentSnapshot>(
                  stream: folderUserStatsStream,
                  builder: (context, userStatsSnapshot) {
                    if (userStatsSnapshot.hasError) {
                      print('Error in folderSetUserStats: ${userStatsSnapshot.error}');
                      return Text('エラー: ${userStatsSnapshot.error}');
                    }

                    // メモリーレベルの初期値
                    Map<String, int> memoryLevels = {
                      'easy': 0,
                      'good': 0,
                      'hard': 0,
                      'again': 0,
                    };

                    // folderSetUserStats のデータがある場合は上書き
                    if (userStatsSnapshot.hasData && userStatsSnapshot.data!.exists) {
                      final userStatsData =
                          userStatsSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final memoryData =
                          userStatsData['memoryLevels'] as Map<String, dynamic>? ?? {};

                      // 各問題のメモリレベルをカウント
                      memoryData.forEach((questionId, level) {
                        if (memoryLevels.containsKey(level)) {
                          memoryLevels[level] = memoryLevels[level]! + 1;
                        }
                      });
                    }

                    // **正答数の計算 (hard, good, easy の合計)**
                    final correctAnswers = (memoryLevels['easy'] ?? 0) +
                        (memoryLevels['good'] ?? 0) +
                        (memoryLevels['hard'] ?? 0);

                    final totalAnswers = (memoryLevels['easy'] ?? 0) +
                        (memoryLevels['good'] ?? 0) +
                        (memoryLevels['hard'] ?? 0) +
                        (memoryLevels['again'] ?? 0);

                    // **未回答数の計算**
                    final unanswered = (questionCount > correctAnswers)
                        ? (questionCount - correctAnswers)
                        : 0;

                    // 未回答を memoryLevels に追加
                    memoryLevels['unanswered'] = unanswered;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        child: InkWell(
                          onTap: () {
                            // フォルダをタップしたときの遷移
                            navigateToQuestionSetsListPage(folderDoc);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0, left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // タイトル行
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Stack(
                                      children: [
                                        RoundedIconBox(
                                          icon: Icons.folder_outlined,
                                          iconColor: AppColors.blue500,
                                          backgroundColor: AppColors.blue100,
                                        ),
                                        if (isPublic)
                                          Positioned(
                                            bottom: 1,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(1.0),
                                              child: const Icon(
                                                Icons.verified,
                                                size: 12,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        folderName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                                      onPressed: () {
                                        // フォルダ操作用モーダル
                                        showFolderOptionsModal(context, folderDoc);
                                      },
                                    ),
                                  ],
                                ),
                                // **正答率表示**
                                QuestionRateDisplay(
                                  top: correctAnswers,   // 正答数
                                  bottom: totalAnswers, // 総問題数（フォルダの questionCount）
                                  memoryLevels: memoryLevels,
                                  count: questionCount,
                                  countSuffix: ' 問',
                                ),
                                const SizedBox(height: 2),
                                // **メモリーレベルのプログレスバー**
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: MemoryLevelProgressBar(memoryValues: memoryLevels),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
    if (user == null) {
      return const Center(child: Text('ログインしてください'));
    }

    final studySetsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('studySets')
        .where('isDeleted', isEqualTo: false) // 削除されていないもののみ表示
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: studySetsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final studySets = snapshot.data?.docs ?? [];

        if (studySets.isEmpty) {
          return const Center(child: Text('暗記セットがありません'));
        }

        return ListView.builder(
          itemCount: studySets.length,
          itemBuilder: (context, index) {
            final studySetDoc = studySets[index];
            final studySetData = studySetDoc.data() as Map<String, dynamic>? ?? {};

            final Map<String, dynamic> memoryLevelStats =
                studySetData['memoryLevelStats'] as Map<String, dynamic>? ?? {};

            // 各記憶レベルのカウント（null の場合は 0 にする）
            final int againCount = (memoryLevelStats['again'] ?? 0) as int;
            final int hardCount = (memoryLevelStats['hard'] ?? 0) as int;
            final int goodCount = (memoryLevelStats['good'] ?? 0) as int;
            final int easyCount = (memoryLevelStats['easy'] ?? 0) as int;

            // **分子（正答数）: hard + good + easy の合計**
            final int correctAnswers = hardCount + goodCount + easyCount;

            // **分母（総回答数）: memoryLevelStats の合計**
            final int totalAnswers = againCount + hardCount + goodCount + easyCount;

            // **総試行回数（countとして表示）**
            final int totalAttemptCount = studySetData['totalAttemptCount'] ?? 0;

            // **未回答数**
            final int unanswered = totalAttemptCount > totalAnswers
                ? totalAttemptCount - totalAnswers
                : 0;

            // **メモリーレベルのマップ**
            final Map<String, int> memoryLevels = {
              'again': againCount,
              'hard': hardCount,
              'good': goodCount,
              'easy': easyCount,
              'unanswered': unanswered,
            };

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
              child: Card(
                color: Colors.white,
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    final studySetId = studySetDoc.id;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudySetAnswerPage(
                          studySetId: studySetId,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0, left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // タイトル行
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const RoundedIconBox(
                              icon: Icons.school_outlined, // フォルダアイコン
                              iconColor: AppColors.blue600, // アイコンの色
                              backgroundColor: AppColors.blue100,
                              iconSize: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                studySetData['name'] ?? '未設定',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gray700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                              onPressed: () {
                                showStudySetOptionsModal(context, studySetDoc);
                              },
                            ),
                          ],
                        ),

                        // **正答率表示**
                        QuestionRateDisplay(
                          top: correctAnswers,   // 正答数（hard + good + easy）
                          bottom: totalAnswers,  // 総回答数（memoryLevelStats の合計）
                          memoryLevels: memoryLevels,
                          count: totalAttemptCount, // 総試行回数
                          countSuffix: ' 回',      // 回数の単位
                        ),
                        const SizedBox(height: 2),

                        // **メモリーレベルのプログレスバー**
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: MemoryLevelProgressBar(memoryValues: memoryLevels),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
          title: Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ホーム'),
                Row(
                  children: [
                    AvailableLikesWidget(),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.notifications_none_outlined,
                      color: AppColors.gray700,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.blue700,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            unselectedLabelColor: AppColors.gray900,
            labelStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 16),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.blue400, width: 4),
              insets: EdgeInsets.symmetric(horizontal: -32.0),
            ),
            tabs: const [
              Tab(text: 'フォルダ'),
              Tab(text: '暗記セット'),
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
            child: const Icon(Icons.add, color: Colors.white, size: 40),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class AvailableLikesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox(); // 未ログインなら何も表示しない

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final int availableLikes = (userData['availableLikes'] ?? 0).toInt(); // 存在しない場合は 0

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // 内側の余白
          decoration: BoxDecoration(
            color: Colors.white, // 背景色を白に
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハートアイコン部分
              const Icon(
                Icons.favorite,
                color: Colors.red, // アイコンの色
                size: 22, // サイズ調整
              ),
              const SizedBox(width: 6), // アイコンと数値の間隔

              // いいねの数（0 でも表示）
              Text(
                '$availableLikes',
                style: const TextStyle(
                  color: Colors.red, // 文字の色
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}