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

        // フォルダデータを取得
        final folderSnapshot = await FirebaseFirestore.instance
            .collection("folders")
            .where("userRoles.$userId", whereIn: ["owner", "editor", "viewer"])
            .get();

        // 学習セットデータを取得
        final studySetSnapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("studySets")
            .get();

        setState(() {
          folders = folderSnapshot.docs;
          studySets = studySetSnapshot.docs;
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  void navigateToQuestionSetsAddPage(BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsAddPage(folderRef: folder.reference),
      ),
    );
  }

  void navigateToQuestionSetsListPage(DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsListPage(folder: folder),
      ),
    );
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

  void showFolderOptionsModal(BuildContext context, DocumentSnapshot folder) {
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
                  leading:
                  Icon(
                      Icons.folder,
                      size: 32,
                      color: AppColors.blue500,
                    ),
                  title: Text(
                    folder['name'],
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis, // 長すぎる場合は省略記号を表示
                    maxLines: 2, // 最大1行に制限
                  ),
                ),
                SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.gray100),
                SizedBox(height: 8),
                Container(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.quiz_sharp,
                          size: 22,
                          color: AppColors.gray600),
                    ),
                    title: const Text('問題集の追加', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsAddPage(context, folder);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  child: ListTile(
                    leading:  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 22,
                          color: AppColors.gray600),
                    ),
                    title: const Text('フォルダ名の編集', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToFolderEditPage(context, folder);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildFolderList() {
    if (folders.isEmpty) {
      return Center(child: Text('フォルダがありません'));
    }
    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final questionCount = folder['questionCount'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 24.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  navigateToQuestionSetsListPage(folder);
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, right: 8.0),
                          child: SizedBox(
                            width: 40,
                            child: Icon(
                              Icons.folder,
                              size: 28,
                              color: AppColors.blue500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 40,
                                child: Container(
                                  alignment: Alignment.centerLeft, // 縦中央、左揃え
                                  child: Text(
                                    folder['name'],
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis, // 長すぎる場合は省略記号を表示
                                    maxLines: 1, // 最大1行に制限
                                  ),
                                ),
                              ),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.filter_none,
                                    size: 16,
                                    color: AppColors.blue400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$questionCount',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                          onPressed: () {
                            showFolderOptionsModal(context, folder);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildStudySetList() {
    if (studySets.isEmpty) {
      return Center(child: Text('学習セットがありません'));
    }
    return ListView.builder(
      itemCount: studySets.length,
      itemBuilder: (context, index) {
        final studySet = studySets[index];
        final numberOfQuestions = studySet['numberOfQuestions'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 24.0),
          child: Column(
            children: [
              GestureDetector(
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
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.blue200, // 背景色
                              borderRadius: BorderRadius.circular(100), // 角を丸くする
                            ),
                            child: Icon(
                              Icons.star,
                              size: 22, // アイコンのサイズを調整
                              color: AppColors.blue500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    studySet['name'] ?? '未設定',
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis, // 長すぎる場合は省略記号を表示
                                    maxLines: 1, // 最大1行に制限
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.filter_none_sharp,
                                    size: 16,
                                    color: AppColors.blue400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$numberOfQuestions',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                          onPressed: () {
                            final userId = FirebaseAuth.instance.currentUser?.uid;
                            if (userId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ログインしてください。')),
                              );
                              return;
                            }

                            final studySetId = studySet.id; // Firestore ドキュメント ID
                            final initialStudySet = EditPage.StudySet(
                              id: studySet.id,
                              name: studySet['name'] ?? '未設定',
                              questionSetIds: List<String>.from(studySet['questionSetIds'] ?? []),
                              numberOfQuestions: studySet['numberOfQuestions'] ?? 0,
                              selectedQuestionOrder: studySet['selectedQuestionOrder'] ?? 'random',
                              correctRateRange: RangeValues(
                                (studySet['correctRateRange']?['start'] ?? 0).toDouble(),
                                (studySet['correctRateRange']?['end'] ?? 100).toDouble(),
                              ),
                              isFlagged: studySet['isFlagged'] ?? false,
                            );

                            navigateToEditStudySetPage(context, userId, studySetId, initialStudySet);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
        body:
        Center(child: Text('ログインしてください')),
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
                Icon(Icons.notifications_none_outlined,
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
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 16),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.blue400, width: 4), // 下線の色と太さ
              insets: EdgeInsets.symmetric(horizontal: -32.0), // 下線の長さを調整（短く）
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
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 16.0), // Positioned above the BottomNavigationBar
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
              borderRadius: BorderRadius.circular(30), // Ensure it is a circle
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Positioned in bottom right
      ),
    );
  }
}
