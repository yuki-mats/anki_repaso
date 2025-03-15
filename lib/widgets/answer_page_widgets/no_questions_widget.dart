import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

/// 「問題がありません」の共通ウィジェット
Widget buildNoQuestionsWidget({
  required BuildContext context,
  required String message, // メインメッセージ（例：「問題がありません」）
  required String subMessage, // サブメッセージ（例：「最初の問題を作成しよう」）
  required String buttonMessage, // ボタンのメッセージ（例：「問題を作成する」）
  required VoidCallback onPressed, // 作成ボタン押下時の処理
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subMessage,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onPressed,
                child: Text(
                  buttonMessage,
                  style: TextStyle(
                      fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
