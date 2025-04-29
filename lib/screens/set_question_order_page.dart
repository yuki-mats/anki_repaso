import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

class SetQuestionOrderPage extends StatefulWidget {
  final String? initialSelection; // 初期選択を保持する

  SetQuestionOrderPage({Key? key, this.initialSelection}) : super(key: key);

  @override
  _SetQuestionOrderPageState createState() => _SetQuestionOrderPageState();
}

class _SetQuestionOrderPageState extends State<SetQuestionOrderPage> {
  final Map<String, String> orderOptions = {
  "random": "ランダム",
    "attemptsDescending": "試行回数が多い順",
    "attemptsAscending": "試行回数が少ない順",
    "accuracyDescending": "正答率が高い順",
    "accuracyAscending": "正答率が低い順",
    "lastStudiedDescending": "最終学習日の降順",
    "lastStudiedAscending": "最終学習日の昇順",
  };

  String? selectedOrder; // 現在選択されている出題順

  @override
  void initState() {
    super.initState();
    selectedOrder = widget.initialSelection; // 初期選択をセット
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出題順を設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            Navigator.pop(context, selectedOrder); // 現在の選択状態を返す
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
        itemCount: orderOptions.length,
        itemBuilder: (context, index) {
          final key = orderOptions.keys.elementAt(index);
          final value = orderOptions[key]!;
          return RadioListTile<String>(
            title: Text(value),
            value: key,
            groupValue: selectedOrder, // 現在選択されている値をグループに設定
            activeColor: AppColors.blue500,
            onChanged: (String? value) {
              setState(() {
                selectedOrder = value; // 選択された値を更新
              });
            },
          );
        },
      ),
    );
  }
}
