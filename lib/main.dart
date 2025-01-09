import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/lobby_page.dart';
import 'app_colors.dart';
import 'firebase_options.dart';
import 'my_page.dart';

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
    print('ThemeData: ${Theme.of(context)}');
    print('BottomNavigationBar Theme: ${Theme.of(context).bottomNavigationBarTheme}');
    print('BottomNavigationBar Background Color: ${Theme.of(context).bottomNavigationBarTheme.backgroundColor}');
    print('Scaffold Background Color: ${Theme.of(context).scaffoldBackgroundColor}');

    final bool islogin = FirebaseAuth.instance.currentUser != null;

    return MaterialApp(
      title: 'Themed App',
      theme: ThemeData(
        // AppBarのテーマ設定
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar背景色
          foregroundColor: AppColors.gray900, // AppBarテキスト色
          titleTextStyle: TextStyle(
            color: AppColors.gray900, // テキスト色
            fontSize: 20, // フォントサイズ
            fontWeight: FontWeight.bold, // 太字
          ),
        ),
        scaffoldBackgroundColor: Colors.white, // 背景色を白に設定

        // BottomNavigationBarのテーマ設定
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,// BottomNavigationBarの背景色
          selectedItemColor: AppColors.blue500, // 選択されたアイコンと文字の色
          unselectedItemColor: AppColors.gray600, // 非選択時のアイコンと文字の色
          selectedIconTheme: IconThemeData(size: 32), // 選択されたアイコンのサイズ
          unselectedIconTheme: IconThemeData(size: 32), // 非選択時のアイコンのサイズ
          selectedLabelStyle: TextStyle(fontSize: 14), // 選択時のラベルスタイル
          unselectedLabelStyle: TextStyle(fontSize: 14), // 非選択時のラベルスタイル
          showSelectedLabels: true, // 選択時のラベルを表示
          showUnselectedLabels: true, // 非選択時のラベルを表示
        ),
      ),
      home: islogin ? const MainPage() : const LobbyPage(), // MainPageを設定
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // 現在のページインデックス

  final List<Widget> _pages = [
    FolderListPage(title: 'ホーム'), // ホームページ
    Placeholder(), // 公式問題ページの仮ページ
    Placeholder(), // 相談ページの仮ページ
    MyPage(), // マイページ
  ];

  @override
  Widget build(BuildContext context) {
    // デバッグ情報を出力
    print('BottomNavigationBar backgroundColor: ${Theme.of(context).bottomNavigationBarTheme.backgroundColor}');

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
              blurRadius: 2.5,// ぼかしの量
              offset: const Offset(0, 3), // 影の位置
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // 位置を固定
          backgroundColor: Colors.white, // 背景色を明示的に設定
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

