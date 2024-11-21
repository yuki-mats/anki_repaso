import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/category_edit_page.dart';
import 'package:repaso/subcategory_add_page.dart';
import 'package:repaso/subcategory_list_page.dart';
import 'app_colors.dart';
import 'category_add_page.dart';
import 'lobby_page.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key, required this.title});

  final String title;

  @override
  State<CategoryListPage> createState() => CategoryListState();
}

class CategoryListState extends State<CategoryListPage> {
  List<DocumentSnapshot> categories = [];

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
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        // permissions.sharedWithに現在のユーザーが含まれるカテゴリを取得
        final snapshot = await FirebaseFirestore.instance
            .collection("categories")
            .where("permissions.sharedWith", arrayContains: userRef)
            .get();

        setState(() {
          categories = snapshot.docs;
        });
      }
    } catch (e) {
      print("Error fetching categories: $e");
    }
  }

  void navigateToAddSubcategoryPage(BuildContext context, DocumentSnapshot category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubcategoryAddPage(categoryId: category.id),
      ),
    );
  }

  void navigateToSubcategories(DocumentSnapshot category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubCategoryListPage(category: category),
      ),
    );
  }

  void navigateToAddCategoryPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryAddPage()),
    );

    if (result == true) {
      fetchFirebaseData();
    }
  }

  void navigateToEditCategoryPage(BuildContext context, DocumentSnapshot category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryEditPage(
          initialCategoryName: category['name'],
          categoryId: category.id,
        ),
      ),
    );

    if (result == true) {
      fetchFirebaseData();
    }
  }

  void showAddModal(BuildContext context) {
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
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.layers_rounded, size: 36),
                    title: const Text('問題集', style: TextStyle(fontSize: 18)),
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
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined, size: 36),
                    title: const Text('フォルダ', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToAddCategoryPage(context);
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
                      navigateToAddCategoryPage(context);
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
                      Navigator.of(context).pop();
                      showDeleteAccountConfirmation(context);
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

  // アカウント削除の確認ダイアログを表示するメソッドを追加
  void showDeleteAccountConfirmation(BuildContext context) {
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'アカウントを削除しますか？',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'これまで作った暗記帳は削除されます。',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'この動作は取り消せません。',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop(); // モーダルを閉じる

                    try {
                      // FirebaseAuthインスタンスを取得
                      User? user = FirebaseAuth.instance.currentUser;

                      // ユーザーの再認証（ユーザーにパスワード再入力を求める）
                      final credential = EmailAuthProvider.credential(
                        email: user!.email!,
                        password: 'ユーザーのパスワードを入力してください', // パスワード入力フィールドを追加する必要があります
                      );

                      // 再認証を実行
                      await user.reauthenticateWithCredential(credential);

                      // 再認証後にアカウント削除を実行
                      await user.delete();

                      // 削除成功後、LobbyPageへ遷移
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LobbyPage()),
                            (route) => false,
                      );
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'requires-recent-login') {
                        // 再認証が必要な場合のエラーメッセージ
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('この操作には再認証が必要です。再度ログインしてください。'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('エラー: ${e.message}')),
                        );
                      }
                    }
                  },
                  child: const Text(
                    '削除する',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }



  // アカウントを削除するメソッドを追加
  Future<void> deleteAccount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      // Firestore上のユーザーデータを削除（必要に応じて追加）
      // 例: カテゴリや問題集などのユーザーデータを削除
      // 以下は例ですので、実際のデータ構造に合わせて調整してください
      // await FirebaseFirestore.instance.collection('users').doc(user?.uid).delete();

      // ユーザーアカウントを削除
      await user?.delete();

      // ロビー画面に遷移
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LobbyPage()),
            (route) => false,
      );
    } catch (e) {
      // エラーハンドリング（再認証が必要な場合など）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アカウントの削除に失敗しました: $e')),
      );
    }
  }

  void showCategoryOptionsModal(BuildContext context, DocumentSnapshot category) {
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
                    category['name'],
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
                      navigateToAddSubcategoryPage(context, category);
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
                      navigateToEditCategoryPage(context, category);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final questionCount = category['questionCount'] ?? 0; // Firestoreから取得した値
            return Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      navigateToSubcategories(category);
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
                                        category['name'],
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '問題数: $questionCount', // 問題数を表示
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                              onPressed: () {
                                showCategoryOptionsModal(context, category);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0), // タイル間のスペース
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            navigateToAddCategoryPage(context);
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
