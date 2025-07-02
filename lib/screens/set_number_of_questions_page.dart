// ignore_for_file: always_use_package_imports, avoid_print
// RevenueCat を用いて isPro をリアルタイム取得・更新します。
// UI / UX は既存と同じ。★ が追加・変更箇所です。

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';           // ★ 追加
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/screens/paywall_page.dart';

class SetNumberOfQuestionsPage extends StatefulWidget {
  final int?  initialSelection; // 初期選択
  final bool  isPro;            // 互換用（初期値）

  const SetNumberOfQuestionsPage({
    Key? key,
    this.initialSelection,
    this.isPro = false,
  }) : super(key: key);

  @override
  _SetNumberOfQuestionsPageState createState() => _SetNumberOfQuestionsPageState();
}

class _SetNumberOfQuestionsPageState extends State<SetNumberOfQuestionsPage> {
  final List<int> numberOfQuestions = [5, 10, 15, 20, 25, 30];
  int?  selectedNumber;                 // 現在選択数
  bool  _isPro = false;                 // ★ RevenueCat で上書き
  late final void Function(CustomerInfo) _listener; // ★

  @override
  void initState() {
    super.initState();
    selectedNumber = widget.initialSelection;
    _isPro         = widget.isPro;                     // 互換用デフォルト

    // ① 現在の購読状態を取得 ★
    Purchases.getCustomerInfo().then((info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      if (mounted) setState(() => _isPro = active);
    });

    // ② 以降の更新を購読 ★
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
        title: const Text('出題数を設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context, selectedNumber),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(height: 1, color: Colors.grey[300]),
        ),
      ),
      body: ListView.builder(
        itemCount: numberOfQuestions.length,
        itemBuilder: (context, index) {
          final count    = numberOfQuestions[index];
          final isLocked = !_isPro && count != 5 && count != 10;    // ★ _isPro を参照

          return RadioListTile<int>(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count問'),
                if (isLocked) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.lock, color: Colors.amber, size: 16),
                ],
              ],
            ),
            value: count,
            groupValue: selectedNumber,
            activeColor: AppColors.blue500,
            onChanged: (int? value) {
              if (value == null) return;

              if (isLocked) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaywallPage()),
                );
                return;
              }

              setState(() => selectedNumber = value);
            },
          );
        },
      ),
    );
  }
}
