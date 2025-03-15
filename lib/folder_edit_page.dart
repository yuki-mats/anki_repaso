import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/widgets/add_page_widgets/name_imput.dart';
import 'utils/app_colors.dart';

class FolderEditPage extends StatefulWidget {
  final String folderId;
  final String initialFolderName;

  const FolderEditPage({
    Key? key,
    required this.folderId,
    required this.initialFolderName,
  }) : super(key: key);

  @override
  _FolderEditPageState createState() => _FolderEditPageState();
}

class _FolderEditPageState extends State<FolderEditPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _folderNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 初期値を設定
    _folderNameController.text = widget.initialFolderName;

    // 入力の変化を監視し、ボタンの有効・無効を更新
    _folderNameController.addListener(() {
      final currentText = _folderNameController.text.trim();
      final initialText = widget.initialFolderName.trim();
      updateButtonState(currentText.isNotEmpty && currentText != initialText);
    });

    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void updateButtonState(bool isEnabled) {
    setState(() {
      _isButtonEnabled = isEnabled;
    });
  }

  Future<void> _updateFolder() async {
    final folderName = _folderNameController.text.trim();
    if (folderName.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報を取得できません')),
      );
      return;
    }

    final String currentUserId = user.uid;

    try {
      await FirebaseFirestore.instance.collection('folders').doc(widget.folderId).update({
        'name': folderName,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedById': currentUserId, // IDのみで管理
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フォルダ名が更新されました')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('フォルダの編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // NameInput ウィジェットを利用
            NameInput(
              controller: _folderNameController,
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
                onPressed: _isButtonEnabled ? _updateFolder : null,
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
