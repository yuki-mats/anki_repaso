import 'package:flutter/material.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({Key? key}) : super(key: key);

  @override
  _PaywallPageState createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  int _selectedIndex = 1; // 0: 月額, 1: 年額

  void _onSelectPlan(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onSubscribe() {
    // TODO: 購読処理を実装
  }

  @override
  Widget build(BuildContext context) {
    final isMonthly = _selectedIndex == 0;
    // 24px padding on each side + 16px gap between cards
    final cardWidth = (MediaQuery.of(context).size.width - 24 * 2 - 16) / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_outlined, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          '暗記プラス',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 上部スクロール可能エリア
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // ヒーロータイトル
                    Text(
                      'Proプランですべて解放',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '300問までまとめて解ける、画像3枚添付、全フィルター利用など',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    // 機能リスト
                    const _FeatureRow(text: 'まとめて解く問題数の上限を300問に拡大'),
                    const _FeatureRow(text: '暗記セット作成数の上限を撤廃'),
                    const _FeatureRow(text: '各種フィルター機能を全て開放'),
                    const _FeatureRow(text: '問題作成時に画像を3枚まで添付可能に'),
                    const SizedBox(height: 32),

                    // プランセレクター
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PlanSelectorCard(
                          width: cardWidth,
                          title: '月額',
                          price: '¥980',
                          period: '/月',
                          selected: isMonthly,
                          onTap: () => _onSelectPlan(0),
                        ),
                        const SizedBox(width: 16),
                        _PlanSelectorCard(
                          width: cardWidth,
                          title: '年額',
                          price: '¥4,980',
                          period: '/年',
                          smallNote: '(¥415/月相当)',
                          badge: 'Most Popular',
                          selected: !isMonthly,
                          onTap: () => _onSelectPlan(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 下部：購入ボタン＆フッター
            Column(
              children: [
                // ノーコミットテキスト
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 6),
                    const Text('縛りなし、１週間無料',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8,),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _onSubscribe,
                      child: const Text(
                        '今すぐ登録',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '年額 ¥4,980 (¥415/月相当)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

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
              mainAxisSize: MainAxisSize.min,          // 子に合わせて伸縮
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
                    child:
                    Icon(Icons.check_circle, size: 20, color: Colors.blue),
                  ),
              ],
            ),
          ),

          if (badge != null && selected)
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(badge!,
                    style:
                    const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}
