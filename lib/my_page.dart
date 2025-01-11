import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/privacy_policy_page.dart';
import 'package:repaso/terms_of_service_page.dart';
import 'package:repaso/lobby_page.dart'; // LobbyPageをインポート

class MyPage extends StatelessWidget {
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
          radius: 40,
          backgroundImage: AssetImage('assets/profile_placeholder.png'), // プロフィール画像
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ユーザー名',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              FirebaseAuth.instance.currentUser!.email!,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.person),
          title: Text('プロフィール編集'),
          onTap: () {
            // プロフィール編集画面へ遷移
          },
        ),
        Divider(),
        ListTile(
          //プライバシーポリシーのiconを追加
          leading: Icon(Icons.privacy_tip_outlined),
          title: Text('プライバシーポリシー'),
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
          //利用規約のiconを追加
          leading: Icon(Icons.library_books_outlined),
          title: Text('利用規約'),
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
          //ログアウトのiconを追加
          leading: Icon(Icons.logout),
          title: Text('ログアウト'),
          onTap: () {
            FirebaseAuth.instance.signOut().then((_) {
              // ログアウト後にLobbyPageへ遷移し、スタックをすべてクリア
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LobbyPage()),
                    (route) => false,
              );
            });
          },
        ),
      ],
    );
  }
}
