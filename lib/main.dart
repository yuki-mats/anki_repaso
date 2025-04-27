import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repaso/home_page.dart';
import 'package:repaso/lobby_page.dart';
import 'package:repaso/official_list_page.dart';
import 'package:repaso/utils/update_checker.dart';
import 'forum_page.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';
import 'my_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/banner_ad_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

class AppLifecycleListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onRestart;
  final VoidCallback onShow;
  const AppLifecycleListener({
    Key? key,
    required this.child,
    required this.onRestart,
    required this.onShow,
  }) : super(key: key);

  @override
  _AppLifecycleListenerState createState() => _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends State<AppLifecycleListener> with WidgetsBindingObserver {
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
      widget.onRestart();
    }
  }
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

Future<void> requestTrackingPermission() async {
  try {
    final trackingStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (trackingStatus == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    final newStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
    print('Tracking Status: $newStatus');
  } catch (e) {
    print('トラッキング許可リクエスト中にエラーが発生しました: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Analytics テストイベント送信
  final analytics = FirebaseAnalytics.instance;
  await analytics.logEvent(name: 'app_launch');

  // 日付ローカライズ
  await initializeDateFormatting('ja_JP', null);

  // AdMob 初期化
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['01262462e4ee6bb499fd8becbef443f3']),
  );
  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // Analytics & Observer を static に持つ
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
  FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Themed App',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.gray900,
          surfaceTintColor: Colors.white,
          titleTextStyle: TextStyle(
            color: AppColors.gray900,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            size: 18,
            color: AppColors.gray700,
          ),
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
      // 追加：Analytics Observer を登録
      navigatorObservers: [observer],
      home: const StartupScreen(),
    );
  }
}

// 以下 StartupScreen～MainPage は変更なし
class StartupScreen extends StatefulWidget {
  const StartupScreen({Key? key}) : super(key: key);

  @override
  _StartupScreenState createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      bool shouldNavigate = await UpdateChecker.checkForUpdate(context);
      if (!shouldNavigate) return;
      final bool isLogin = FirebaseAuth.instance.currentUser != null;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => isLogin ? const MainPage() : const LobbyPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    FolderListPage(title: 'ホーム'),
    OfficialListPage(),
    ForumPage(),
    MyPage(),
  ];

  final AppOpenAdManager _appOpenAdManager = AppOpenAdManager();

  @override
  void initState() {
    super.initState();
    _appOpenAdManager.loadAd();
  }

  @override
  Widget build(BuildContext context) {
    return AppLifecycleListener(
      onRestart: () => _appOpenAdManager.showAdIfAvailable(),
      onShow: () => _appOpenAdManager.loadAd(),
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdWidget(),
            Container(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 2.5, offset: const Offset(0, 3))],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
                  BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: '公式問題'),
                  BottomNavigationBarItem(icon: Icon(Icons.comment), label: 'フォーラム'),
                  BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'マイページ'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnderDevelopmentPage extends StatelessWidget {
  final String title;
  const UnderDevelopmentPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text(
          '現在、開発中です。',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray600),
        ),
      ),
    );
  }
}
