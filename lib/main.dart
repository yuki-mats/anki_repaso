// lib/main.dart
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:repaso/screens/library_page.dart';
import 'ads/banner_ad_widget.dart';
import 'firebase_options.dart';
import 'package:repaso/screens/home_page.dart';
import 'package:repaso/screens/lobby_page.dart';
import 'package:repaso/screens/forum_page.dart';
import 'package:repaso/screens/my_page.dart';
import 'package:repaso/utils/update_checker.dart';
import 'utils/app_colors.dart';

// ─────────────────────────────────────────────
// RouteObserver  ─ 画面遷移イベント監視用（HomePage の更新など）
// ─────────────────────────────────────────────
final RouteObserver<PageRoute<dynamic>> routeObserver =
RouteObserver<PageRoute<dynamic>>();

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
    // 起動広告表示ロジック削除につき何もしない
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

  // ───────────────────────────────────────────
  // Google Mobile Ads SDK 初期化 & テストデバイス登録
  await MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: <String>[
        'BBF5B92D-5E84-4B46-905C-ED71FB328CFF',
        'CF36ECD6-F4DC-4B1F-A468-6FFC2757889A',
      ],
    ),
  );
  // ───────────────────────────────────────────

  // ATT 要求（iOSのみ）
  if (!kIsWeb && Platform.isIOS) {
    await requestTrackingPermission();
  }

  // Analytics テストイベント
  final analytics = FirebaseAnalytics.instance;
  await analytics.logEvent(name: 'app_launch');

  // 日付ローカライズ
  await initializeDateFormatting('ja_JP', null);

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

    // 初回・更新リスナーはそのまま残す
    try {
      final info = await Purchases.getCustomerInfo();
      debugPrint('[DEBUG] 初回プラン情報: '
          'activeEntitlements=${info.entitlements.active.keys.toList()}');
    } catch (e) {
      debugPrint('[DEBUG] Purchases.getCustomerInfo error: $e');
    }
    Purchases.addCustomerInfoUpdateListener((info) {
      debugPrint('[DEBUG] プラン情報更新: '
          'activeEntitlements=${info.entitlements.active.keys.toList()}');
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
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.black54,
          selectedIconTheme: const IconThemeData(size: 28),
          unselectedIconTheme: const IconThemeData(size: 28),
          selectedLabelStyle: const TextStyle(fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      navigatorObservers: [
        observer,
        routeObserver,
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
  bool _isPro = false;
  final List<Widget> _pages = [
    HomePage(),
    LibraryPage(),
    ForumPage(),
    MyPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
    Purchases.addCustomerInfoUpdateListener((info) {
      final isPro = info.entitlements.active['Pro']?.isActive ?? false;
      if (mounted && _isPro != isPro) {
        setState(() => _isPro = isPro);
      }
    });
  }

  Future<void> _loadEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      setState(() => _isPro =
          info.entitlements.active['Pro']?.isActive ?? false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),

      // ② bottomNavigationBar を Column にして、上部にバナー広告を配置
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── バナー広告をここに表示 ──
          const BannerAdWidget(),

          // ── 既存のボトムナビゲーションバー ──
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
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'ホーム',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.source_outlined),
                  activeIcon: Icon(Icons.source_rounded),
                  label: 'ライブラリ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.comment_outlined),
                  activeIcon: Icon(Icons.comment),
                  label: 'フォーラム',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle_outlined),
                  activeIcon: Icon(Icons.account_circle),
                  label: 'マイページ',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
