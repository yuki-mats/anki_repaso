// lib/ads/app_open_ad_manager.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  // 2分間は連続して広告をロードしないようにする間隔設定
  static const Duration _minLoadInterval = Duration(minutes: 2);

  // 最後に広告をロードした日時を保持
  DateTime? _lastLoadTime;

  // ロード済みの App Open Ad インスタンス
  AppOpenAd? _appOpenAd;

  // 広告が現在表示中かどうかのフラグ
  bool _isShowingAd = false;

  /// 起動時に広告をロードする
  void loadAd() {
    // 直近のロードから2分未満ならスキップ
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!) < _minLoadInterval) {
      if (kDebugMode) {
        debugPrint('AppOpenAd load skipped: too soon since last load');
      }
      return;
    }
    _lastLoadTime = DateTime.now(); // ロード時間を更新

    final adUnitId = _getAdUnitId(); // 広告ユニットIDを取得
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          // ロード成功時にインスタンスを保持
          _appOpenAd = ad;
          if (kDebugMode) {
            debugPrint('AppOpenAd loaded: $adUnitId');
          }
        },
        onAdFailedToLoad: (error) {
          // ロード失敗時はログ出力のみ
          if (kDebugMode) {
            debugPrint('AppOpenAd failed to load: $error');
          }
        },
      ),
    );
  }

  /// 本番用の広告ユニットIDを返す
  ///
  /// テストデバイスの設定は main.dart 側で行っているため、
  /// ここでは常に本番IDを指定します。
  String _getAdUnitId() {
    return 'ca-app-pub-4495844115981683/6169233197'; // 本番広告ID
  }

  /// エミュレーターかどうかを判定する（必要に応じて拡張可）
  bool _isEmulator() {
    return Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid;
  }

  /// 広告が準備できていて、まだ表示中でなければ表示する
  void showAdIfAvailable() {
    if (_isShowingAd || _appOpenAd == null) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        // 広告を閉じたあと、再度ロードできるようにリセット
        _isShowingAd = false;
        _appOpenAd = null;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        // 表示に失敗しても次回のロードをトライ
        _isShowingAd = false;
        _appOpenAd = null;
        if (kDebugMode) {
          debugPrint('AppOpenAd show failed: $error');
        }
        loadAd();
      },
    );

    _isShowingAd = true;    // 表示中フラグをON
    _appOpenAd!.show();      // 広告を表示
    if (kDebugMode) {
      debugPrint('AppOpenAd is shown.');
    }
  }
}
