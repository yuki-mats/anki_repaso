import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  // 2分ごとに広告をリロードする間隔
  static const Duration _reloadInterval = Duration(minutes: 2);

  late BannerAd _bannerAd;
  bool _isAdLoaded = false;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    // 初回ロード
    _loadBannerAd();
    // 定期的に新しい広告をロード
    _reloadTimer = Timer.periodic(_reloadInterval, (_) {
      _loadBannerAd();
    });
  }

  void _loadBannerAd() {
    // 既存の広告がロード済みなら廃棄してから新しくロード
    if (_isAdLoaded) {
      _bannerAd.dispose();
      _isAdLoaded = false;
    }

    // 非エンジニア向け：デバッグ時には必ずテスト広告を使う
    final adUnitId = kDebugMode
        ? 'ca-app-pub-3940256099942544/6300978111' // Google 提供のテスト用バナー広告ID
        : 'ca-app-pub-4495844115981683/7136073776'; // 本番用広告ID

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // ロード成功時に画面を更新して表示
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          // エラー発生時は廃棄してログ出力
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load(); // ロード開始
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 広告がまだロードされていなければ何も表示しない
    if (!_isAdLoaded) return const SizedBox.shrink();

    // デバッグモードではユーザーの誤タップ防止のためタップを無効化
    final adWidget = kDebugMode
        ? AbsorbPointer(child: AdWidget(ad: _bannerAd))
        : AdWidget(ad: _bannerAd);

    return Container(
      // 広告エリアの背景色（任意で変更可）
      color: Colors.green[100],
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: adWidget,
    );
  }
}
