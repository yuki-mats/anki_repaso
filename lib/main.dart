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
// 追加：Google Mobile Ads SDK の初期化用
import 'package:google_mobile_ads/google_mobile_ads.dart';
// 追加：App Open Ad 管理クラスのインポート
import 'app_open_ad_manager.dart';
// 追加：AppLifecycleListener の簡易実装（Flutter 3.13 以降の仕組みを利用）
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('ja_JP', null);

  // Google Mobile Ads SDK の初期化
  MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
            color: AppColors.gray900, // アイコンの色
          ),
          toolbarHeight: 50,
        ),
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.blue500,
          unselectedItemColor: AppColors.gray600,
          selectedIconTheme: IconThemeData(size: 28),
          unselectedIconTheme: IconThemeData(size: 28),
          selectedLabelStyle: TextStyle(fontSize: 10),
          unselectedLabelStyle: TextStyle(fontSize: 10),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      home: const StartupScreen(), // 修正: 起動時にバージョンチェックを実行
    );
  }
}

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
      bool shouldNavigate = await UpdateChecker.checkForUpdate(context); // バージョンチェックの結果を取得
      if (!shouldNavigate) return; // アップデートダイアログが表示されている場合は遷移しない

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
    return const Scaffold(
      body: SizedBox.shrink(),
    );
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

  // 追加：App Open Ad 管理インスタンス
  final AppOpenAdManager _appOpenAdManager = AppOpenAdManager();

  @override
  void initState() {
    super.initState();
    // 起動時に広告をロード
    _appOpenAdManager.loadAd();
  }

  @override
  Widget build(BuildContext context) {
    // 追加：アプリ切り替え時に広告表示するために AppLifecycleListener で Scaffold をラップ
    return AppLifecycleListener(
      onRestart: () {
        // アプリが再開されたときに広告を表示
        _appOpenAdManager.showAdIfAvailable();
      },
      onShow: () {
        // 広告が表示された後、次回用に再ロード
        _appOpenAdManager.loadAd();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
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
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'ホーム',
                backgroundColor: Colors.white,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: '公式問題',
                backgroundColor: Colors.white,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.forum_outlined),
                label: 'フォーラム',
                backgroundColor: Colors.white,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle),
                label: 'マイページ',
                backgroundColor: Colors.white,
              ),
            ],
          ),
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
      appBar: AppBar(
        title: Text(title),
      ),
      body: const Center(
        child: Text(
          '現在、開発中です。',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray600),
        ),
      ),
    );
  }
}
