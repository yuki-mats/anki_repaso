import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/folder_edit_page.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_list_page.dart';
import 'package:repaso/study_set_add_page.dart' as AddPage; // 新しい学習セット用
import 'package:repaso/study_set_answer_page.dart';
import 'package:repaso/study_set_edit_page.dart' as EditPage; // 既存学習セット編集用
import 'app_colors.dart';
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

        // 学習セットデータを取得
        final studySetSnapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("studySets")
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
        builder: (context) => QuestionSetsAddPage(folderRef: folder.reference),
      ),
    );
  }

  void navigateToQuestionSetsListPage(DocumentSnapshot folder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsListPage(folder: folder),
      ),
    );

    print('QuestionSetsListPageからの戻り値: $result');

    if (result == true) {
      print('FolderListPageのfetchFirebaseData()を実行します');
      if (mounted) {
        fetchFirebaseData();
      } else {
        print('FolderListPageが破棄されているため、fetchFirebaseData()をスキップ');
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

  // --- 学習セット追加 ---
  void navigateToAddStudySetPage(BuildContext context) async {
    final studySet = AddPage.StudySet(
      name: '',
      questionSetIds: [],
      numberOfQuestions: 10,
      selectedQuestionOrder: 'random',
      correctRateRange: const RangeValues(0, 100),
      isFlagged: false,
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

  // --- 学習セット編集 ---
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
          folderRef: folder.reference,
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
        .where('userRef', isEqualTo: FirebaseFirestore.instance.collection('users').doc(user.uid))
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
          child: Container(
            height: 220,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    size: 32,
                    color: AppColors.blue500,
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
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 学習セット削除 ---
  Future<void> deleteStudySet(BuildContext context, DocumentSnapshot studySetDoc) async {
    try {
      await studySetDoc.reference.delete();

      // Navigator.pop() を実行した後に context を遅延して使用
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('学習セットを削除しました')),
          );
        }
      });

      // 画面を更新する処理
      if (mounted) {
        setState(() {
          fetchFirebaseData();
        });
      }
    } catch (e) {
      print("Error deleting study set: $e");

      // 例外処理に遅延を適用
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除に失敗しました')),
          );
        }
      });
    }
  }


  // --- 学習セット操作用モーダル ---
  void showStudySetOptionsModal(BuildContext context, DocumentSnapshot studySetDoc) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください。')),
      );
      return;
    }

    final studySetId = studySetDoc.id;
    final initialStudySet = EditPage.StudySet(
      id: studySetDoc.id,
      name: studySetDoc['name'] ?? '未設定',
      questionSetIds: List<String>.from(studySetDoc['questionSetIds'] ?? []),
      numberOfQuestions: studySetDoc['numberOfQuestions'] ?? 0,
      selectedQuestionOrder: studySetDoc['selectedQuestionOrder'] ?? 'random',
      correctRateRange: RangeValues(
        (studySetDoc['correctRateRange']?['start'] ?? 0).toDouble(),
        (studySetDoc['correctRateRange']?['end'] ?? 100).toDouble(),
      ),
      isFlagged: studySetDoc['isFlagged'] ?? false,
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
                  leading: Icon(
                    Icons.star,
                    size: 32,
                    color: AppColors.blue500,
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
                  title: const Text('学習セットの編集', style: TextStyle(fontSize: 16)),
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
                  title: const Text('学習セットの削除', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // 確認ダイアログを表示し、削除実行
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('削除確認'),
                        content: Text('${studySetDoc['name'] ?? '未設定'} を削除しますか？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除'),
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
        .where('userRef', isEqualTo: FirebaseFirestore.instance.collection('users').doc(user.uid))
        .where('role', whereIn: ['owner', 'editor', 'viewer'])
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: folderPermissionsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in folderPermissionsStream: ${snapshot.error}');
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final permissionsDocs = snapshot.data!.docs;
        if (permissionsDocs.isEmpty) {
          return const Center(child: Text('フォルダがありません'));
        }

        // 2) permissionsドキュメントから親フォルダの参照を取得し、それぞれを監視
        return ListView.builder(
          itemCount: permissionsDocs.length,
          itemBuilder: (context, index) {
            final permissionDoc = permissionsDocs[index];
            final folderRef = permissionDoc.reference.parent.parent; // 親のフォルダ参照
            if (folderRef == null) {
              return const SizedBox.shrink(); // 万一 null の場合は何も描画しない
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: folderRef.snapshots(),
              builder: (context, folderSnapshot) {
                if (folderSnapshot.hasError) {
                  print('Error in folderRef snapshots: ${folderSnapshot.error}');
                  return Text('エラー: ${folderSnapshot.error}');
                }
                if (!folderSnapshot.hasData || !folderSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                // 取得したフォルダドキュメント
                final folderDoc = folderSnapshot.data!;
                final folderData = folderDoc.data() as Map<String, dynamic>? ?? {};
                final folderName = folderData['name'] ?? '未設定';
                final questionCount = folderData['questionCount'] ?? 0;
                final isPublic = folderData['isPublic'] ?? false;

                // --- フォルダユーザーステータスも購読 ---
                final folderUserStatsStream = folderRef
                    .collection('folderSetUserStats')
                    .doc(user.uid)
                    .snapshots();

                // 2段階目の StreamBuilder
                return StreamBuilder<DocumentSnapshot>(
                  stream: folderUserStatsStream,
                  builder: (context, userStatsSnapshot) {
                    if (userStatsSnapshot.hasError) {
                      print('Error in folderSetUserStats: ${userStatsSnapshot.error}');
                      return Text('エラー: ${userStatsSnapshot.error}');
                    }

                    // デフォルトのメモリレベルカウント
                    Map<String, int> memoryLevels = {
                      'easy': 0,
                      'good': 0,
                      'hard': 0,
                      'again': 0,
                    };

                    // folderSetUserStatsドキュメントが存在する場合は上書き
                    if (userStatsSnapshot.hasData && userStatsSnapshot.data!.exists) {
                      final userStatsData =
                          userStatsSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final memoryData =
                          userStatsData['memoryLevels'] as Map<String, dynamic>? ?? {};

                      // memoryLevels の集計
                      memoryData.forEach((questionId, level) {
                        if (memoryLevels.containsKey(level)) {
                          memoryLevels[level] = (memoryLevels[level] ?? 0) + 1;
                        }
                      });
                    }

                    // 合計回答数を計算 → 未回答 = questionCount - answered
                    final totalAnswered = memoryLevels.values.fold<int>(0, (a, b) => a + b);
                    final unanswered = (questionCount is int && questionCount > totalAnswered)
                        ? (questionCount - totalAnswered)
                        : 0;

                    // プログレスバー左→右のレベル順
                    final sortedMemoryLevels = ['again', 'hard', 'good', 'easy', 'unanswered'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: InkWell(
                          onTap: () {
                            // フォルダをタップしたときの遷移
                            navigateToQuestionSetsListPage(folderDoc);
                          },
                          borderRadius: BorderRadius.circular(8.0),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0, left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // タイトル行
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 24,
                                      color: isPublic ? Colors.amber : AppColors.blue500,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        folderName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    Text(
                                      '$questionCount',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray700,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                                      onPressed: () {
                                        // フォルダ操作用モーダル
                                        showFolderOptionsModal(context, folderDoc);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // プログレスバー（左: easy -> good -> hard -> again -> unanswered）
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2.0),
                                    child: Row(
                                      children: sortedMemoryLevels.map((level) {
                                        final flexValue = (level == 'unanswered')
                                            ? unanswered
                                            : (memoryLevels[level] ?? 0);

                                        return Expanded(
                                          flex: flexValue,
                                          child: Container(
                                            height: 8,
                                            color: _getMemoryLevelColor(level),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
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


// メモリーレベルに応じた色を返す関数
  Color _getMemoryLevelColor(String level) {
    switch (level) {
      case 'unanswered':
        return Colors.grey[300]!;  // 未回答（グレー）
      case 'again':
        return Colors.red[300]!;   // 間違えた問題（赤）
      case 'hard':
        return Colors.orange[300]!; // 難しい問題（オレンジ）
      case 'good':
        return Colors.green[300]!;  // 良好（緑）
      case 'easy':
        return Colors.blue[300]!;   // 簡単（青）
      default:
        return Colors.grey;
    }
  }

// --- 学習セット一覧表示 ---
  Widget buildStudySetList() {
    if (studySets.isEmpty) {
      return Center(child: Text('学習セットがありません'));
    }
    return ListView.builder(
      itemCount: studySets.length,
      itemBuilder: (context, index) {
        final studySet = studySets[index];
        final numberOfQuestions = studySet['numberOfQuestions'] ?? 0;
        final createdAt = DateTime.now();
        final updatedAt = DateTime.now();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Card(
            color: Colors.white,
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: InkWell(
              onTap: () {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ログインしてください。')),
                  );
                  return;
                }

                final studySetId = studySet.id; // Firestore ドキュメント ID
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudySetAnswerPage(
                      studySetId: studySetId,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0, left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Icon(
                            Icons.star_border,
                            size: 24,
                            color: AppColors.blue500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            studySet['name'] ?? '未設定',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          '$numberOfQuestions',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                          onPressed: () {
                            showStudySetOptionsModal(context, studySet);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          '作成日:',
                          style: TextStyle(fontSize: 14, color: AppColors.gray500),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14, color: AppColors.gray700),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '更新日:',
                          style: TextStyle(fontSize: 14, color: AppColors.gray500),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${updatedAt.year}/${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14, color: AppColors.gray700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                Icon(
                  Icons.notifications_none_outlined,
                  color: AppColors.gray700,
                  size: 24,
                ),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.blue700,
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
              Tab(text: '学習セット'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: TabBarView(
            controller: _tabController,
            children: [
              buildFolderList(),
              buildStudySetList(),
            ],
          ),
        ),
        backgroundColor: AppColors.gray50,
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
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
