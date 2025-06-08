///Users/yuki/StudioProjects/repaso/lib/widgets/add_page_widgets/question_type_selector.dart

import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

typedef QuestionTypeChanged = void Function(String newType);

class QuestionTypeSelector extends StatelessWidget {
  final String selectedType;
  final QuestionTypeChanged onTypeChanged;

  const QuestionTypeSelector({
    Key? key,
    required this.selectedType,
    required this.onTypeChanged,
  }) : super(key: key);

  String _labelForType(String type) {
    switch (type) {
      case 'true_false':
        return '正誤問題';
      case 'flash_card':
        return 'カード';
      case 'single_choice':
        return '四択問題';
      default:
        return '';
    }
  }

  Future<void> _showModal(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
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
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildTile('true_false', '正誤問題', Icons.check_circle_outline, context),
            _buildTile('flash_card', 'カード', Icons.filter_none_rounded, context),
            _buildTile('single_choice', '四択問題', Icons.list_alt, context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null && picked != selectedType) {
      onTypeChanged(picked);
    }
  }

  Widget _buildTile(String value, String label, IconData icon, BuildContext ctx) {
    final isSel = value == selectedType;
    return ListTile(
      leading: Icon(icon, color: isSel ? AppColors.blue500 : AppColors.gray600),
      title: Text(label, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      trailing: isSel ? const Icon(Icons.check, color: AppColors.blue500) : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: const Text('問題形式',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
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
                Text(_labelForType(selectedType),
                    style: const TextStyle(fontSize: 14, color: Colors.black87)),
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
