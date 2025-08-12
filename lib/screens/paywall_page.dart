import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/app_open_ad_manager.dart';
import '../utils/app_colors.dart'; // ← リンク用

// ====== それぞれの外部リンク先 =============================================
const _kTermsUrl =
    'https://right-saxophone-1b5.notion.site/215e144de0eb8094b3b2ce284b39975c';
const _kPolicyUrl =
    'https://right-saxophone-1b5.notion.site/17be144de0eb807c8e1fe6da3de3f92c?pvs=74';
const _kCancelUrl = 'https://support.apple.com/ja-jp/HT202039';
// ============================================================================

class PaywallPage extends StatefulWidget {
  final String? subtitle;
  const PaywallPage({Key? key, this.subtitle}) : super(key: key);
  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  int _selectedIndex = 1; // 0: 月額, 1: 年額
  Package? _monthlyPackage;
  Package? _annualPackage;

  // ───────────────────────────── 新規追加 ─────────────────────────────
  bool _isLoading = false; // 今すぐ登録ボタン押下時のローディング状態
  // ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (!mounted) return;
      setState(() {
        _monthlyPackage = current?.monthly;
        _annualPackage = current?.annual;
      });
    } catch (e) {
      debugPrint('Offerings fetch error: $e');
    }
  }

  void _onSelectPlan(int index) => setState(() => _selectedIndex = index);

  Future<void> _onSubscribe() async {
    final pkg = _selectedIndex == 0 ? _monthlyPackage : _annualPackage;
    if (pkg == null) return;

    AppOpenAdManager.instance.ignoreNextResume(); // ★ 追加: 課金フロー復帰を無視
    setState(() => _isLoading = true);
    try {
      final info = await Purchases.purchasePackage(pkg);
      if (!mounted) return;
      if (info.entitlements.active.containsKey('Pro')) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ご登録ありがとうございました！')));
        Navigator.of(context).pop();
      }
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('購入に失敗しました: ${e.message}')));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRestore() async {
    AppOpenAdManager.instance.ignoreNextResume(); // ★ 追加
    try {
      await Purchases.restorePurchases();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('購入履歴を復元しました')));
    } catch (e) {
      debugPrint('Restore error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('復元に失敗しました')));
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMonthly = _selectedIndex == 0;
    final monthlyPrice = _monthlyPackage?.storeProduct.priceString ?? '---';
    final annualPrice = _annualPackage?.storeProduct.priceString ?? '---';

    // 24px padding ×2 + 16px gap
    final cardWidth = (MediaQuery.of(context).size.width - 24 * 2 - 16) / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 140,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  'Anki',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'Pro',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.close, color: Colors.black, size: 18),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.asset(
                        'assets/paywall/paywall.png',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 0.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.subtitle ??
                                'Anki Proプランで、学習をもっと効率的に！',
                            textAlign: TextAlign.center,
                            style:
                            TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          // ─── 機能リスト ────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Column(
                              children: [
                                _FeatureRow(
                                  icon: Icons.library_books,
                                  bgColor: Colors.blueAccent,
                                  text: '暗記セットを無制限に保存',
                                ),
                                _FeatureRow(
                                  icon: Icons.summarize,
                                  bgColor: Colors.purpleAccent,
                                  text: 'より効率的にまとめて学習',
                                ),
                                _FeatureRow(
                                  icon: Icons.thumb_up,
                                  bgColor: Colors.cyan,
                                  text: '今すぐ学習でよりスムーズに',
                                ),
                                _FeatureRow(
                                  icon: Icons.rocket_launch,
                                  bgColor: Colors.indigoAccent,
                                  text: '今なら7日間無料',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ─── プランセレクター ─────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PlanSelectorCard(
                                width: double.infinity,
                                title: '月額',
                                price: monthlyPrice,
                                period: '/月',
                                smallNote: '自動更新',
                                selected: isMonthly,
                                onTap: () => _onSelectPlan(0),
                              ),
                              const SizedBox(height: 16),
                              _PlanSelectorCard(
                                width: double.infinity,
                                title: '年額',
                                price: annualPrice,
                                period: '/年',
                                smallNote: '自動更新',
                                badge: '55%オフ',
                                selected: !isMonthly,
                                onTap: () => _onSelectPlan(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // ─── 利用規約・プライバシー・解約リンク ────────────
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                InkWell(
                                  onTap: () => _launchUrl(_kTermsUrl),
                                  child: const Text(
                                    '利用規約',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _launchUrl(_kPolicyUrl),
                                  child: const Text(
                                    'プライバシーポリシー',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                _PolicyLink(label: '解約方法', url: _kCancelUrl),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '年額 ¥4,980 (¥415/月相当) – 期間終了 24 時間前までに解約しない限り自動更新されます。',
                            textAlign: TextAlign.start,
                            style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          TextButton(
                            onPressed: _onRestore,
                            child: const Text(
                              '購入内容を復元する',
                              style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                  color: Colors.blue),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ─── 購入ボタン & 復元リンク ────────────────────────
            Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      // ─── 変更：ローディング中は無効 ────────────────
                      onPressed: _isLoading ? null : _onSubscribe,
                      // ─── 変更：ローディング表示 ──────────────────
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        '初回7日無料 今すぐ登録',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────── 小さなリンクボタン ─────────────────── */
class _PolicyLink extends StatelessWidget {
  final String label;
  final String url;
  const _PolicyLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.bgColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSelectorCard extends StatelessWidget {
  final String? discountLabel;
  final double width;
  final String title;
  final String price;
  final String period;
  final String? smallNote;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanSelectorCard({
    required this.width,
    required this.title,
    required this.price,
    required this.period,
    this.smallNote,
    this.badge,
    this.discountLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.blue : Colors.grey[300]!;
    final bgColor = selected ? Colors.blue[50] : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width,
            height: 100, // 縦幅を固定（必要に応じて値を調整）
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 縦方向は中央揃え
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.blue[800] : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      period,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected ? Colors.blue[800] : Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (smallNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      smallNote!,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.blue[700] : Colors.black45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              bottom: 8,
              right: 8,
              child: Icon(Icons.check_circle, size: 20, color: Colors.blue),
            ),
          if (badge != null && selected)
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
