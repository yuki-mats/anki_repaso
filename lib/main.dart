import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/lobby_page.dart';
import 'app_colors.dart';
import 'firebase_options.dart';

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
          backgroundColor: Colors.white, // 背景色
          selectedItemColor: AppColors.blue500, // 選択されたアイコンと文字の色
          unselectedItemColor: AppColors.gray600, // 非選択時のアイコンと文字の色
          selectedIconTheme: IconThemeData(size: 40), // 選択されたアイコンのサイズ
          unselectedIconTheme: IconThemeData(size: 40), // 非選択時のアイコンのサイズ
          showSelectedLabels: true, // 選択時のラベルを表示
          showUnselectedLabels: true, // 非選択時のラベルを表示
        ),
      ),
      home: islogin ? const FolderListPage(title: 'ホーム') : const LobbyPage(),
    );
  }
}
