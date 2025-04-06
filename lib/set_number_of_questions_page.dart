import 'package:flutter/material.dart';

import 'utils/app_colors.dart';

class SetNumberOfQuestionsPage extends StatefulWidget {
  final int? initialSelection; // 初期選択を保持

  SetNumberOfQuestionsPage({Key? key, this.initialSelection}) : super(key: key);

  @override
  _SetNumberOfQuestionsPageState createState() => _SetNumberOfQuestionsPageState();
}

class _SetNumberOfQuestionsPageState extends State<SetNumberOfQuestionsPage> {
  final List<int> numberOfQuestions = [5, 10, 15, 20, 25, 30];
  int? selectedNumber; // 現在選択されている出題数

  @override
  void initState() {
    super.initState();
    selectedNumber = widget.initialSelection; // 初期選択をセット
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出題数を設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            Navigator.pop(context, selectedNumber); // 現在の選択状態を返す
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0), // 線の高さ
          child: Container(
            color: Colors.grey[300], // 薄いグレーの線
            height: 1.0,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: numberOfQuestions.length,
        itemBuilder: (context, index) {
          final count = numberOfQuestions[index];
          return RadioListTile<int>(
            title: Text('$count問'),
            value: count,
            groupValue: selectedNumber, // 現在選択されている値をグループに設定
            activeColor: AppColors.blue500,
            onChanged: (int? value) {
              setState(() {
                selectedNumber = value; // 選択された値を更新
              });
            },
          );
        },
      ),
    );
  }
}
