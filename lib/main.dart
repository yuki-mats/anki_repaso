import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/lobby_page.dart';
import 'app_colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        colorScheme: const ColorScheme(
          primary: AppColors.blue900,
          secondary: AppColors.blue700,
          surface: Colors.white,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.gray50,

        // AppBarのテーマ設定
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.blue700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        // NavigationBarのテーマ設定
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.blue700, // 青系のセカンダリーカラー
          indicatorColor: AppColors.blue900,  // 選択された項目の色（プライマリー）
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: Colors.white),  // ナビゲーション項目のテキスト色
          ),
        ),
      ),
      home: islogin ? const FolderListPage(title: 'ホーム') : const LobbyPage(),
    );
  }
}
