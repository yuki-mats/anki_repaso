// lib/ads/app_open_ad_manager.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  // 2分間は連続して広告をロードしないようにする間隔設定
  static const Duration _minLoadInterval = Duration(minutes: 0);

  // 最後に広告をロードした日時を保持
  DateTime? _lastLoadTime;

  // ロード済みの App Open Ad インスタンス
  AppOpenAd? _appOpenAd;

  // 広告が現在表示中かどうかのフラグ
  bool _isShowingAd = false;

  /// 起動時に広告をロードする
  void loadAd() {
    debugPrint('🔄 loadAd() called');
    final now = DateTime.now();
    if (_lastLoadTime != null) {
      final diff = now.difference(_lastLoadTime!);
      debugPrint('▶︎ lastLoadTime=$_lastLoadTime, now=$now, diff=${diff.inSeconds}s');
    }
    // ロード間隔チェック
    if (_lastLoadTime != null && now.difference(_lastLoadTime!) < _minLoadInterval) {
      debugPrint('⏱ load skipped (too soon)');
      return;
    }

    _lastLoadTime = now;
    debugPrint('✅ _lastLoadTime updated to $_lastLoadTime');

    final adUnitId = _getAdUnitId();
    debugPrint('🔑 loadAd using unitId=$adUnitId');
    // --- lib/ads/app_open_ad_manager.dart の該当箇所のみ抜粋 ---
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          debugPrint('✅ onAdLoaded! ad=$ad, unitId=$adUnitId');
          // ↓ 以下をコメントアウトまたは削除し、
          //    ロード完了時に即時表示しないようにする
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ onAdFailedToLoad: $error');
        },
      ),
    );
    debugPrint('🔄 AppOpenAd.load() called with adUnitId=$adUnitId');
  }

  String _getAdUnitId() {
    if (kDebugMode) {
      final id = Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/3419835294'
          : 'ca-app-pub-3940256099942544/5575463023';
      debugPrint('⚙️ DEBUG mode adUnitId: $id');
      return id;
    }
    const prodId = 'ca-app-pub-4495844115981683/6169233197';
    debugPrint('⚙️ RELEASE mode adUnitId: $prodId');
    return prodId;
  }

  bool _isEmulator() {
    return Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid;
  }

  void showAdIfAvailable() {
    debugPrint('🔍 showAdIfAvailable() called: _isShowingAd=$_isShowingAd, _appOpenAd is ${_appOpenAd == null ? "null" : "ready"}');
    if (_isShowingAd) {
      debugPrint('⏱ show skipped (_isShowingAd==true)');
      return;
    }
    if (_appOpenAd == null) {
      debugPrint('⚠️ show skipped (_appOpenAd==null)');
      return;
    }

    debugPrint('🔧 attaching FullScreenContentCallback');
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✖️ Ad dismissed');
        _isShowingAd = false;
        _appOpenAd = null;
        loadAd();
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Ad failed to show: $error');
        _isShowingAd = false;
        _appOpenAd = null;
        ad.dispose();
        loadAd();
      },
    );

    _isShowingAd = true;
    debugPrint('▶︎ calling ad.show()');
    _appOpenAd!.show();
    debugPrint('✅ AppOpenAd is shown.');
  }
}
