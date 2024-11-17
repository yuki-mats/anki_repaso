import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SubcategoryEditPage extends StatefulWidget {
  final String initialSubcategoryName;
  final String categoryId;
  final String subcategoryId;

  const SubcategoryEditPage({
    Key? key,
    required this.initialSubcategoryName,
    required this.categoryId,
    required this.subcategoryId,
  }) : super(key: key);

  @override
  _SubcategoryEditPageState createState() => _SubcategoryEditPageState();
}

class _SubcategoryEditPageState extends State<SubcategoryEditPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _subcategoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subcategoryNameController.text = widget.initialSubcategoryName; // 初期値を設定
    _subcategoryNameController.addListener(() {
      updateButtonState(_subcategoryNameController.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _subcategoryNameController.dispose();
    super.dispose();
  }

  void updateButtonState(bool isEnabled) {
    setState(() {
      _isButtonEnabled = isEnabled;
    });
  }

  Future<void> _saveSubcategory() async {
    final subcategoryName = _subcategoryNameController.text;
    await FirebaseFirestore.instance
        .collection('categories')
        .doc(widget.categoryId)
        .collection('subcategories') // サブコレクションにアクセス
        .doc(widget.subcategoryId) // サブカテゴリーIDを指定
        .update({'name': subcategoryName});
    Navigator.of(context).pop(true); // 保存後、前の画面に戻る
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サブカテゴリー編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _subcategoryNameController,
              autofocus: true,
              minLines: 1,
              maxLines: 1,
              style: const TextStyle(height: 1.5),
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                labelText: 'サブカテゴリー名',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isButtonEnabled ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled ? _saveSubcategory : null,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void navigateToEditSubcategoryPage(
    BuildContext context, String categoryId, String subcategoryId, String initialSubcategoryName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SubcategoryEditPage(
        initialSubcategoryName: initialSubcategoryName,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
      ),
    ),
  );
}
