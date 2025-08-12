// lib/utils/tracking_permission.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// iOS 14+ App Tracking Transparency 許諾をリクエストする共通関数。
/// - iOS 以外／Web では何もしない
/// - 既に許諾済みの場合は即 return
Future<void> requestTrackingPermission() async {
  if (kIsWeb || !Platform.isIOS) return;

  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    // ログ出力のみ。失敗しても致命的ではない
    print('[ATT] requestTrackingPermission error: $e');
  }
}
