import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

/// モーダルに表示する１行分のデータ
class OptionItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  OptionItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });
}

/// 汎用 Options モーダルシート
class OptionsModalSheet extends StatelessWidget {
  /// ヘッダー用に自由な Widget を渡せる
  final Widget? headerWidget;

  /// headerWidget が null の場合に表示されるテキスト
  final String? headerTitle;

  final List<OptionItem> items;
  final double height;

  const OptionsModalSheet({
    Key? key,
    this.headerWidget,
    this.headerTitle,
    required this.items,
    this.height = 280,
  })  : assert(headerWidget != null || headerTitle != null,
  'headerWidget か headerTitle のいずれかを指定してください'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー部分
          if (headerWidget != null) ...[
            headerWidget!,
          ] else ...[
            Text(
              headerTitle!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.gray100),
          const SizedBox(height: 8),

          // オプションリスト
          ...items.map((item) {
            return ListTile(
              enabled: item.enabled,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.iconBgColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(item.icon, size: 22, color: item.iconColor),
              ),
              title: Text(item.title, style: const TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                item.onTap();
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// 呼び出しヘルパー
Future<void> showOptionsModal({
  required BuildContext context,
  Widget? headerWidget,
  String? headerTitle,
  required List<OptionItem> items,
  double? height,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => OptionsModalSheet(
      headerWidget: headerWidget,
      headerTitle: headerTitle,
      items: items,
      height: height ?? 280,
    ),
  );
}
