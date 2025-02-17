import 'package:flutter/material.dart';

/// フッターボタンを表示するウィジェット
Widget buildFooterButtons({
  required String questionType,
  required bool? isAnswerCorrect,
  required bool flashCardAnswerShown, // フラッシュカードの場合、回答済みかどうか
  required VoidCallback onMemoryLevelSelected,
  required VoidCallback onNextPressed,
  required Function(String) saveAnswer,
}) {
  if (questionType == 'flash_card') {
    // flash_cardの場合、回答が表示されていなければボタンを非表示
    if (!flashCardAnswerShown) {
      return SizedBox.shrink();
    }
    // 回答が表示されている場合は、常に ['Again', 'Hard', 'Good', 'Easy'] のボタンを表示
    final levels = ['Again', 'Hard', 'Good', 'Easy'];
    return _buildMemoryLevelButtons(levels, onMemoryLevelSelected, saveAnswer);
  } else if (isAnswerCorrect == null) {
    return SizedBox.shrink(); // まだ回答していない場合は非表示
  } else if (isAnswerCorrect == true) {
    final levels = ['Hard', 'Good', 'Easy'];
    return _buildMemoryLevelButtons(levels, onMemoryLevelSelected, saveAnswer);
  } else {
    return _buildNextButton(onNextPressed);
  }
}


/// メモリレベル選択ボタンの共通ウィジェット
Widget _buildMemoryLevelButtons(
    List<String> levels,
    VoidCallback onMemoryLevelSelected,
    Function(String) saveAnswer,
    ) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.blue, width: 4.0)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: levels.map((displayText) {
        final memoryLevel = displayText.toLowerCase();
        final buttonData = _getButtonStyle(memoryLevel);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: () {
                saveAnswer(memoryLevel);
                onMemoryLevelSelected();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonData['color'],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero, // 内部の余白をなくす
                minimumSize: Size.zero, // 必要に応じて最小サイズをなくす
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // タップ領域を最小化
              ),
              child: Padding(
                padding: const EdgeInsets.only(top:3.0, bottom: 3.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(buttonData['icon'], color: Colors.white, size: 18),
                    const SizedBox(height: 4),
                    Text(displayText, style: const TextStyle(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

/// Next ボタンの共通ウィジェット
Widget _buildNextButton(VoidCallback onNextPressed) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.redAccent, width: 4.0)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
    child: ElevatedButton(
      onPressed: onNextPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('次へ', style: TextStyle(fontSize: 18, color: Colors.white)),
    ),
  );
}

/// メモリレベルボタンのスタイルを取得するヘルパー関数
Map<String, dynamic> _getButtonStyle(String level) {
  switch (level) {
    case 'again':
      return {'color': Colors.red[300], 'icon': Icons.refresh};
    case 'hard':
      return {'color': Colors.orange[300], 'icon': Icons.sentiment_dissatisfied_outlined};
    case 'good':
      return {'color': Colors.green[300], 'icon': Icons.sentiment_satisfied};
    case 'easy':
      return {'color': Colors.blue[300], 'icon': Icons.sentiment_satisfied_alt_outlined};
    default:
      return {'color': Colors.grey, 'icon': Icons.help_outline};
  }
}
