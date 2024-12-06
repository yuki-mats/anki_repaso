import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

class FolderEditPage extends StatefulWidget {
  final String initialFolderName;
  final String folderId;

  const FolderEditPage({Key? key, required this.initialFolderName, required this.folderId}) : super(key: key);

  @override
  _FolderEditPageState createState() => _FolderEditPageState();
}

class _FolderEditPageState extends State<FolderEditPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderNameController.text = widget.initialFolderName; // 初期値を設定
    _folderNameController.addListener(() {
      updateButtonState(_folderNameController.text.trim().isNotEmpty);
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

  Future<void> _updateFolder() async {
    final folderName = _folderNameController.text.trim();
    if (folderName.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('folders')
          .doc(widget.folderId) // ドキュメントIDを使って更新
          .update({
        'name': folderName,
        'updatedAt': FieldValue.serverTimestamp(), // 更新日時を設定
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フォルダ名が更新されました')),
      );

      Navigator.of(context).pop(true); // 更新完了後、前の画面に戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フォルダの編集'),
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
                  backgroundColor: _isButtonEnabled ? AppColors.blue600 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled ? _updateFolder : null,
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

void navigateToFolderEditPage(BuildContext context, String initialFolderName, String folderId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FolderEditPage(initialFolderName: initialFolderName, folderId: folderId),
    ),
  );
}
