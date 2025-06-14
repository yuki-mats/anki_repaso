import 'package:flutter/material.dart';
import 'package:flutter/services.dart';                // PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repaso/screens/terms_of_service_page.dart';
import 'package:url_launcher/url_launcher.dart';       // ← リンク用

// ====== それぞれの外部リンク先 =============================================
const _kTermsUrl   = 'https://example.com/terms';
const _kPolicyUrl  = 'https://right-saxophone-1b5.notion.site/17be144de0eb807c8e1fe6da3de3f92c';
const _kCancelUrl  = 'https://support.apple.com/ja-jp/HT202039';
// ============================================================================

class PaywallPage extends StatefulWidget {
  const PaywallPage({Key? key}) : super(key: key);
  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  int _selectedIndex = 1;                               // 0: 月額, 1: 年額
  Package? _monthlyPackage;
  Package? _annualPackage;

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
        _annualPackage  = current?.annual;
      });
    } catch (e) {
      debugPrint('Offerings fetch error: $e');
    }
  }

  void _onSelectPlan(int index) => setState(() => _selectedIndex = index);

  Future<void> _onSubscribe() async {
    final pkg = _selectedIndex == 0 ? _monthlyPackage : _annualPackage;
    if (pkg == null) return;                            // まだロード中

    try {
      final info = await Purchases.purchasePackage(pkg);  // v6+
      if (info.entitlements.active.containsKey('Pro')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ご登録ありがとうございました！')),
        );
        Navigator.of(context).pop();
      }
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('購入に失敗しました: ${e.message}')),
      );
    }
  }

  Future<void> _onRestore() async {
    try {
      await Purchases.restorePurchases();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入履歴を復元しました')),
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('復元に失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMonthly    = _selectedIndex == 0;
    final monthlyPrice = _monthlyPackage?.storeProduct.priceString ?? '---';
    final annualPrice  = _annualPackage ?.storeProduct.priceString ?? '---';

    // 24px padding ×2 + 16px gap
    final cardWidth =
        (MediaQuery.of(context).size.width - 24 * 2 - 16) / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: true,
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── タイトル & 説明 ───────────────────────────
                    Text(
                      '暗記プラス 寄付プラン',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '暗記プラスの開発者へ寄付することができます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    // ─── 機能リスト ────────────────────────────────
                    const _FeatureRow(text: '暗記プラスの継続的な運営と改善をサポート'),
                    const _FeatureRow(text: '開発者のモチベーションアップと品質向上'),
                    const _FeatureRow(text: 'より良い学習体験を多くの人に届ける手助け'),
                    const _FeatureRow(text: '皆様からのご支援が、アプリのさらなる成長を支えます'),
                    const SizedBox(height: 8),

                    // ─── プランセレクター ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PlanSelectorCard(
                          width: cardWidth,
                          title: '月額',
                          price: monthlyPrice,
                          period: '/月',
                          smallNote: '自動更新',
                          selected: isMonthly,
                          onTap: () => _onSelectPlan(0),
                        ),
                        const SizedBox(width: 16),
                        _PlanSelectorCard(
                          width: cardWidth,
                          title: '年額',
                          price: annualPrice,
                          period: '/年',
                          smallNote: '自動更新',
                          badge: 'おすすめ',
                          selected: !isMonthly,
                          onTap: () => _onSelectPlan(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ─── 利用規約・プライバシー・解約リンク ────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        children: [
                          // 利用規約リンク
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                            ),
                            child: const Text(
                              '利用規約',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          // プライバシーポリシーも同じ画面へ遷移
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                            ),
                            child: const Text(
                              'プライバシーポリシー',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          // 解約方法は外部リンク
                          _PolicyLink(label: '解約方法', url: _kCancelUrl),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ─── 価格フッター ────────────────────────────────
                    const Text(
                      '年額 ¥4,980 (¥415/月相当) – 期間終了 24 時間前までに解約しない限り自動更新されます。',
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                  ],
                ),
              ),
            ),

            // ─── 購入ボタン & 復元リンク ────────────────────────
            Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 6),
                    const Text('縛りなし、１週間無料',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _onSubscribe,
                      child: const Text(
                        '今すぐ登録',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                // --------------- 復元リンク ----------------------
                TextButton(
                  onPressed: _onRestore,
                  child: const Text(
                    '購入内容を復元する',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
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
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

/* ───────── 既存 UI コンポーネントはそのまま ─────────── */

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _PlanSelectorCard extends StatelessWidget {
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
            constraints: const BoxConstraints(minHeight: 115),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.blue[800] : Colors.black,
                        )),
                    const SizedBox(width: 4),
                    Text(period,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.blue[800] : Colors.black54,
                        )),
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
                if (selected)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.check_circle,
                        size: 20, color: Colors.blue),
                  ),
              ],
            ),
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
                child: Text(badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}
