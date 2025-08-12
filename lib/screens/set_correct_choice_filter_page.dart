// lib/screens/set_correct_choice_filter_page.dart
// ignore_for_file: always_use_package_imports
import 'package:flutter/material.dart';

class SetCorrectChoiceFilterPage extends StatefulWidget {
  /// 'all' | 'correct' | 'incorrect'
  final String initialSelection;
  const SetCorrectChoiceFilterPage({Key? key, required this.initialSelection})
      : super(key: key);

  @override
  State<SetCorrectChoiceFilterPage> createState() =>
      _SetCorrectChoiceFilterPageState();
}

class _SetCorrectChoiceFilterPageState
    extends State<SetCorrectChoiceFilterPage> {
  late String _selected; // 現在の選択値

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  /// 現在の選択を呼び出し元へ返して閉じる
  void _finish() => Navigator.of(context).pop(_selected);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 物理戻るボタン／スワイプでも値を返す
      onWillPop: () async {
        _finish();
        return false; // 既に pop 済みなのでデフォルト処理は行わない
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('正誤フィルター'),
          // AppBar の矢印でも値を返す
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _finish,
          ),
        ),
        body: Column(
          children: [
            RadioListTile<String>(
              title: const Text('すべて'),
              value: 'all',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: Colors.blue[800],
            ),
            RadioListTile<String>(
              title: const Text('正しいのみ'),
              value: 'correct',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: Colors.blue[800],
            ),
            RadioListTile<String>(
              title: const Text('間違いのみ'),
              value: 'incorrect',
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: Colors.blue[800],
            ),
          ],
        ),
      ),
    );
  }
}
