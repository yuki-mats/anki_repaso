//wedgets/review_prompt_dialog.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repaso/utils/app_colors.dart';

class ReviewPromptDialog {
  /// 呼び出し元はこのメソッドだけを呼ぶ
  static Future<void> show(BuildContext context) async {
    final _inAppReview = InAppReview.instance;
    bool _dialogShown = true; // 呼び出し前にフラグ管理する場合は外部で制御可

    int selectedStars = 0;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '暗記プラスの評価は？',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < selectedStars;
                      return IconButton(
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          size: 32,
                          color: filled ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () async {
                          setState(() {
                            selectedStars = i + 1;
                          });
                          Navigator.of(ctx2).pop();

                          if (selectedStars >= 4) {
                            final u = FirebaseAuth.instance.currentUser;
                            try {
                              if (await _inAppReview.isAvailable()) {
                                await _inAppReview.requestReview();
                              } else {
                                await _inAppReview.openStoreListing(
                                  appStoreId: '6740453092',
                                );
                              }
                              if (u != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(u.uid)
                                    .set(
                                  {'hasRated': true},
                                  SetOptions(merge: true),
                                );
                              }
                            } on PlatformException catch (e) {
                              debugPrint('In-App review error: $e');
                            }
                          }
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text('ぜひ星５をタップしてください。'),
                  const SizedBox(height: 4),
                  const Text('もっと便利にしていきます👍'),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.blue200,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          _dialogShown = false;
                          Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          '後で',
                          style: TextStyle(color: AppColors.blue600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
