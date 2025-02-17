import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils/app_colors.dart';

class FolderAddPage extends StatefulWidget {
  const FolderAddPage({Key? key}) : super(key: key);

  @override
  _FolderAddPageState createState() => _FolderAddPageState();
}

class _FolderAddPageState extends State<FolderAddPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _folderNameController = TextEditingController();

  // ★★ UIでフォーカス制御を行うため、FocusNodeを追加
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 入力文字が1文字以上になったらボタンを有効化する既存ロジック
    _folderNameController.addListener(() {
      updateButtonState(_folderNameController.text.isNotEmpty);
    });

    // フォーカス状態が変化したらUIを再描画
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

  // フォルダ追加処理（既存の機能そのまま）
  Future<void> _addFolder() async {
    final folderName = _folderNameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final userId = user.uid;
        final userRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

        // 1. フォルダドキュメントを追加
        final folderRef = await FirebaseFirestore.instance
            .collection('folders')
            .add({
          'name': folderName,
          'tags': [],
          'createdByRef': userRef,
          'updatedByRef': userRef,
          'isDeleted': false,
          'isPublic': false,
          'questionCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. permissions サブコレクションにオーナー権限を付与
        await folderRef.collection('permissions').doc(userId).set({
          'userRef': userRef,
          'role': 'owner',
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
    // フォーカス中かどうか
    final bool hasFocus = _focusNode.hasFocus;
    // 入力中かどうか
    final bool hasText = _folderNameController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('フォルダの追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ★★ FolderEditPage と同様に、Containerで括る＆枠線を透明にする
            Container(
              alignment: Alignment.center,
              height: 64, // 適宜レイアウトに合わせて固定
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.transparent, // フォーカス時/非フォーカス時ともに無色
                  width: 2.0,
                ),
              ),
              child: TextField(
                focusNode: _focusNode,
                controller: _folderNameController,
                autofocus: true,
                minLines: 1,
                maxLines: 1,
                style: const TextStyle(height: 1.5),

                // Iビームカーソルの色（必要なら設定）
                cursorColor: AppColors.blue600,

                decoration: InputDecoration(
                  // 中身を白色に
                  filled: true,
                  fillColor: Colors.white,

                  // フォーカス or テキストがあればラベル表示、それ以外はnull
                  labelText: (hasFocus || hasText) ? 'フォルダ名' : null,

                  // フォーカス中で未入力なら「例）製造基礎」、未フォーカスで未入力なら「フォルダ名」
                  hintText: (!hasFocus && !hasText)
                      ? 'フォルダ名'
                      : (hasFocus && !hasText)
                      ? '例）製造基礎'
                      : null,

                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  floatingLabelStyle: const TextStyle(color: AppColors.blue600),

                  // 枠線は全て消す
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
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
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                // 上記ロジックで _isButtonEnabled が true のときのみ押下可能
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
                        : Colors.black54,
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
