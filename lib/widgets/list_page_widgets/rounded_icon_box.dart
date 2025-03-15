import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

/// アイコンをラウンド角のコンテナで包む共通ウィジェット
class RoundedIconBox extends StatelessWidget {
  /// 表示するアイコン
  final IconData icon;

  /// アイコンの色（デフォルトは `AppColors.blue500`）
  final Color? iconColor;

  /// コンテナの背景色（デフォルトは `AppColors.blue200`）
  final Color? backgroundColor;

  /// コンテナの角を丸くする半径（デフォルト `6.0`）
  final double borderRadius;

  /// コンテナの幅（デフォルト `28.0`）
  final double size;

  /// アイコンのサイズ（デフォルト `16.0`）
  final double iconSize;

  const RoundedIconBox({
    super.key,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.borderRadius = 6.0,
    this.size = 28.0,
    this.iconSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.blue200, // `null` の場合デフォルト値
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? AppColors.blue500, // `null` の場合デフォルト値
      ),
    );
  }
}
