// lib/main.dart
//
// HomePage の再表示検知用に RouteObserver を追加した完全版。
// 既存 UI・UX は一切変更していません。

import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';                       // ★追加
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/banner_ad_widget.dart';
import 'firebase_options.dart';
import 'package:repaso/screens/home_page.dart';
import 'package:repaso/screens/library_page.dart';
import 'package:repaso/screens/lobby_page.dart';
import 'package:repaso/screens/forum_page.dart';
import 'package:repaso/screens/my_page.dart';
import 'package:repaso/utils/update_checker.dart';
import 'utils/app_colors.dart';

// ─────────────────────────────────────────────
// RouteObserver  ─ 画面遷移イベント監視用（HomePage の更新など）
// ─────────────────────────────────────────────
final RouteObserver<PageRoute<dynamic>> routeObserver =
RouteObserver<PageRoute<dynamic>>();                    // ★追加

// ─────────────────────────────────────────────
// アプリのライフサイクル検知
// ─────────────────────────────────────────────
class AppLifecycleListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onResumed;

  const AppLifecycleListener({
    Key? key,
    required this.child,
    required this.onResumed,
  }) : super(key: key);

  @override
  _AppLifecycleListenerState createState() => _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends State<AppLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────
// ATT 権限リクエスト（iOS）
// ─────────────────────────────────────────────
Future<void> requestTrackingPermission() async {
  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('Error requesting tracking authorization: $e');
  }
}

// ─────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化（重複ガード）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('already exists') || msg.contains('duplicate-app')) {
      debugPrint('⚠️ Firebase already initialized, skipping.');
    } else {
      rethrow;
    }
  }

  // ATT 要求（iOSのみ）
  if (!kIsWeb && Platform.isIOS) {
    await requestTrackingPermission();
  }

  // Analytics テストイベント
  final analytics = FirebaseAnalytics.instance;
  await analytics.logEvent(name: 'app_launch');

  // 日付ローカライズ
  await initializeDateFormatting('ja_JP', null);

  // AdMob 初期化（Webではスキップ）
  if (!kIsWeb) {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: ['01262462e4ee6bb499fd8becbef443f3']),
    );
    await MobileAds.instance.initialize();
  }

  // RevenueCat SDK 初期化（Webではスキップ）
  if (!kIsWeb) {
    Purchases.setLogLevel(LogLevel.debug);
    const iosApiKey = 'appl_aIuuLscAmVhWrSRAVFhUvpBnjpy';
    const androidApiKey = 'goog_あなたの_Android_Public_SDK_Key';
    final key = Platform.isIOS ? iosApiKey : androidApiKey;
    await Purchases.configure(
      PurchasesConfiguration(key)
        ..appUserID = FirebaseAuth.instance.currentUser?.uid,
    );

    // 1) 初回起動時に現在のカスタマー情報を取得してログ出力
    try {
      final info = await Purchases.getCustomerInfo();
      debugPrint('[DEBUG] 初回プラン情報: '
          'activeEntitlements=${info.entitlements.active.keys.toList()}');
      final isPro = info.entitlements.active['Pro']?.isActive ?? false;
      debugPrint('[DEBUG] isPro: $isPro');
    } catch (e) {
      debugPrint('[DEBUG] Purchases.getCustomerInfo error: $e');
    }

    // 2) 更新があったときにもログを出力するリスナーを登録
    Purchases.addCustomerInfoUpdateListener((info) {
      debugPrint('[DEBUG] プラン情報更新: '
          'activeEntitlements=${info.entitlements.active.keys.toList()}');
      final isProUpdated = info.entitlements.active['Pro']?.isActive ?? false;
      debugPrint('[DEBUG] isPro（更新後）: $isProUpdated');
    });
  }

  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// MyApp
// ─────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
  FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Repaso',
      theme: ThemeData(
        fontFamily: kIsWeb ? 'NotoSansJP' : null,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.gray900,
          surfaceTintColor: Colors.white,
          titleTextStyle: TextStyle(
            color: AppColors.gray900,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(size: 18, color: AppColors.gray700),
          toolbarHeight: 50,
        ),
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.blue600,
          unselectedItemColor: AppColors.gray536,
          selectedIconTheme: IconThemeData(size: 28),
          unselectedIconTheme: IconThemeData(size: 28),
          selectedLabelStyle: TextStyle(fontSize: 10),
          unselectedLabelStyle: TextStyle(fontSize: 10),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      navigatorObservers: [
        observer,
        routeObserver,                                  // ★追加
      ],
      home: const StartupScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// StartupScreen
// ─────────────────────────────────────────────
class StartupScreen extends StatefulWidget {
  const StartupScreen({Key? key}) : super(key: key);

  @override
  _StartupScreenState createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final shouldNavigate = await UpdateChecker.checkForUpdate(context);
      if (!shouldNavigate) return;
      final isLogin = FirebaseAuth.instance.currentUser != null;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLogin ? const MainPage() : const LobbyPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}

// ─────────────────────────────────────────────
// MainPage
// ─────────────────────────────────────────────
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    HomePage(),
    FolderListPage(title: 'ライブラリ'),
    ForumPage(),
    MyPage(),
  ];
  final AppOpenAdManager _adManager = AppOpenAdManager();

  @override
  void initState() {
    super.initState();
    _adManager.loadAd();
  }

  @override
  Widget build(BuildContext context) {
    return AppLifecycleListener(
      onResumed: _adManager.showAdIfAvailable,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2.5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                currentIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.source_rounded), label: 'ライブラリ'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.comment), label: 'フォーラム'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.account_circle), label: 'マイページ'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
