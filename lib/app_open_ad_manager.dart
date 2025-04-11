// lib/app_open_ad_manager.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;

  /// App Open Ad をロードする
  void loadAd() {
    // ※ 実際の広告ユニットID（ここでは仮の値 'ca-app-pub-4495844115981683/6169233197'）に置き換えてください
    AppOpenAd.load(
      adUnitId: 'ca-app-pub-4495844115981683/6169233197',
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          if (kDebugMode) {
            print('App Open Ad loaded.');
          }
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('App Open Ad failed to load: $error');
          }
        },
      ),
    );
  }

  /// 広告がロード済みで、かつ表示中でなければ表示する
  void showAdIfAvailable() {
    if (_isShowingAd || _appOpenAd == null) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        _appOpenAd = null;
        loadAd(); // 広告が閉じたら再ロード
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        _appOpenAd = null;
        if (kDebugMode) {
          print('App Open Ad failed to show: $error');
        }
        loadAd();
      },
    );

    _isShowingAd = true;
    _appOpenAd!.show();
    if (kDebugMode) {
      print('App Open Ad is shown.');
    }
  }
}
