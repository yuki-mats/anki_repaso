import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'question_edit_page.dart';

class QuestionListPage extends StatelessWidget {
  final String categoryId;
  final String subcategoryId;
  final String subcategoryName;

  const QuestionListPage({
    Key? key,
    required this.categoryId,
    required this.subcategoryId,
    required this.subcategoryName,
  }) : super(key: key);

  void testDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      print('Documents Directory: ${directory.path}');
    } catch (e) {
      print('Error retrieving documents directory: $e');
    }
  }

  Future<void> ensureDirectoryExists(String filePath) async {
    final file = File(filePath);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true); // 必要に応じて親ディレクトリも作成
    }
  }


  Future<void> exportQuestionsToCSV(BuildContext context, String categoryId, String subcategoryId) async {
    try {
      // Firestoreからデータを取得
      final querySnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('categoryRef', isEqualTo: FirebaseFirestore.instance.doc('categories/$categoryId'))
          .where('subcategoryRef', isEqualTo: FirebaseFirestore.instance
          .doc('categories/$categoryId')
          .collection('subcategories')
          .doc(subcategoryId))
          .get();

      // データをCSVフォーマットに変換
      List<List<String>> csvData = [
        ['Question Text', 'Correct Answer', 'Type', 'Choices', 'Year', 'Labels']
      ];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        csvData.add([
          data['question'] ?? '',
          data['correctAnswer']?.toString() ?? '',
          data['type'] ?? '',
          (data['choices'] as List?)?.join(', ') ?? '',
          data['year']?.toString() ?? '',
          (data['labels'] as List?)?.join(', ') ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      // ファイルパスを取得
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/questions_export.csv';

      // ディレクトリが存在しない場合に備えて作成
      await ensureDirectoryExists(filePath);

      // ファイル保存処理
      final file = File(filePath);
      await file.writeAsString(csv);

      // ファイルを共有
      await Share.shareXFiles(
        [XFile(file.path)],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSVファイルを共有しました: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポート中にエラーが発生しました: $e')),
      );
    }
  }

  Future<void> importQuestionsFromCSV(BuildContext context, String categoryId, String subcategoryId) async {
    try {
      // ファイル選択
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルが選択されませんでした')),
        );
        return;
      }

      // ファイルの読み取り
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();

      // CSVデータを解析
      final csvData = const CsvToListConverter().convert(csvString, eol: '\n');

      // 1行目はヘッダーなのでスキップ
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        await FirebaseFirestore.instance.collection('questions').add({
          'question': row[0], // Question Text
          'correctAnswer': row[1], // Correct Answer
          'type': row[2], // Type
          'choices': (row[3] as String).split(', '), // Choices
          'year': int.tryParse(row[4]?.toString() ?? ''), // Year
          'labels': (row[5] as String).split(', '), // Labels
          'categoryRef': FirebaseFirestore.instance.collection('categories').doc(categoryId),
          'subcategoryRef': FirebaseFirestore.instance
              .collection('categories')
              .doc(categoryId)
              .collection('subcategories')
              .doc(subcategoryId),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVファイルから問題をインポートしました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポート中にエラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subcategoryName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                // モーダルを表示
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.0),
                      topRight: Radius.circular(24.0),
                    ),
                  ),
                  builder: (BuildContext context) {
                    return Wrap(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // 背景色
                              borderRadius: BorderRadius.circular(16.0), // カードの角丸
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.check_box_outlined, size: 36, color: Colors.blue),
                                title: const Text(
                                  '一括選択',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  // 問題の追加処理
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // 背景色
                              borderRadius: BorderRadius.circular(16.0), // カードの角丸
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.upload, size: 36, color: Colors.green),
                                title: const Text(
                                  '問題をインポート',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  importQuestionsFromCSV(context, categoryId, subcategoryId);
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 48),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // 背景色
                              borderRadius: BorderRadius.circular(16.0), // カードの角丸
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.download, size: 36, color: Colors.orange),
                                title: const Text(
                                  '問題をエクスポート',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  exportQuestionsToCSV(context, categoryId, subcategoryId);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("questions")
            .where(
            'categoryRef',
            isEqualTo: FirebaseFirestore.instance
                .collection('categories')
                .doc(categoryId))
            .where(
            'subcategoryRef',
            isEqualTo: FirebaseFirestore.instance
                .collection('categories')
                .doc(categoryId)
                .collection('subcategories')
                .doc(subcategoryId))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました'));
          }

          final questions = snapshot.data?.docs ?? [];
          if (questions.isEmpty) {
            return const Center(child: Text('問題がありません'));
          }

          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              final questionId = question.id; // FirestoreのドキュメントID
              final questionText = question['question'] is String
                  ? question['question']
                  : '問題なし';
              final answerText = question['correctAnswer'] is String
                  ? question['correctAnswer']
                  : '答えなし';

              return GestureDetector(
                onTap: () {
                  // QuestionEditPageへ遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuestionEditPage(
                        questionId: questionId,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3), // Shadow position
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "問",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  questionText,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "答",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  answerText,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () {
                                  // 音声読み上げ処理
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.bookmark_border),
                                onPressed: () {
                                  // お気に入り登録処理
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}