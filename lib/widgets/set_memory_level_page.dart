import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

class SetMemoryLevelPage extends StatefulWidget {
  final List<String>? initialSelection;

  const SetMemoryLevelPage({Key? key, this.initialSelection}) : super(key: key);

  @override
  _SetMemoryLevelPageState createState() => _SetMemoryLevelPageState();
}

class _SetMemoryLevelPageState extends State<SetMemoryLevelPage> {
  final Map<String, String> memoryLevelOptions = {
    "again": "もう一度",
    "hard": "難しい",
    "good": "普通",
    "easy": "簡単",
  };

  late List<String> selectedLevels;

  @override
  void initState() {
    super.initState();
    selectedLevels = widget.initialSelection?.toList() ?? memoryLevelOptions.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記憶度を選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            if (selectedLevels.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('少なくとも1つは選択してください')),
              );
            } else {
              Navigator.pop(context, selectedLevels);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: memoryLevelOptions.length,
        itemBuilder: (context, index) {
          final key = memoryLevelOptions.keys.elementAt(index);
          final label = memoryLevelOptions[key]!;
          return CheckboxListTile(
            title: Text(label, style: const TextStyle(fontSize: 14)),
            value: selectedLevels.contains(key),
            activeColor: AppColors.blue500,
            controlAffinity: ListTileControlAffinity.leading, // チェックボックスを左側に（標準）
            visualDensity: const VisualDensity(horizontal: -2.0, vertical: -2.0), // 小さくする
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0), // 左右の余白
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  selectedLevels.add(key);
                } else {
                  selectedLevels.remove(key);
                }
              });
            },
          );
        },
      ),
    );
  }
}
