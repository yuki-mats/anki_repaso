import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/folder_edit_page.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_list_page.dart';
import 'package:repaso/study_set_add_page.dart' as AddPage; // 新しい暗記セット用
import 'package:repaso/study_set_answer_page.dart';
import 'package:repaso/study_set_edit_page.dart' as EditPage; // 既存暗記セット編集用
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
                    Icons.school_outlined,
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
                      print(
                          'Error in folderSetUserStats: ${userStatsSnapshot.error}');
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
                    if (userStatsSnapshot.hasData &&
                        userStatsSnapshot.data!.exists) {
                      final userStatsData = userStatsSnapshot.data!.data()
                      as Map<String, dynamic>? ??
                          {};
                      final memoryData =
                          userStatsData['memoryLevels'] as Map<String, dynamic>? ??
                              {};

                      memoryData.forEach((questionId, level) {
                        if (memoryLevels.containsKey(level)) {
                          memoryLevels[level] =
                              (memoryLevels[level] ?? 0) + 1;
                        }
                      });
                    }

                    // 合計回答数を計算 → 未回答 = questionCount - answered
                    final totalAnswered =
                    memoryLevels.values.fold<int>(0, (a, b) => a + b);
                    final unanswered = (questionCount is int &&
                        questionCount > totalAnswered)
                        ? (questionCount - totalAnswered)
                        : 0;

                    // プログレスバー左→右のレベル順
                    final sortedMemoryLevels =
                    ['again', 'hard', 'good', 'easy', 'unanswered'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
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
                            padding: const EdgeInsets.only(
                                top: 8.0, bottom: 16.0, left: 16.0),
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
                                      color: isPublic
                                          ? Colors.amber
                                          : AppColors.blue500,
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
                                    IconButton(
                                      icon: const Icon(Icons.more_vert_rounded,
                                          color: Colors.grey),
                                      onPressed: () {
                                        // フォルダ操作用モーダル
                                        showFolderOptionsModal(context, folderDoc);
                                      },
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: Builder(
                                    builder: (context) {
                                      // 回答済み問題数が 0 の場合は正答率 0 とする
                                      double correctRate = totalAnswered > 0
                                          ? (((totalAnswered - memoryLevels['again']!) / totalAnswered) * 100)
                                          : 0;
                                      // 小数点第一位で四捨五入
                                      double roundedRate = (correctRate * 10).round() / 10;
                                      // 値が整数の場合は小数点以下を省略
                                      String correctRateStr = roundedRate == 0
                                          ? '0'
                                          : (roundedRate % 1 == 0 ? roundedRate.toStringAsFixed(0) : roundedRate.toStringAsFixed(1));
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // 正答率部分（固定幅コンテナ内で左寄せ）
                                          Container(
                                            width: 90, // 必要に応じて調整してください
                                            alignment: Alignment.centerLeft,
                                            child: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '正答率',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                                                  ),
                                                  TextSpan(
                                                    text: ' : ',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                                                  ),
                                                  TextSpan(
                                                    text: correctRateStr,
                                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                  ),
                                                  TextSpan(
                                                    text: ' %',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // 「/」部分を固定表示
                                          const Text(
                                            ' / ',
                                            style: TextStyle(fontSize: 12, color: Colors.black87),
                                          ),
                                          // 問題数部分（固定幅コンテナ内で右寄せ）
                                          Container(
                                            width: 50, // 必要に応じて調整してください
                                            alignment: Alignment.centerRight,
                                            child: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '$questionCount',
                                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                  ),
                                                  TextSpan(
                                                    text: ' 問',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Padding(
                                  padding:
                                  const EdgeInsets.only(right: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2.0),
                                    child: Row(
                                      children: sortedMemoryLevels.map((level) {
                                        final flexValue =
                                        (level == 'unanswered')
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

// --- 暗記セット一覧表示 ---
  Widget buildStudySetList() {
    if (studySets.isEmpty) {
      return Center(child: Text('暗記セットがありません'));
    }
    return ListView.builder(
      itemCount: studySets.length,
      itemBuilder: (context, index) {
        final studySet = studySets[index];
        final numberOfQuestions = studySet['numberOfQuestions'] ?? 0;

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
                    // タイトル行（暗記セット名など）
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Icon(
                            Icons.school_outlined,
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
                    // ▼ 修正後の memoryLevelRatios を元にしたプログレスバー ▼
                    Builder(builder: (context) {
                      // Firestoreからの memoryLevelRatios を取得（null の場合は空の Map にする）
                      final Map<String, dynamic> ratioData =
                          studySet['memoryLevelRatios'] as Map<String, dynamic>? ?? {};

                      // 各比率（double）を取得、デフォルトは0
                      final double againRatio = (ratioData['again'] ?? 0).toDouble();
                      final double hardRatio = (ratioData['hard'] ?? 0).toDouble();
                      final double goodRatio = (ratioData['good'] ?? 0).toDouble();
                      final double easyRatio = (ratioData['easy'] ?? 0).toDouble();

                      // 合計値を計算し、100% に満たない場合は未回答（unanswered）として残りを算出
                      final double totalRatios = againRatio + hardRatio + goodRatio + easyRatio;
                      final double unansweredRatio = (totalRatios < 100) ? (100 - totalRatios) : 0;

                      // `memoryLevelRatios` が存在しない場合（totalRatios == 0）、未回答（100%）にする
                      final bool noData = totalRatios == 0;
                      final Map<String, int> memoryRatiosMap = noData
                          ? {'unanswered': 100} // データがない場合、グレー100%
                          : {
                        'again': againRatio.round(),
                        'hard': hardRatio.round(),
                        'good': goodRatio.round(),
                        'easy': easyRatio.round(),
                        'unanswered': unansweredRatio.round(),
                      };

                      // 表示順序（Folderと同様：左から "again", "hard", "good", "easy", "unanswered"）
                      final List<String> sortedOrder = ['again', 'hard', 'good', 'easy', 'unanswered'];

                      return Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2.0),
                          child: Row(
                            children: sortedOrder.map((level) {
                              final flexValue = memoryRatiosMap[level] ?? 0;
                              if (flexValue <= 0) return const SizedBox.shrink();
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
                      );
                    }),
                    // ▲ 修正後のプログレスバーここまで ▲
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
              Tab(text: '暗記セット'),
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
