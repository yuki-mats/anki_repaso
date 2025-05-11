import 'package:cloud_firestore/cloud_firestore.dart';

/// 中間モデル: フォルダ情報とユーザー統計をまとめる
class FolderItem {
  /// フォルダのドキュメントスナップショット
  final DocumentSnapshot folderDoc;

  /// メモリーレベルごとのカウント (again, hard, good, easy)
  final Map<String, int> memoryLevels;

  /// 正解数 (easy + good + hard)
  final int correct;

  /// 総問題数 (correct + again)
  final int total;

  /// 正答率 (0～1)
  double get rate => total > 0 ? correct / total : 0;

  FolderItem({
    required this.folderDoc,
    required this.memoryLevels,
  })  : correct = (memoryLevels['easy']! + memoryLevels['good']! + memoryLevels['hard']!),
        total = (memoryLevels['easy']! + memoryLevels['good']! + memoryLevels['hard']! + memoryLevels['again']!);
}
