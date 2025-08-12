// lib/screens/my_page.dart
//
// 寄付プランを最上部に配置し、すべてのカードを白背景・影なしに統一した版。
// 「レビューで応援」タイルを追加。

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/screens/profile_edit_page.dart';
import 'package:repaso/screens/lobby_page.dart';
import 'package:repaso/utils/entitlement_gate.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

class MyPage extends StatefulWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String profileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2Fdefault_profile_icon_v1.0.png?alt=media';
  String userName = 'user';

  // ──────────────── 追加: ストアレビュー URL と起動ヘルパ ────────────────
  static const String _iosReviewUrl =
      'itms-apps://itunes.apple.com/app/id6740453092?action=write-review'; // YOUR_APP_ID を実際の ID に置換
  static const String _androidReviewUrl =
      'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME'; // YOUR_PACKAGE_NAME を実際の ID に置換

  Future<void> _launchReviewPage() async {
    final url = Platform.isIOS ? _iosReviewUrl : _androidReviewUrl;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レビュー画面を開けませんでした。')),
      );
    }
  }
  // ────────────────────────────────────────────────────────────────

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
        userName = data?['name'] ?? userName;
      });
    } catch (e) {
      debugPrint('ユーザーデータ取得エラー: $e');
    }
  }

  /* ────────────── アカウント削除まわり（ロジック変更なし） ────────────── */
  Future<void> _reauthenticateAndDeleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final providerId =
    user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password';

    final confirmed = await _showConfirmDialog(context, providerId);
    if (!confirmed) return;

    try {
      switch (providerId) {
        case 'password':
          final password = await _askPassword(context);
          if (password == null) return;
          final credential =
          EmailAuthProvider.credential(email: user.email!, password: password);
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

  /* ──────────────── ダイアログ系ヘルパー（ロジック変更なし） ──────────────── */
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

  /* ────────────────────────── UI ────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'メールアドレス未設定';
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
          title: const Text('マイページ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileSection(email),
              const SizedBox(height: 12),
              EntitlementBuilder(
                builder: (_, isPro) => _buildSettingsList(context, isPro),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* -------- プロフィールカード（白背景・影なし） -------- */
  Widget _buildProfileSection(String email) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(radius: 40, backgroundImage: NetworkImage(profileImageUrl)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* -------- 設定カード群 -------- */
  Widget _buildSettingsList(BuildContext context, bool isPro) {
    final donateTitle = isPro ? 'Anki Pro 加入中' : 'アップグレード';
    // 寄付アイコン（Proユーザーは特別なアイコンを使用）
    final donateIcon = Icons.diamond_outlined;

    // ListTile 生成ヘルパ
    List<Widget> _tile(
        IconData icon,
        String title,
        VoidCallback? onTap, {
          Color? iconColor,
          Widget? trailing,
        }) =>
        [
          ListTile(
            leading: Icon(icon, size: 22, color: iconColor),
            title: Text(title, style: const TextStyle(fontSize: 14)),
            trailing: trailing ?? const Icon(Icons.chevron_right, size: 18),
            visualDensity: VisualDensity.compact,
            onTap: onTap,
          ),
        ];

    // ── 寄付プランカード（最上部） ──
    final planCard = _buildCard(
      context,
      tiles: [
        ..._tile(
          donateIcon,
          donateTitle,
          isPro
              ? null
              : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallPage()),
            );
          },
          iconColor: isPro ? Colors.blue : null,
          trailing: isPro
              ? const Icon(Icons.verified, color: Colors.white, size: 18)
              : const Icon(Icons.chevron_right, size: 18),
        ),
      ],
    );

    // ── レビューで応援カード（追加） ──
    final reviewCard = _buildCard(
      context,
      tiles: [
        ..._tile(
          Icons.thumb_up_alt_outlined,
          'レビューで応援',
          _launchReviewPage,
          iconColor: Colors.black87,
        ),
      ],
    );

    // ── アカウント管理 ──
    final accountCard = _buildCard(
      context,
      tiles: [
        ..._tile(
          Icons.person,
          'プロフィール',
              () async {
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => ProfileEditPage()),
            );
            if (updated == true) _fetchUserData();
          },
        ),
      ],
    );

    // ── アプリ情報 ──
    final infoCard = _buildCard(
      context,
      tiles: [
        ..._tile(
          Icons.privacy_tip_outlined,
          'プライバシーポリシー',
              () async {
            final uri = Uri.parse(
                'https://www.notion.so/17be144de0eb807c8e1fe6da3de3f92c');
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('リンクを開くことができませんでした。')),
              );
            }
          },
        ),
        ..._tile(
          Icons.format_list_bulleted_outlined,
          '利用規約',
              () async {
            final uri = Uri.parse(
                'https://right-saxophone-1b5.notion.site/215e144de0eb8094b3b2ce284b39975c');
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('リンクを開くことができませんでした。')),
              );
            }
          },
        ),
      ],
    );

    // ── セキュリティ ──
    final securityCard = _buildCard(
      context,
      tiles: [
        ..._tile(
          Icons.logout,
          'ログアウト',
              () {
            FirebaseAuth.instance.signOut().then((_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LobbyPage()),
                    (_) => false,
              );
            });
          },
        ),
        ..._tile(
          Icons.delete_forever,
          'アカウント削除',
              () => _reauthenticateAndDeleteAccount(context),
        ),
      ],
    );

    return Column(
      children: [
        planCard,
        const SizedBox(height: 8),
        reviewCard,           // ← 追加したカード
        const SizedBox(height: 8),
        accountCard,
        const SizedBox(height: 8),
        infoCard,
        const SizedBox(height: 8),
        securityCard,
      ],
    );
  }

  /* -------- 共通カード生成ヘルパ（白背景・影なし） -------- */
  Widget _buildCard(BuildContext context, {required List<Widget> tiles}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: ListTile.divideTiles(
          context: context,
          tiles: tiles,
          color: Colors.grey.shade300,
        ).toList(),
      ),
    );
  }
}
