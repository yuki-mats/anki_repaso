import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';
import 'question_add_page.dart';

class SubcategoryAddPage extends StatefulWidget {
  final String categoryId;

  const SubcategoryAddPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  _SubcategoryAddPageState createState() => _SubcategoryAddPageState();
}

class _SubcategoryAddPageState extends State<SubcategoryAddPage> {
  bool _isButtonEnabled = false;
  bool _isLoading = false; // ローディング状態の管理
  final TextEditingController _subcategoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  Future<void> _addSubcategory() async {
    setState(() {
      _isLoading = true; // ローディング状態を開始
    });

    try {
      final subcategoryName = _subcategoryNameController.text;
      final newSubcategory = await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.categoryId)
          .collection('subcategories')
          .add({'name': subcategoryName});

      // Firestoreにデータが正常に追加された後、問題作成画面へ遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuestionCreationPage(
            categoryId: widget.categoryId,
            subcategoryId: newSubcategory.id,
          ),
        ),
      );
    } catch (e) {
      // エラー時の処理（例: SnackBarでエラーを通知）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サブカテゴリーの追加に失敗しました。再度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false; // ローディング状態を終了
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しいサブカテゴリー'),
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
                  backgroundColor: _isButtonEnabled ? AppColors.blue500 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled && !_isLoading ? _addSubcategory : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('保存', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
