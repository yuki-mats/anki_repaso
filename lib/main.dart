import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/lobby_page.dart';
import 'package:repaso/official_list_page.dart';
import 'package:repaso/utils/update_checker.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';
import 'my_page.dart';

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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
      body: Center(child: CircularProgressIndicator()),
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
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              icon: Icon(Icons.account_circle),
              label: 'マイページ',
              backgroundColor: Colors.white,
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
