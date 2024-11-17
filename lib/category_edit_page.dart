import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

class CategoryEditPage extends StatefulWidget {
  final String initialCategoryName;
  final String categoryId;

  const CategoryEditPage({Key? key, required this.initialCategoryName, required this.categoryId}) : super(key: key);

  @override
  _CategoryEditPageState createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends State<CategoryEditPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _categoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categoryNameController.text = widget.initialCategoryName; // 初期値を設定
    _categoryNameController.addListener(() {
      updateButtonState(_categoryNameController.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  void updateButtonState(bool isEnabled) {
    setState(() {
      _isButtonEnabled = isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _categoryNameController,
              autofocus: true,
              minLines: 1,
              maxLines: 1,
              style: const TextStyle(height: 1.5),
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                labelText: 'フォルダ名',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isButtonEnabled ? AppColors.blue600 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled ? () async {
                  final categoryName = _categoryNameController.text;
                  await FirebaseFirestore.instance
                      .collection('categories')
                      .doc(widget.categoryId) // ドキュメントIDを使って更新
                      .update({'name': categoryName});
                  Navigator.of(context).pop(true);
                } : null,
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: _isButtonEnabled ? Colors.white : Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void navigateToAddCategoryPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CategoryEditPage(initialCategoryName: '', categoryId: '',)),
  );
}
