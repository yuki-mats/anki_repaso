// lib/widgets/add_page_widgets/question_count_selector.dart

import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

typedef QuestionCountChanged = void Function(int newCount);

class QuestionCountSelector extends StatelessWidget {
  final int selectedCount;
  final QuestionCountChanged onCountChanged;

  const QuestionCountSelector({
    Key? key,
    required this.selectedCount,
    required this.onCountChanged,
  }) : super(key: key);

  Future<void> _showModal(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildTile(1,  '1問',  context),
            _buildTile(3,  '3問',  context),
            _buildTile(5,  '5問',  context),
            _buildTile(10, '10問', context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null && picked != selectedCount) {
      onCountChanged(picked);
    }
  }

  Widget _buildTile(int value, String label, BuildContext ctx) {
    final isSel = value == selectedCount;
    return ListTile(
      leading: Icon(
        Icons.format_list_numbered,
        color: isSel ? AppColors.blue500 : AppColors.gray600,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSel
          ? const Icon(Icons.check, color: AppColors.blue500)
          : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 12.0),
          child: Text(
            '生成数',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showModal(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray100, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedCount}問',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.gray500),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
