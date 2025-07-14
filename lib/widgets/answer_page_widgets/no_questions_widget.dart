import 'package:flutter/material.dart';

/// 「問題がありません」の共通ウィジェット
Widget buildNoQuestionsWidget({
  required BuildContext context,
  required String message,
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
          ],
        ),
      ),
    ),
  );
}
