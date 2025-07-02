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
  // ⇒ リロード間隔を2分→5分に延長
  static const Duration _reloadInterval = Duration(minutes: 5);

  late BannerAd _bannerAd;
  bool _isAdLoaded = false;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _reloadTimer = Timer.periodic(_reloadInterval, (_) => _loadBannerAd());
  }

  void _loadBannerAd() {
    if (_isAdLoaded) {
      _bannerAd.dispose();
      _isAdLoaded = false;
    }

    final adUnitId = kDebugMode
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-4495844115981683/7136073776';

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // ⇒ State破棄後の setState を防止
          if (!mounted) return;
          setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // ⇒ デバッグ時のみログ出力
          if (kDebugMode) {
            debugPrint('BannerAd failed to load: $error');
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded) return const SizedBox.shrink();

    final adView = kDebugMode
        ? AbsorbPointer(child: AdWidget(ad: _bannerAd))
        : AdWidget(ad: _bannerAd);

    return Container(
      color: Colors.green[100],
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: adView,
    );
  }
}
