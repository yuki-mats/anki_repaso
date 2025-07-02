// lib/utils/paywall_manager.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/paywall_page.dart';

class PaywallManager {
  PaywallManager._();                               // インスタンス生成禁止

  static const _kPrefsLastPaywallDate = 'lastPaywallShownDate';
  static bool _hasShownThisSession = false;         // 起動中 1 回だけ表示

  /// 必要があれば PaywallPage を push する（乱数判定なし）
  static Future<void> maybeShow({
    required BuildContext context,
    required String uid,
  }) async {
    if (await _isProUser(uid)) return;              // 有料ユーザーは非表示

    final prefs   = await SharedPreferences.getInstance();
    final today   = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 既に当日表示済みならスキップ
    if (prefs.getString(_kPrefsLastPaywallDate) == today) return;

    // セッション内で未表示なら必ず表示
    if (!_hasShownThisSession) {
      _hasShownThisSession = true;
      _openPaywall(context);
      await prefs.setString(_kPrefsLastPaywallDate, today);
    }
  }

  /* ---------- 内部 util ---------- */

  static Future<bool> _isProUser(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return (snap.data()?['isPro'] ?? false) as bool;
    } catch (e) {
      debugPrint('isPro 判定エラー: $e');
      return false;                                 // 失敗時は表示する
    }
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
