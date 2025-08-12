// lib/utils/paywall_manager.dart
// ignore_for_file: always_use_package_imports, avoid_print
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';          // RevenueCat
import 'package:package_info_plus/package_info_plus.dart';          // ★ アプリバージョン取得
import '../screens/paywall_page.dart';

class PaywallManager {
  PaywallManager._();                               // インスタンス生成禁止

  static bool _hasShownThisSession = false;         // プロセス中は 1 回

  /// ─────────────────────────────────────────────
  /// MainPage 到達時に呼び出し
  ///   - Pro は除外
  ///   - `lastPaywallVersion_<uid>` が現在バージョンと違えば表示
  ///   - 同セッション内で二重表示を防ぐ
  /// ─────────────────────────────────────────────
  static Future<void> maybeShow({
    required BuildContext context,
    required String uid,
  }) async {
    if (uid.isEmpty) return;                        // 未ログイン
    if (await _isProUser()) return;                 // 有料ユーザー

    final prefs          = await SharedPreferences.getInstance();
    final currentVersion = await _appVersion();
    final lastVersion    = prefs.getString('lastPaywallVersion_$uid');

    // 既に同バージョンで表示済み、またはセッション内で表示済み
    if (lastVersion == currentVersion || _hasShownThisSession) return;

    _hasShownThisSession = true;
    _openPaywall(context);
    await prefs.setString('lastPaywallVersion_$uid', currentVersion);
  }

  /* ---------- 内部 util ---------- */

  static Future<bool> _isProUser() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active['Pro']?.isActive ?? false;
    } catch (e) {
      debugPrint('[PaywallManager] isPro 判定エラー: $e');
      return false;                                 // 失敗時は無料扱い
    }
  }

  static Future<String> _appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;                            // 例 "2.12.0"
  }

  /// PaywallPage を **下からスライドイン** で表示
  static void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PaywallPage(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0, 1),              // 画面下
            end: Offset.zero,                       // 画面中央
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }
}
