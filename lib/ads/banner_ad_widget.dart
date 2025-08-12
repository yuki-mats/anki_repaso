// lib/ads/banner_ad_widget.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// プラットフォームごとに適切なバナー広告ユニット ID を返す
String getAdBannerUnitId() {
  if (Platform.isAndroid) {
    return kDebugMode
    // デバッグ用の Android テスト広告 ID
        ? 'ca-app-pub-3940256099942544/6300978111'
    // リリース用の Android 広告ユニット ID
        : 'ca-app-pub-4495844115981683/8175496111';
  } else if (Platform.isIOS) {
    return kDebugMode
    // デバッグ用の iOS テスト広告 ID
        ? 'ca-app-pub-3940256099942544/2435281174'
    // リリース用の iOS 広告ユニット ID
        : 'ca-app-pub-4495844115981683/8175496111';
  }
  return '';
}

/// バナー広告を表示するウィジェット
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdReady = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: getAdBannerUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _isAdReady = true;       // 読み込み完了→表示
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdReady = false;      // 読み込み失敗→非表示
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 広告が準備できていない場合はウィジェットごと隠す
    if (!_isAdReady) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8), // 上マージン
        SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
        const SizedBox(height: 8), // 下マージン（誤タップ防止用）
      ],
    );
  }
}
