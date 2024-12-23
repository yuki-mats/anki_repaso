import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/folder_edit_page.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_list_page.dart';
import 'package:repaso/study_set_setting_page.dart';
import 'app_colors.dart';
import 'folder_add_page.dart';
import 'lobby_page.dart';

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
            .where("userRoles.$userId", whereIn: ["owner", "editor", "reader"])
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
    final studySet = StudySet(
      name: '',
      questionSetIds: [], // 初期値として空のリスト
      numberOfQuestions: 10, // 初期値
      selectedQuestionOrder: 'random', // 初期値
      correctRateRange: const RangeValues(0, 100), // 初期値
      isFlagged: false, // 初期値
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudySetSettingPage(studySet: studySet),
      ),
    );
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

  void showStartModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      builder: (BuildContext context) {
        return Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.today_outlined,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('今日の学習', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 48),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.settings,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('条件を設定', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToFolderAddPage(context);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void showFolderOptionsModal(BuildContext context, DocumentSnapshot folder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      builder: (BuildContext context) {
        return Wrap(
          children: [
            // モーダルの上部にフォルダ情報を表示
            Padding(
              padding: const EdgeInsets.fromLTRB(46, 36, 24, 12),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 36, color: AppColors.blue500),
                  const SizedBox(width: 16),
                  Text(
                    folder['name'],
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.gray100), // 区切り線
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.layers_rounded,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題集の追加', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsAddPage(context, folder);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(
                        Icons.edit_outlined,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('フォルダ名の編集', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToFolderEditPage(context, folder);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  void showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      builder: (BuildContext context) {
        return Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      size: 36,
                      color: AppColors.gray800,
                    ),
                    title: const Text('ログアウト', style: TextStyle(fontSize: 18)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LobbyPage()),
                            (route) => false,
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(
                      Icons.error_outline,
                      size: 36,
                      color: AppColors.gray800,
                    ),
                    title: const Text('開発中', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      // アカウント削除処理を追加可能
                    },
                  ),
                ),
              ),
            ),
          ],
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
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
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
                          padding: EdgeInsets.only(left: 16.0, right: 16.0),
                          child: SizedBox(
                            width: 40,
                            child: Icon(
                              Icons.folder_outlined,
                              size: 32,
                              color: AppColors.blue500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 52,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    folder['name'],
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_rounded,
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
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  // 学習セットの編集画面への遷移

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
                          padding: EdgeInsets.only(left: 16.0, right: 16.0),
                          child: SizedBox(
                            width: 40,
                            child: Icon(
                              Icons.tune_outlined,
                              size: 32,
                              color: AppColors.blue500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 52,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    studySet['name'] ?? '未設定',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_rounded,
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
                            // Firestoreのドキュメントを基にStudySetオブジェクトを作成
                            final studySetData = StudySet(
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

                            // StudySetSettingPageへ遷移
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudySetSettingPage(studySet: studySetData),
                              ),
                            );
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
                Text('ライブラリ'),
                Icon(Icons.notifications_none_outlined,
                  color: AppColors.gray700,
                  size: 30,
                ),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.blue700,
            unselectedLabelColor: AppColors.gray900,
            labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 18),
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
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.gray300, // 線の色
                width: 1.0, // 線の太さ
              ),
            ),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              if (index == 1)  {
                // 学習を開始する
              } else if (index == 3) {
                showSettingsModal(context);
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined, size: 40),
                label: 'ライブラリ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.not_started_outlined, size: 40),
                label: '開始',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle, size: 40),
                label: 'アカウント',
              ),
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
