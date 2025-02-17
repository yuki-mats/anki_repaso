import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

class UpdateChecker {
  static const String _appStoreURL = 'https://apps.apple.com/jp/app/%E6%9A%97%E8%A8%98%E3%83%97%E3%83%A9%E3%82%B9/id6740453092';


  /// Firestore から最新のバージョン情報を取得し、強制アップデートをチェック
  static Future<bool> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);
      print('現在のアプリバージョン: $currentVersion');

      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('08zYvCuKUcvGTNYqehrm') // Firestore のドキュメントID
          .get();

      if (!doc.exists || !doc.data()!.containsKey('ios_force_app_version')) {
        print('Firestore から取得したバージョン情報が存在しません。');
        return true; // 画面遷移を許可
      }

      final newVersion = Version.parse(doc.data()!['ios_force_app_version'] as String);
      print('Firestore の最新バージョン: $newVersion');

      if (currentVersion < newVersion) {
        print('アップデートが必要: YES');
        await _showUpdateDialog(context); // ダイアログが閉じるまで待機
        return false; // 画面遷移を防ぐ
      } else {
        print('アップデートが必要: NO');
        return true; // 画面遷移を許可
      }
    } catch (e) {
      print('バージョンチェックエラー: $e');
      return true; // 画面遷移を許可（エラー時）
    }
  }

  /// アップデートダイアログを表示
  static Future<void> _showUpdateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('バージョン更新のお知らせ'),
          content: const Text('新しいバージョンのアプリをご利用ください。ストアより更新版を入手することができます。'),
          actions: <Widget>[
            TextButton(
              child: const Text('今すぐ更新', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(_appStoreURL))) {
                  await launchUrl(Uri.parse(_appStoreURL), mode: LaunchMode.externalApplication);
                } else {
                  print('ストアを開けませんでした');
                }
              },
            ),
          ],
        );
      },
    );
  }
}
