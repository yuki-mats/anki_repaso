import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/privacy_policy_page.dart';
import 'package:repaso/screens/profile_edit_page.dart';
import 'package:repaso/screens/terms_of_service_page.dart';
import 'package:repaso/screens/lobby_page.dart'; // LobbyPageをインポート

class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String profileImageUrl = 'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2FIcons.school.v3.png?alt=media&token=2fe984d6-b755-439e-a81e-afb8b707f495'; // 初期値
  String userName = '未設定'; // 初期値

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data();
          setState(() {
            profileImageUrl = data?['profileImageUrl'] ?? profileImageUrl;
            userName = data?['name'] ?? userName;
          });
        } else {
          print('ユーザードキュメントが存在しません');
        }
      } else {
        print('ユーザーがログインしていません');
      }
    } catch (e) {
      print('エラーが発生しました: $e');
    }
  }

  Future<void> _reauthenticateAndDeleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final email = user.email ?? '';
    final passwordController = TextEditingController();

    // 再認証用ダイアログを表示
    final reauthenticate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Colors.white,
          title: Text('再認証が必要です'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('アカウント削除には再認証が必要です。パスワードを入力してください。'),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('キャンセル', style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('アカウントの削除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (reauthenticate != true) {
      return; // キャンセルされた場合
    }

    try {
      // 再認証を実行
      final credential = EmailAuthProvider.credential(
        email: email,
        password: passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // アカウント削除処理
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();

      // 成功時にログアウトしてロビー画面へ遷移
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LobbyPage()),
            (route) => false,
      );
    } catch (e) {
      print('アカウント削除時にエラーが発生しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再認証またはアカウント削除に失敗しました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('マイページ'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileSection(),
            SizedBox(height: 20),
            _buildSettingsList(context),
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage: NetworkImage(profileImageUrl),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                FirebaseAuth.instance.currentUser?.email ?? 'メールアドレス未設定',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 16),
        ListTile(
          leading: Icon(Icons.person, size: 22),
          title: Text('プロフィール編集', style: TextStyle(fontSize: 14)),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileEditPage(),
              ),
            );
            if (result == true) {
              _fetchUserData();
            }
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.privacy_tip_outlined, size: 22),
          title: Text('プライバシーポリシー', style: TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyPage(),
              ),
            );
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.library_books_outlined, size: 22),
          title: Text('利用規約', style: TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TermsOfServicePage(),
              ),
            );
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.logout, size: 22),
          title: Text('ログアウト',style: TextStyle(fontSize: 14)),
          onTap: () {
            FirebaseAuth.instance.signOut().then((_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LobbyPage()),
                    (route) => false,
              );
            });
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.delete_forever,size: 22),
          title: Text('アカウントの削除', style: TextStyle(fontSize: 14)),
          onTap: () => _reauthenticateAndDeleteAccount(context),
        ),
      ],
    );
  }
}
