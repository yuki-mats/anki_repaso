// lib/screens/my_page.dart
//
// UI はそのままに、EntitlementGate を使って「寄付プラン」タイルを
// Pro ユーザー向けにステータス表示（登録済み／未登録）するようにした版。

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/screens/privacy_policy_page.dart';
import 'package:repaso/screens/profile_edit_page.dart';
import 'package:repaso/screens/terms_of_service_page.dart';
import 'package:repaso/screens/lobby_page.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:repaso/utils/entitlement_gate.dart';   // ← 追加

class MyPage extends StatefulWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String profileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2Fdefault_profile_icon_v1.0.png?alt=media';
  String userName = 'user';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) return;
      final data = doc.data();
      setState(() {
        profileImageUrl = data?['profileImageUrl'] ?? profileImageUrl;
        userName        = data?['name'] ?? userName;
      });
    } catch (e) {
      debugPrint('ユーザーデータ取得エラー: $e');
    }
  }

  /* ------------- アカウント削除まわり（省略なし、元コードそのまま） ------------- */
  Future<void> _reauthenticateAndDeleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    final confirmed = await _showConfirmDialog(context, providerId);
    if (!confirmed) return;

    try {
      switch (providerId) {
        case 'password':
          final password = await _askPassword(context);
          if (password == null) return;
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.reauthenticateWithCredential(credential);
          break;
        case 'google.com':
          if (kIsWeb) {
            await user.reauthenticateWithPopup(GoogleAuthProvider());
          } else {
            final googleUser = await GoogleSignIn().signIn();
            if (googleUser == null) return;
            final auth = await googleUser.authentication;
            final credential = GoogleAuthProvider.credential(
              idToken: auth.idToken,
              accessToken: auth.accessToken,
            );
            await user.reauthenticateWithCredential(credential);
          }
          break;
        case 'apple.com':
          if (kIsWeb) {
            await user.reauthenticateWithPopup(OAuthProvider('apple.com'));
          } else if (Platform.isIOS || Platform.isMacOS) {
            final appleId = await SignInWithApple.getAppleIDCredential(
              scopes: [AppleIDAuthorizationScopes.email],
            );
            final credential = OAuthProvider('apple.com').credential(
              idToken: appleId.identityToken,
              accessToken: appleId.authorizationCode,
            );
            await user.reauthenticateWithCredential(credential);
          } else {
            throw FirebaseAuthException(
              code: 'apple_sign_in_unavailable',
              message: 'Apple サインインはこのプラットフォームでは使用できません。',
            );
          }
          break;
        default:
          throw FirebaseAuthException(
            code: 'unsupported_provider',
            message: '未対応のログイン方法です。',
          );
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LobbyPage()),
            (_) => false,
      );
    } catch (e) {
      debugPrint('アカウント削除エラー: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('再認証またはアカウント削除に失敗しました。')),
      );
    }
  }

  /* ---------- 以下、ダイアログ系ヘルパーは元コードと同じなので省略せず保持 ---------- */
  Future<bool> _showConfirmDialog(BuildContext context, String providerId) async {
    final providerLabel = {
      'password': 'メールアドレス',
      'google.com': 'Google',
      'apple.com': 'Apple',
    }[providerId]!;
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
        title: const Text('アカウントの削除'),
        content: Text('$providerLabel で登録したアカウントを削除します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<String?> _askPassword(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
        title: const Text('再認証が必要です'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'パスワード'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('続行'),
          ),
        ],
      ),
    );
    return ok == true ? controller.text : null;
  }

  /* ------------------------------ UI ------------------------------ */

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'メールアドレス未設定';
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileSection(email),
              const SizedBox(height: 20),
              EntitlementBuilder(
                builder: (_, isPro) => _buildSettingsList(context, isPro),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(String email) {
    return Row(
      children: [
        CircleAvatar(radius: 32, backgroundImage: NetworkImage(profileImageUrl)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(email,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsList(BuildContext context, bool isPro) {
    final donateTitle = isPro ? '寄付プラン（登録済み）' : '寄付プラン';
    final donateIcon  = isPro ? Icons.check_circle : Icons.shopping_cart_outlined;

    return Column(
      children: [
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.person, size: 22),
          title: const Text('プロフィール編集', style: TextStyle(fontSize: 14)),
          onTap: () async {
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => ProfileEditPage()),
            );
            if (updated == true) _fetchUserData();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, size: 22),
          title: const Text('プライバシーポリシー', style: TextStyle(fontSize: 14)),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.library_books_outlined, size: 22),
          title: const Text('利用規約', style: TextStyle(fontSize: 14)),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
        ),
        const Divider(),
        ListTile(
          leading: Icon(donateIcon, size: 22, color: isPro ? Colors.blue : null),
          title: Text(donateTitle, style: const TextStyle(fontSize: 14)),
          onTap: isPro
              ? null
              : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallPage()),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, size: 22),
          title: const Text('ログアウト', style: TextStyle(fontSize: 14)),
          onTap: () {
            FirebaseAuth.instance.signOut().then((_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LobbyPage()),
                    (_) => false,
              );
            });
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever, size: 22),
          title: const Text('アカウントの削除', style: TextStyle(fontSize: 14)),
          onTap: () => _reauthenticateAndDeleteAccount(context),
        ),
      ],
    );
  }
}
