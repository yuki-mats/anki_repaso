import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/subcategory_add_page.dart';
import 'package:repaso/subcategory_edit_page.dart';
import 'app_colors.dart';
import 'lobby_page.dart';
import 'question_add_page.dart';
import 'answer_page.dart'; // AnswerPageのインポートを追加
import 'question_list_page.dart'; // QuestionListPageのインポートを追加

class SubCategoryListPage extends StatefulWidget {
  final DocumentSnapshot category;

  SubCategoryListPage({Key? key, required this.category}) : super(key: key);

  @override
  _SubCategoryListPageState createState() => _SubCategoryListPageState();
}

class _SubCategoryListPageState extends State<SubCategoryListPage> {
  void navigateToAddSubcategoryPage(BuildContext context, String categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubcategoryAddPage(categoryId: categoryId),
      ),
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
                    leading: const Icon(Icons.logout,
                        size: 36,
                        color: AppColors.gray800
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
                    leading: const Icon(Icons.error_outline, size: 36),
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

  void navigateToEditSubcategoryPage(BuildContext context, DocumentSnapshot category, DocumentSnapshot subcategory) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubcategoryEditPage(
          initialSubcategoryName: subcategory['name'],
          categoryId: category.id,
          subcategoryId: subcategory.id,
        ),
      ),
    );

    if (result == true) {
      setState(() {}); // 更新後、画面を再構築
    }
  }

  void navigateToQuestionCreationPage(BuildContext context, String categoryId, String subcategoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionCreationPage(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
        ),
      ),
    );
  }

  void navigateToAnswerPage(BuildContext context, String categoryId, String subcategoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswerPage(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
        ),
      ),
    );
  }

  void navigateToQuestionListPage(BuildContext context, String categoryId, DocumentSnapshot subcategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionListPage(
          categoryId: categoryId,
          subcategoryId: subcategory.id,
          subcategoryName: subcategory['name'],
        ),
      ),
    );
  }

  void showSubcategoryOptionsModal(BuildContext context, DocumentSnapshot category, DocumentSnapshot subcategory) {
    showModalBottomSheet(
      context: context,
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
              padding: const EdgeInsets.fromLTRB(46, 36, 24, 12),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, size: 36, color: AppColors.blue500),
                  const SizedBox(width: 16),
                  Text(
                    subcategory['name'],
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
                    leading: const Icon(Icons.add,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題の追加', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionCreationPage(context, category.id, subcategory.id);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.edit_outlined,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題集名の編集', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToEditSubcategoryPage(context, category, subcategory);
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
                    leading: const Icon(
                        Icons.list,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題の一覧', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionListPage(context, category.id, subcategory);
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
        title: Text(widget.category['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("categories")
              .doc(widget.category.id)
              .collection("subcategories")
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('エラーが発生しました'));
            }
            final subcategories = snapshot.data?.docs ?? [];
            return ListView.builder(
              itemCount: subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = subcategories[index];
                final questionCount = subcategory['questionCount'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          navigateToAnswerPage(context, widget.category.id, subcategory.id);
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
                                      Icons.layers_rounded,
                                      size: 40,
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
                                            subcategory['name'],
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '問題数: ${questionCount.toString()}', // 動的に問題数を表示
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    showSubcategoryOptionsModal(context, widget.category, subcategory);
                                  },
                                  icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
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
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            navigateToAddSubcategoryPage(context, widget.category.id);
          } else if (index == 3) {
            showSettingsModal(context);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open, size: 42),
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