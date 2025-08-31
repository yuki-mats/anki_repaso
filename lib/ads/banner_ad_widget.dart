import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

String getAdBannerUnitId() {
  if (Platform.isAndroid) {
    return kDebugMode
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-4495844115981683/8175496111';
  } else if (Platform.isIOS) {
    return kDebugMode
        ? 'ca-app-pub-3940256099942544/2435281174'
        : 'ca-app-pub-4495844115981683/8175496111';
  }
  return '';
}

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

    // ★ Web の場合は広告をロードしない
    if (kIsWeb) return;

    _bannerAd = BannerAd(
      adUnitId: getAdBannerUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _isAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdReady = false;
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
    // Web の場合は常に非表示
    if (kIsWeb) return const SizedBox.shrink();
    if (!_isAdReady) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
