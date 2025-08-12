import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// App-Open-Ad を管理するシングルトン。
/// * **仕様 v3**: 10 秒クールダウン / 4 時間キャッシュ失効
/// * **未ログイン時は一切表示しない**（ロードもしない）
/// * ログアウト後に復帰しても広告が出ないよう、毎回ログイン状態を確認
class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAdManager._internal();
  static final AppOpenAdManager instance = AppOpenAdManager._internal();

  /* ───────── helpers ───────── */
  String get _adUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/9257395921'
          : 'ca-app-pub-3940256099942544/5575463023';
    }
    return 'ca-app-pub-4495844115981683/6169233197';
  }

  /* ───────── state ───────── */
  AppOpenAd? _appOpenAd;
  DateTime? _loadTime;
  DateTime? _lastShowTime;
  bool _isShowingAd = false;

  bool _shouldShowOnResume = false;

  // ★ 追加: 課金ダイアログ復帰時は次の resume を 1 回だけ無視
  bool _ignoreNextResume = false;
  void ignoreNextResume() => _ignoreNextResume = true; // 外部から呼び出し

  static const _maxCacheDuration = Duration(hours: 4);
  static const _minTimeBetweenShows = Duration(seconds: 10);

  /* ───────── public API ───────── */
  void initialize() {
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('[DEBUG] AppOpenAdManager.initialize → 未ログインなのでスキップ');
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _loadAd(showAfterLoad: true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appOpenAd?.dispose();
  }

  /* ───── WidgetsBindingObserver ───── */
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _shouldShowOnResume = true;
        debugPrint('[DEBUG] lifecycle → $state ⇒ 次回 resume で広告検討');
        break;

      case AppLifecycleState.resumed:
        debugPrint('[DEBUG] lifecycle → resumed '
            '(_should=$_shouldShowOnResume, ignore=$_ignoreNextResume)');
        if (_ignoreNextResume) {                     // ★ 追加
          _ignoreNextResume = false;
          _shouldShowOnResume = false;               // 念のためリセット
          debugPrint('[DEBUG] └─ resume ignored once (purchase flow)');
          return;
        }
        if (_shouldShowOnResume) {
          _shouldShowOnResume = false;
          _showAdIfAvailable();
        }
        break;
      default:
        break;
    }
  }

  /* ───────── ad logic ───────── */
  void _loadAd({bool showAfterLoad = false}) {
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('[DEBUG] _loadAd() skipped → 未ログイン');
      return;
    }
    if (_appOpenAd != null) return;

    debugPrint('[DEBUG] AppOpenAd loading...');
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[DEBUG] AppOpenAd loaded ✅');
          _appOpenAd = ad;
          _loadTime = DateTime.now();
          if (showAfterLoad) _showAdIfAvailable();
        },
        onAdFailedToLoad: (error) {
          debugPrint('[DEBUG] AppOpenAd failed to load ❌ '
              'code=${error.code} message=${error.message}');
          _appOpenAd = null;
        },
      ),
    );
  }

  void _showAdIfAvailable() {
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('[DEBUG] └─ skip: 未ログインなので表示しない');
      return;
    }

    debugPrint('[DEBUG] _showAdIfAvailable() called  '
        'lastShow=$_lastShowTime  adLoaded=${_appOpenAd != null}');

    if (_lastShowTime != null &&
        DateTime.now().difference(_lastShowTime!) < _minTimeBetweenShows) {
      debugPrint('[DEBUG] └─ skip: cooldown中');
      return;
    }

    if (_appOpenAd == null) {
      debugPrint('[DEBUG] └─ skip: 未ロード → _loadAd()');
      _loadAd();
      return;
    }

    if (DateTime.now().difference(_loadTime!) > _maxCacheDuration) {
      debugPrint('[DEBUG] └─ skip: キャッシュ失効 → dispose & reload');
      _appOpenAd!.dispose();
      _appOpenAd = null;
      _loadAd();
      return;
    }

    if (_isShowingAd) return;

    debugPrint('[DEBUG] └─ show() 実行');
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        _lastShowTime = DateTime.now();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _loadAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _loadAd();
      },
    );

    try {
      _appOpenAd!.show();
    } on PlatformException catch (e) {
      if (kDebugMode && e.code == 'recreating_view') {
        debugPrint('[DEBUG] AppOpenAd show skipped ⇒ recreating_view');
        _isShowingAd = false;
        _appOpenAd?.dispose();
        _appOpenAd = null;
        _loadAd();
        return;
      }
      rethrow;
    }
  }
}
