import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // 年額の月割表示を通貨書式で出すため

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
  int _selectedIndex = 1; // 0: 月額, 1: 年額（デフォルトは年額）
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

    // 年額の月割表示（通貨表記をストア通貨に合わせる）
    final annualCurrency = _annualPackage?.storeProduct.currencyCode;
    final annualTotal = _annualPackage?.storeProduct.price;
    final annualMonthlyEq = (annualCurrency != null && annualTotal != null)
        ? NumberFormat.simpleCurrency(name: annualCurrency)
        .format(annualTotal / 12)
        : '---';

    // 24px padding ×2 + 16px gap（既存計算そのまま）
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
                                '1日15分の積み重ねで、合格率が変わる。\nAnki Proで、暗記を3倍速に。',
                            textAlign: TextAlign.center,
                            style:
                            TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 24),
                          // ─── プランセレクター ─────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 年額を上に。文字と割引率の配置を画像イメージに合わせる
                              _PlanSelectorCard(
                                width: double.infinity,
                                title: '年額プラン',
                                price: annualMonthlyEq, // 月割表示（例: ¥300）
                                period: '/月',
                                // 画像の注釈テキストに合わせて右下に小さく表示
                                smallNote: '$annualPriceで毎年更新',
                                discountLabel: '55％割引', // 左上のピルで強調
                                selected: !isMonthly,
                                onTap: () => _onSelectPlan(1),
                              ),
                              const SizedBox(height: 16),
                              // 月額（下）
                              _PlanSelectorCard(
                                width: double.infinity,
                                title: '月額プラン',
                                price: monthlyPrice,
                                period: '/月',
                                smallNote: '自動更新',
                                selected: isMonthly,
                                onTap: () => _onSelectPlan(0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // ─── 機能リスト ────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Column(
                              children: const [
                                _FeatureRow(
                                  icon: Icons.block, // 例: 広告の削除イメージ
                                  bgColor: Colors.blueAccent,
                                  title: '広告の削除',
                                  description: 'アプリ内の広告をすべて削除します',
                                ),
                                _FeatureRow(
                                  icon: Icons.auto_awesome, // 例: 記憶度サポート
                                  bgColor: Colors.purpleAccent,
                                  title: 'まとめて学習',
                                  description: '覚えていない問題を重点的に復習できます',
                                ),
                                _FeatureRow(
                                  icon: Icons.sync, // 例: 進行状況の同期
                                  bgColor: Colors.cyan,
                                  title: 'お気に入り設定',
                                  description: 'ホーム画面に問題集をセットし学習できます。',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ─── 利用規約・プライバシー・解約リンク ────────────
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              InkWell(
                                onTap: () => _launchUrl(_kTermsUrl),
                                child: const Text(
                                  '利用規約',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87, // 文字色
                                    decoration: TextDecoration.underline, // 下線
                                    decorationColor: Colors.black54,         // 下線の色
                                    decorationThickness: 0.8,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _launchUrl(_kPolicyUrl),
                                child: const Text(
                                  'プライバシーポリシー',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87, // 文字色
                                    decoration: TextDecoration.underline, // 下線
                                    decorationColor: Colors.black54,         // 下線の色
                                    decorationThickness: 0.8,
                                  ),
                                ),
                              ),
                              _PolicyLink(label: 'プランの解約について', url: _kCancelUrl),
                            ],
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
                      onPressed: _isLoading ? null : _onSubscribe,
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
                        '７日間無料ではじめる',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'App Storeにて、いつでもキャンセルできます。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
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
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black87, // 文字色を統一
          decoration: TextDecoration.underline,
          decorationColor: Colors.black54, // 下線の色
          decorationThickness: 0.8,        // 下線の太さ
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final String title;
  final String description;

  const _FeatureRow({
    super.key,
    required this.icon,
    required this.bgColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左：角丸スクエア背景のアイコン
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          // 右：タイトル（上）＋説明（下）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                // 説明
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
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
  final String title;   // 「年額プラン」「月額プラン」
  final String price;   // 表示価格
  final String period;  // /月
  final String? smallNote; // 右下の注釈
  final String? badge;  // 互換のため残置（未使用でOK）
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
          // 本体カード
          Container(
            width: width,
            height: 100, // 既存の高さを維持
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 既存仕様
              children: [
                // ── 1行目：チェック＋プラン名（左）／価格＋単位（右） ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ← 追加：選択中だけプラン名の左にチェックを表示
                    if (selected) ...[
                      const Icon(Icons.check_circle,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 6),
                    ],

                    // プラン名（年額プラン／月額プラン）
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 右端：価格（数値大＋通貨記号小）＋単位（小）を横一列で右寄せ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RichText(
                          textAlign: TextAlign.right,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: price.isNotEmpty ? price.substring(0, 1) : '', // 通貨記号部分（例: ¥）
                                style: TextStyle(
                                  fontSize: 18, // 小さく
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Colors.blue[800] : Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: price.length > 1 ? price.substring(1) : '', // 数値部分
                                style: TextStyle(
                                  fontSize: 32, // 大きく
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Colors.blue[800] : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          period, // /月
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            color: selected ? Colors.blue[800] : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2行目：注釈（右寄せ）
                if (smallNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Spacer(),
                        Text(
                          smallNote!,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.blue[700] : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 左上：割引率のピル（必要なときだけ）
          if (discountLabel != null)
            Positioned(
              top: -12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.blue[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? Colors.blue[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: discountLabel!.replaceAll(RegExp(r'[^0-9]'), ''), // 数字部分
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontSize: 14, // 数字を大きく
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: discountLabel!.replaceAll(RegExp(r'[0-9]'), ''), // %割引部分
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontSize: 12, // 記号・文字を小さく
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 右上バッジ（互換のため残置）
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

