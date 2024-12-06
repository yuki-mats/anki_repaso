import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/folder_edit_page.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_list_page.dart';
import 'app_colors.dart';
import 'folder_add_page.dart';
import 'lobby_page.dart';

class FolderListPage extends StatefulWidget {
  const FolderListPage({super.key, required this.title});

  final String title;

  @override
  State<FolderListPage> createState() => FolderListPageState();
}

class FolderListPageState extends State<FolderListPage> {
  List<DocumentSnapshot> folders = [];

  get leading => null;

  @override
  void initState() {
    super.initState();
    fetchFirebaseData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void fetchFirebaseData() async {
    try {
      // 現在のログインユーザーを取得
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userId = user.uid;

        final snapshot = await FirebaseFirestore.instance
            .collection("folders")
            .where("userRoles.$userId", whereIn: ["owner", "editor", "reader"]) // ロールが条件に合致する場合
            .get();

        setState(() {
          folders = snapshot.docs;
        });
      }
    } catch (e) {
      print("Error fetching folders: $e");
    }
  }

  void navigateToQuestionSetsAddPage(BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsAddPage(folderId: folder.id),
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
  // 設定モーダルを表示するメソッドを追加
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
                        color: AppColors.gray800,),
                    title: const Text('アカウントの削除', style: TextStyle(fontSize: 18)),
                    onTap: () {
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


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          // Firestoreで現在のユーザーがアクセスできるフォルダを監視
          stream: FirebaseFirestore.instance
              .collection("folders")
              .where("userRoles.${user.uid}", whereIn: ["owner", "editor", "reader"])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('フォルダがありません'));
            }

            final folders = snapshot.data!.docs;

            return ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final totalQuestions = folder['totalQuestions'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          navigateToQuestionSetsListPage(folder);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16.0, right: 16.0),
                                  child: SizedBox(
                                    width: 40,
                                    child: Icon(
                                      Icons.folder,
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
                                            '$totalQuestions',
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
                      const SizedBox(height: 16.0),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            navigateToFolderAddPage(context);
          } else if (index == 2) {
            showStartModal(context);
          } else if (index == 3) {
            showSettingsModal(context);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open_outlined, size: 42),
            label: 'ライブラリ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 42),
            label: '追加',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.not_started_outlined, size: 42),
            label: '開始',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle, size: 42),
            label: 'アカウント',
          ),
        ],
      ),
    );
  }
}