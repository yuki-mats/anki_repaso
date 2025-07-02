// lib/ads/app_open_ad_manager.dart
//
// ■ 目的
//   1. アプリを **バックグラウンド→フォアグラウンド** したときだけ
//      App-Open 広告を表示する。
//   2. アプリ起動直後（Cold Start）には表示しない。
//   3. 広告を閉じたら即ロードしておき、次回の復帰で表示できるようにする。
//   4. 2 分以内の連続ロードはスキップして無駄なリクエストを抑制する。
//
//   ※ MainPage → AppLifecycleListener で
//      `onResumed: _adManager.showAdIfAvailable` が呼ばれる前提に合わせています。
//   ※ それ以外の既存 UI／ロジックには一切触れていません。

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  /* ───────── 設定 ───────── */

  /// 2 分以内の再ロードを抑止
  static const Duration _minLoadInterval = Duration(minutes: 2);

  /* ───────── 内部状態 ───────── */

  DateTime? _lastLoadTime;   // 最後にロードを試みた時刻
  AppOpenAd? _appOpenAd;     // キャッシュしている App-Open Ad
  bool _isShowingAd = false; // 表示中フラグ

  /* ───────── 広告ロード ───────── */

  /// バックグラウンドでも事前ロードしておく
  void loadAd() {
    final now = DateTime.now();

    // 連続ロード間隔チェック
    if (_lastLoadTime != null &&
        now.difference(_lastLoadTime!) < _minLoadInterval) {
      debugPrint('⏱ load skipped (within $_minLoadInterval)');
      return;
    }
    _lastLoadTime = now;

    final adUnitId = _getAdUnitId();
    debugPrint('🔄 AppOpenAd.load() → $adUnitId');

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ onAdLoaded');
          _appOpenAd = ad;
          // ここでは表示しない：次回 resume 時に show()
        },
        onAdFailedToLoad: (error) =>
            debugPrint('❌ onAdFailedToLoad: $error'),
      ),
    );
  }

  /* ───────── フォアグラウンド復帰時に呼ぶ ───────── */

  void showAdIfAvailable() {
    debugPrint(
      '🔍 showAdIfAvailable → isShowing=$_isShowingAd, ad=${_appOpenAd == null ? "null" : "ready"}',
    );

    // すでに全画面表示中ならスキップ
    if (_isShowingAd) return;

    // 広告が無ければロードだけして次回に備える
    if (_appOpenAd == null) {
      loadAd();
      return;
    }

    // 表示準備 OK
    _isShowingAd = true;
    _appOpenAd!.fullScreenContentCallback = _callback;
    _appOpenAd!.show();
    debugPrint('▶︎ AppOpenAd shown');
  }

  /* ───────── コールバック定義 ───────── */

  FullScreenContentCallback<AppOpenAd> get _callback =>
      FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('✖️ Ad dismissed');
          _isShowingAd = false;
          _appOpenAd = null;
          ad.dispose();
          loadAd(); // 次回復帰に備えてロード
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ Ad failed to show: $error');
          _isShowingAd = false;
          _appOpenAd = null;
          ad.dispose();
          loadAd(); // リトライ
        },
      );

  /* ───────── ユニット ID 判定 ───────── */

  String _getAdUnitId() {
    if (kDebugMode) {
      // Google が提供するテスト用 ID（Android / iOS）
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/3419835294'
          : 'ca-app-pub-3940256099942544/5575463023';
    }
    // 本番ユニット ID
    return 'ca-app-pub-4495844115981683/6169233197';
  }
}
