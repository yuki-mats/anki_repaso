import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repaso/widgets/add_page_widgets/name_imput.dart';
import '../utils/app_colors.dart';

class FolderAddPage extends StatefulWidget {
  const FolderAddPage({Key? key}) : super(key: key);

  @override
  _FolderAddPageState createState() => _FolderAddPageState();
}

class _FolderAddPageState extends State<FolderAddPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {
        _isButtonEnabled = _nameController.text.isNotEmpty;
      });
    });
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addFolder() async {
    final folderName = _nameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userId = user.uid;
        final userRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

        final folderRef = await FirebaseFirestore.instance
            .collection('folders')
            .add({
          'name': folderName,
          'isDeleted': false,
          'isPublic': false,
          'isOfficial': false,
          'aggregatedQuestionTags': [],
          'licenseName': '',
          'questionCount': 0,
          'createdById': userId,
          'updatedById': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await folderRef.collection('permissions').doc(userId).set({
          'userId': userId,
          'userRef': userRef,
          'role': 'owner',
          'isHidden': false, //削除予定
          'isDeleted': false,
          'createdById': userId,
          'updatedById': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォルダが保存されました')),
        );

        Navigator.of(context).pop(true);
      } catch (e) {
        print('Firestoreへの保存中にエラーが発生: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報を取得できません')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(title: const Text('フォルダの追加')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // NameInput ウィジェットを利用（labelTextなどは必要に応じて変更）
            NameInput(
              controller: _nameController,
              focusNode: _focusNode,
              labelText: 'フォルダ名',
              hintText: '例）製造基礎',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _isButtonEnabled ? AppColors.blue600 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                onPressed: _isButtonEnabled ? _addFolder : null,
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: _isButtonEnabled ? Colors.white : Colors.black54,
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
