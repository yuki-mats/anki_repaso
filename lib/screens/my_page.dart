// lib/screens/my_page.dart
//
// 寄付プランを最上部にカード1枚で表示（アップグレード＋レビューで応援を1枚に集約）。
// 「購入の復元」はログアウトの直前に表示（同じセキュリティカード内）。
// 白背景・影なしで統一。ステータス表示や解約リンクは表示しない。

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/screens/profile_edit_page.dart';
import 'package:repaso/screens/lobby_page.dart';
import 'package:repaso/utils/entitlement_gate.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

// RevenueCat（購入復元）
import 'package:purchases_flutter/purchases_flutter.dart';
// AppOpen広告の復帰抑制（既存方針）
import 'package:repaso/ads/app_open_ad_manager.dart';

// 共通削除確認ダイアログ
import 'package:repaso/widgets/dialogs/delete_confirmation_dialog.dart';

class MyPage extends StatefulWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String profileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2Fdefault_profile_icon_v1.0.png?alt=media';
  String userName = 'user';

  // ストアレビュー URL と起動ヘルパ
  static const String _iosReviewUrl =
      'itms-apps://itunes.apple.com/app/id6740453092?action=write-review'; // 実アプリIDに置換
  static const String _androidReviewUrl =
      'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME'; // 実パッケージ名に置換

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

  // 復元中フラグ
  bool _restoring = false;

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

  // 購入の復元（RevenueCat）
  Future<void> _restoreFromMyPage() async {
    AppOpenAdManager.instance.ignoreNextResume(); // AppOpen広告の復帰抑制
    setState(() => _restoring = true);
    try {
      await Purchases.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('購入履歴を復元しました')));
    } catch (e) {
      debugPrint('復元エラー: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('復元に失敗しました')));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /* ────────────── アカウント削除（ロジック変更なし） ────────────── */
  Future<void> _reauthenticateAndDeleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final providerId =
    user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password';

    // 共通ダイアログ（説明文なし）
    final res = await DeleteConfirmationDialog.show(
      context,
      title: 'アカウント削除',
      bulletPoints: const [
        'ユーザーデータが削除されます',
        'この操作は取り消せません',
      ],
      confirmText: '削除する',
      cancelText: 'キャンセル',
      confirmColor: Colors.redAccent,
    );
    if (res?.confirmed != true) return;

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

  /* ──────────────── 再認証ダイアログ（入力） ────────────────
     ※ 確認ダイアログではないため、既存UIのまま維持（共通ダイアログ対象外） */
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

    // ── アップグレード & レビューで応援（1枚に集約） ──
    final upgradeAndReviewCard = _buildCard(
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
        ..._tile(
          Icons.thumb_up_alt_outlined,
          'レビューで応援',
          _launchReviewPage,
          iconColor: Colors.black87,
        ),
      ],
    );

    // ── アプリ情報（プライバシーポリシー＋利用規約） ──
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
            if (updated == true) {
              _fetchUserData();
            }
          },
        ),
      ],
    );

    // ── セキュリティ（購入の復元 → ログアウト → アカウント削除） ──
    final securityCard = _buildCard(
      context,
      tiles: [
        // 「ログアウトの上」に配置する復元
        ListTile(
          leading: const Icon(Icons.restore, size: 22, color: Colors.black87),
          title: const Text('購入の復元', style: TextStyle(fontSize: 14)),
          trailing: _restoring
              ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.blue[800]!)))
              : const Icon(Icons.chevron_right, size: 18),
          onTap: _restoring ? null : _restoreFromMyPage,
          visualDensity: VisualDensity.compact,
        ),
        ..._tile(
          Icons.logout,
          'ログアウト',
              () async {
            // 共通ダイアログ（説明文なし）
            final res = await DeleteConfirmationDialog.show(
              context,
              title: 'ログアウト',
              bulletPoints: const [
                '現在のアカウントからサインアウトします',
                '再度利用するにはログインが必要です',
              ],
              confirmText: 'ログアウト',
              cancelText: 'キャンセル',
            );
            if (res?.confirmed != true) return;

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
        accountCard,
        const SizedBox(height: 8),
        upgradeAndReviewCard, // ← 1枚に集約
        const SizedBox(height: 8),
        infoCard,
        const SizedBox(height: 8),
        securityCard, // ← 復元はこのカード内でログアウトの直前
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
