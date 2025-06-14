// lib/utils/entitlement_gate.dart
//
// RevenueCat の Entitlement（例: "Pro"）をリアルタイムで監視し、
// アプリ全体で購読状態を参照できるようにするシンプルなゲート。
// ChangeNotifier ベースなので Provider / Riverpod などに依存しません。

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class EntitlementGate extends ChangeNotifier {
  /// シングルトンインスタンス
  static final EntitlementGate _instance = EntitlementGate._internal();

  factory EntitlementGate() => _instance;

  EntitlementGate._internal() {
    _initialize();
  }

  bool _isPro = false;

  /// 現在の購読状態を返す（true = Pro アクティブ）
  bool get isPro => _isPro;

  /* ------------------------------------------------------------------ */
  /* 初期化 & 監視                                                        */
  /* ------------------------------------------------------------------ */
  Future<void> _initialize() async {
    try {
      // 起動時に一度 CustomerInfo を取得
      final info = await Purchases.getCustomerInfo();
      _updateState(info);

      // 購読状態が変わったときに自動コールバック
      Purchases.addCustomerInfoUpdateListener(_updateState);
    } catch (e) {
      debugPrint('EntitlementGate init error: $e');
    }
  }

  void _updateState(CustomerInfo info) {
    final active = info.entitlements.active.containsKey('Pro');
    if (active != _isPro) {
      _isPro = active;
      notifyListeners();
    }
  }
}

/* ------------------------------------------------------------------ */
/* UI で使うヘルパー: EntitlementBuilder                               */
/* ------------------------------------------------------------------ */

typedef EntitlementWidgetBuilder = Widget Function(
    BuildContext context,
    bool isPro,
    );

/// 例:
/// ```dart
/// EntitlementBuilder(
///   builder: (_, isPro) => isPro ? AdFreeWidget() : BannerAdWidget(),
/// )
/// ```
class EntitlementBuilder extends StatelessWidget {
  final EntitlementWidgetBuilder builder;

  const EntitlementBuilder({Key? key, required this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gate = EntitlementGate(); // シングルトン取得
    return AnimatedBuilder(
      animation: gate,
      builder: (context, _) => builder(context, gate.isPro),
    );
  }
}
