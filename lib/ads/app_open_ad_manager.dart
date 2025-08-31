import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAdManager._internal();
  static final AppOpenAdManager instance = AppOpenAdManager._internal();

  String get _adUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/9257395921'
          : 'ca-app-pub-3940256099942544/5575463023';
    }
    return 'ca-app-pub-4495844115981683/6169233197';
  }

  AppOpenAd? _appOpenAd;
  DateTime? _loadTime;
  DateTime? _lastShowTime;
  bool _isShowingAd = false;

  bool _shouldShowOnResume = false;
  bool _ignoreNextResume = false;

  void ignoreNextResume() => _ignoreNextResume = true;

  static const _maxCacheDuration = Duration(hours: 4);
  static const _minTimeBetweenShows = Duration(seconds: 10);

  void initialize() {
    // ★ Web の場合は即リターン
    if (kIsWeb) {
      debugPrint('[DEBUG] AppOpenAdManager.initialize → Webなのでスキップ');
      return;
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return; // ★ Web の場合は無視

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _shouldShowOnResume = true;
        break;
      case AppLifecycleState.resumed:
        if (_ignoreNextResume) {
          _ignoreNextResume = false;
          _shouldShowOnResume = false;
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

  void _loadAd({bool showAfterLoad = false}) {
    if (kIsWeb) return; // ★ Web はロードしない
    if (FirebaseAuth.instance.currentUser == null) return;
    if (_appOpenAd != null) return;

    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _loadTime = DateTime.now();
          if (showAfterLoad) _showAdIfAvailable();
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
        },
      ),
    );
  }

  void _showAdIfAvailable() {
    if (kIsWeb) return; // ★ Web は表示しない
    if (FirebaseAuth.instance.currentUser == null) return;

    if (_lastShowTime != null &&
        DateTime.now().difference(_lastShowTime!) < _minTimeBetweenShows) {
      return;
    }

    if (_appOpenAd == null) {
      _loadAd();
      return;
    }

    if (DateTime.now().difference(_loadTime!) > _maxCacheDuration) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
      _loadAd();
      return;
    }

    if (_isShowingAd) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        _lastShowTime = DateTime.now();
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
    } on PlatformException catch (_) {
      _isShowingAd = false;
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _loadAd();
    }
  }
}
