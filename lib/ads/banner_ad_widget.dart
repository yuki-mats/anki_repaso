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
  late BannerAd _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    // BannerAd のインスタンスを生成
    _bannerAd = BannerAd(
      adUnitId: getAdBannerUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
      ),
    );

    // 広告をロード
    _bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      // 広告がロードされるまで何も表示しない
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        // 広告本体
        Container(
          width: _bannerAd.size.width.toDouble(),
          height: _bannerAd.size.height.toDouble(),
          alignment: Alignment.center,
          child: AdWidget(ad: _bannerAd),
        ),
        // SafeArea を挿入して誤タップを防止
        const SizedBox(height: 16),
      ],
    );
  }
}
