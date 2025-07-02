// ignore_for_file: always_use_package_imports, avoid_print
// RevenueCat で isPro をリアルタイム取得・更新。UI／機能はそのままです。
// ★ が追加・変更箇所。

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';      // ★ 追加
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/screens/paywall_page.dart';

class SetQuestionOrderPage extends StatefulWidget {
  final String? initialSelection; // 初期選択
  final bool    isPro;            // 互換用デフォルト

  const SetQuestionOrderPage({
    Key? key,
    this.initialSelection,
    this.isPro = false,
  }) : super(key: key);

  @override
  _SetQuestionOrderPageState createState() => _SetQuestionOrderPageState();
}

class _SetQuestionOrderPageState extends State<SetQuestionOrderPage> {
  final Map<String, String> orderOptions = {
    "random"               : "ランダム",
    "attemptsDescending"   : "試行回数が多い順",
    "attemptsAscending"    : "試行回数が少ない順",
    "accuracyDescending"   : "正答率が高い順",
    "accuracyAscending"    : "正答率が低い順",
    "lastStudiedDescending": "最終学習日の降順",
    "lastStudiedAscending" : "最終学習日の昇順",
  };

  String? selectedOrder;              // 現在の選択
  bool    _isPro = false;             // ★ RevenueCat 上書き
  late final void Function(CustomerInfo) _listener; // ★

  @override
  void initState() {
    super.initState();
    selectedOrder = widget.initialSelection;
    _isPro        = widget.isPro;               // 互換デフォルト

    // ① 初回取得 ★
    Purchases.getCustomerInfo().then((info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      if (mounted) setState(() => _isPro = active);
    });

    // ② 更新購読 ★
    _listener = (CustomerInfo info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      if (mounted && _isPro != active) setState(() => _isPro = active);
    };
    Purchases.addCustomerInfoUpdateListener(_listener);
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_listener); // ★
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出題順を設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context, selectedOrder),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(height: 1.0, color: Colors.grey[300]),
        ),
      ),
      body: ListView.builder(
        itemCount: orderOptions.length,
        itemBuilder: (context, index) {
          final key      = orderOptions.keys.elementAt(index);
          final label    = orderOptions[key]!;
          final isLocked = !_isPro && key != 'random';      // ★ _isPro 参照

          return RadioListTile<String>(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (isLocked) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.lock, color: Colors.amber, size: 16),
                ],
              ],
            ),
            value: key,
            groupValue: selectedOrder,
            activeColor: AppColors.blue500,
            onChanged: (String? value) {
              if (value == null) return;

              // 無料ユーザーでロック項目をタップしたら課金ページへ
              if (!_isPro && value != 'random') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaywallPage(
                      subtitle:
                      '暗記プラス Proプランで、出題順の設定をより自由に！学習効率をUPさせよう！',
                    ),
                  ),
                );
                return;
              }

              setState(() => selectedOrder = value);
            },
          );
        },
      ),
    );
  }
}
