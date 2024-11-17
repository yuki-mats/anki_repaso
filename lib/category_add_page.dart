import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class CategoryAddPage extends StatefulWidget {
  @override
  _CategoryAddPageState createState() => _CategoryAddPageState();
}

class _CategoryAddPageState extends State<CategoryAddPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _categoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  Future<void> _saveCategory() async {
    final categoryName = _categoryNameController.text;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final creatorRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // カテゴリデータをFirestoreに追加
      await FirebaseFirestore.instance.collection('categories').add({
        'name': categoryName,
        'creatorRef': creatorRef, // 作成者の参照
        'permissions': {
          'sharedWith': [creatorRef], // 作成者自身を共有リストに含める
        },
        'isPublic': false, // 初期状態で非公開
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しいフォルダ'),
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
                onPressed: _isButtonEnabled
                    ? () async {
                  await _saveCategory();
                  Navigator.of(context).pop(true);
                }
                    : null,
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
    MaterialPageRoute(builder: (context) => CategoryAddPage()),
  );
}
