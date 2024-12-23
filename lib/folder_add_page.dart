import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class FolderAddPage extends StatefulWidget {
  @override
  _FolderAddPageState createState() => _FolderAddPageState();
}

class _FolderAddPageState extends State<FolderAddPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderNameController.addListener(() {
      updateButtonState(_folderNameController.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void updateButtonState(bool isEnabled) {
    setState(() {
      _isButtonEnabled = isEnabled;
    });
  }

  Future<void> _addFolder() async {
    final folderName = _folderNameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // 作成者のUIDを取得
        final userId = user.uid;

        // Firestoreにフォルダデータを保存
        await FirebaseFirestore.instance.collection('folders').add({
          'name': folderName,
          'tags': [], // 初期状態でタグは空
          'createdByRef': FirebaseFirestore.instance.collection('users').doc(userId), // 作成者の参照
          'updatedByRef': FirebaseFirestore.instance.collection('users').doc(userId), // 更新者の参照
          'userRoles': {
            userId: 'owner', // 作成者をオーナーとして設定
          },
          'isPublic': false,          // 初期状態で非公開
          'questionCount':0,         // 初期問題数
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 保存成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォルダが保存されました')),
        );

        // 画面を閉じる
        Navigator.of(context).pop(true);
      } catch (e) {
        // エラーをキャッチして表示
        print('Firestoreへの保存中にエラーが発生: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } else {
      // ユーザーが認証されていない場合
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報を取得できません')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フォルダの追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _folderNameController,
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
                  backgroundColor:
                  _isButtonEnabled ? AppColors.blue600 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled
                    ? () async {
                  await _addFolder();
                }
                    : null,
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: _isButtonEnabled
                        ? Colors.white
                        : Colors.black.withOpacity(0.5),
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

