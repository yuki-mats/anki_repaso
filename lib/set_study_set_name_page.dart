import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

class SetStudySetNamePage extends StatefulWidget {
  final String initialName;

  const SetStudySetNamePage({Key? key, required this.initialName}) : super(key: key);

  @override
  _SetStudySetNamePageState createState() => _SetStudySetNamePageState();
}

class _SetStudySetNamePageState extends State<SetStudySetNamePage> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();

    // 🔹 ページ遷移後にテキストフィールドへ自動フォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('暗記セット名の編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.transparent, // フォーカス時/非フォーカス時でも無色
                  width: 2.0,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode, // 🔹 フォーカス管理を追加
                minLines: 1,
                maxLines: 1,
                style: const TextStyle(height: 1.5),
                cursorColor: AppColors.blue600, // `_buildExpandableTextField` に合わせたカーソル色
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'セット名',
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  floatingLabelStyle: TextStyle(color: AppColors.blue600), // `_buildExpandableTextField` に合わせたラベル色
                  border: InputBorder.none, // `Container` 側で管理するため削除
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
                  backgroundColor: AppColors.blue500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, _controller.text);
                },
                child: const Text('設定', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
