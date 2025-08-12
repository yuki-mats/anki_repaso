// lib/main.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';                 // ★ 追加
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/banner_ad_widget.dart';
import 'package:repaso/utils/tracking_permission.dart';
import 'package:repaso/utils/paywall_manager.dart';
import 'package:repaso/utils/update_checker.dart';
import 'utils/app_colors.dart';
import 'package:repaso/screens/home_page.dart';
import 'package:repaso/screens/library_page.dart';
import 'package:repaso/screens/forum_page.dart';
import 'package:repaso/screens/my_page.dart';
import 'package:repaso/screens/lobby_page.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver =
RouteObserver<PageRoute<dynamic>>();

/// ─────────────────────────────────────────────
/// 起動広告を初期化すべきか判定
/// ─────────────────────────────────────────────
Future<bool> _shouldInitAppOpenAd(String uid) async {
  try {
    if (uid.isEmpty) {
      debugPrint('[DEBUG] initAd? → 未ログインなので false');
      return false;
    }

    final info  = await Purchases.getCustomerInfo();
    final isPro = info.entitlements.active['Pro']?.isActive ?? false;
    if (isPro) {
      debugPrint('[DEBUG] initAd? → Pro ユーザーなので false');
      return false;
    }

    final prefs          = await SharedPreferences.getInstance();
    final currentVersion = (await PackageInfo.fromPlatform()).version;
    final lastVersion    = prefs.getString('lastPaywallVersion_$uid');

    final result = lastVersion == currentVersion;
    debugPrint('[DEBUG] initAd? → last=$lastVersion  current=$currentVersion  ⇒ $result');
    return result;
  } catch (e) {
    debugPrint('[_shouldInitAppOpenAd] error: $e');
    return false; // 失敗時は安全側
  }
}

/// ─────────────────────────────────────────────
/// main()
/// ─────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  /* RevenueCat ----------------------------------------------- */
  if (!kIsWeb) {
    Purchases.setLogLevel(LogLevel.debug);
    const iosKey     = 'appl_aIuuLscAmVhWrSRAVFhUvpBnjpy';
    const androidKey = 'goog_あなたの_Android_Public_SDK_Key';
    final rcKey      = Platform.isIOS ? iosKey : androidKey;
    await Purchases.configure(
      PurchasesConfiguration(rcKey)
        ..appUserID = FirebaseAuth.instance.currentUser?.uid,
    );
  }

  /* Google Mobile Ads --------------------------------------- */
  await MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: const [
      'BBF5B92D-5E84-4B46-905C-ED71FB328CFF',
      'CF36ECD6-F4DC-4B1F-A468-6FFC2757889A',
    ]),
  );

  /* ATT (iOS) ----------------------------------------------- */
  await requestTrackingPermission();

  /* Intl ロケール初期化（ja_JP）------------------------------ */
  await initializeDateFormatting('ja_JP', null);                  // ★ 追加

  /* App Open Ad 初期化判定 ---------------------------------- */
  final uid    = FirebaseAuth.instance.currentUser?.uid ?? '';
  final initAd = await _shouldInitAppOpenAd(uid);
  if (initAd) {
    AppOpenAdManager.instance.initialize();
    debugPrint('[DEBUG] AppOpenAdManager initialized');
  } else {
    debugPrint('[DEBUG] AppOpenAdManager NOT initialized');
  }

  runApp(const MyApp());
}

/// ─────────────────────────────────────────────
/// MyApp
/// ─────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static final FirebaseAnalyticsObserver observer =
  FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Repaso',
      navigatorObservers: [observer, routeObserver],
      theme: _theme,
      home: const StartupScreen(),
    );
  }

  ThemeData get _theme => ThemeData(
    fontFamily: kIsWeb ? 'NotoSansJP' : null,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.gray900,
      surfaceTintColor: Colors.white,
      titleTextStyle: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900),
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
  );
}

/// ─────────────────────────────────────────────
/// StartupScreen – アップデート確認 & ルーティング
/// ─────────────────────────────────────────────
class StartupScreen extends StatefulWidget {
  const StartupScreen({Key? key}) : super(key: key);
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final ok = await UpdateChecker.checkForUpdate(context);
      if (!ok || !mounted) return;

      final isLogin = FirebaseAuth.instance.currentUser != null;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => isLogin ? const MainPage() : const LobbyPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

/// ─────────────────────────────────────────────
/// MainPage – PaywallManager 呼び出し
/// ─────────────────────────────────────────────
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _isPro = false;
  final _pages = [HomePage(), LibraryPage(), ForumPage(), MyPage()];

  @override
  void initState() {
    super.initState();
    _loadEntitlement();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaywallManager.maybeShow(context: context, uid: uid);
    });

    Purchases.addCustomerInfoUpdateListener((info) {
      final isPro = info.entitlements.active['Pro']?.isActive ?? false;
      if (mounted && _isPro != isPro) setState(() => _isPro = isPro);
    });
  }

  Future<void> _loadEntitlement() async {
    final info = await Purchases.getCustomerInfo();
    setState(() => _isPro = info.entitlements.active['Pro']?.isActive ?? false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _pages),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isPro) const BannerAdWidget(),
        BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                label: 'ホーム',
                activeIcon: Icon(Icons.home)),
            BottomNavigationBarItem(
                icon: Icon(Icons.source_outlined),
                label: 'ライブラリ',
                activeIcon: Icon(Icons.source_rounded)),
            BottomNavigationBarItem(
                icon: Icon(Icons.comment_outlined),
                label: 'フォーラム',
                activeIcon: Icon(Icons.comment)),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined),
                label: 'マイページ',
                activeIcon: Icon(Icons.account_circle)),
          ],
        ),
      ],
    ),
  );
}
