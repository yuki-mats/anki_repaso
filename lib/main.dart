import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/lobby_page.dart';
import 'package:repaso/official_list_page.dart';
import 'app_colors.dart';
import 'firebase_options.dart';
import 'my_page.dart';

Future<void> requestTrackingPermission() async {
  try {
    // 現在のトラッキング許可状態を取得
    final trackingStatus = await AppTrackingTransparency.trackingAuthorizationStatus;

    if (trackingStatus == TrackingStatus.notDetermined) {
      // 許可リクエストを表示
      await AppTrackingTransparency.requestTrackingAuthorization();
    }

    // 許可リクエスト後の状態を再取得
    final newStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
    print('Tracking Status: $newStatus');

    // 状態に応じた処理を追加（必要に応じて）
    switch (newStatus) {
      case TrackingStatus.authorized:
        print('ユーザーがトラッキングを許可しました。');
        // 許可された場合の処理を追加
        break;
      case TrackingStatus.denied:
        print('ユーザーがトラッキングを拒否しました。');
        // 拒否された場合の処理を追加
        break;
      case TrackingStatus.notDetermined:
        print('ユーザーがトラッキングの選択を行っていません。');
        break;
      case TrackingStatus.restricted:
        print('トラッキングが制限されています。');
        // 制限されている場合の処理を追加
        break;
      case TrackingStatus.notSupported:
        print('トラッキングがサポートされていません。');
        // サポートされていない場合の処理を追加
        break;
    }
  } catch (e) {
    // エラー発生時の処理
    print('トラッキング許可リクエスト中にエラーが発生しました: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 日本語ロケールデータを初期化
  await initializeDateFormatting('ja_JP', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool islogin = FirebaseAuth.instance.currentUser != null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Themed App',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar背景色
          foregroundColor: AppColors.gray900, // AppBarテキスト色
          titleTextStyle: TextStyle(
            color: AppColors.gray900, // テキスト色
            fontSize: 18, // フォントサイズ
            fontWeight: FontWeight.bold, // 太字
          ),
        ),
        scaffoldBackgroundColor: Colors.white, // 背景色を白に設定
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
      home: islogin ? const MainPage() : const LobbyPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    // Show tracking authorization dialog and ask for permission
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) async {
      await requestTrackingPermission();
      final status = await AppTrackingTransparency.requestTrackingAuthorization();
    });
  }
  int _currentIndex = 0; // 現在のページインデックス

  final List<Widget> _pages = [
    FolderListPage(title: 'ホーム'), // ホームページ
    OfficialListPage(), // 公式問題ページ
    UnderDevelopmentPage(title: '相談'), // 相談ページ
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex, // 現在のページだけを表示
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5), // 影の色
              spreadRadius: 1, // 拡散の半径
              blurRadius: 2.5, // ぼかしの量
              offset: const Offset(0, 3), // 影の位置
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index; // インデックスを更新してページを切り替え
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
              icon: Icon(Icons.chat_outlined),
              label: '相談',
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
