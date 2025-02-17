import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:repaso/question_add_page.dart';
import 'utils/app_colors.dart';
import 'question_edit_page.dart';

class QuestionListPage extends StatefulWidget {
  final DocumentSnapshot folder;
  final DocumentSnapshot questionSet;
  final String questionSetName;

  const QuestionListPage({
    Key? key,
    required this.folder,
    required this.questionSet,
    required this.questionSetName,
  }) : super(key: key);

  @override
  _QuestionListPageState createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage> {

  void testDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      debugPrint('Documents Directory: ${directory.path}');
    } catch (e) {
      debugPrint('Error retrieving documents directory: $e');
    }
  }

  Future<void> ensureDirectoryExists(String filePath) async {
    final file = File(filePath);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<void> _toggleFlag(DocumentSnapshot question) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final questionUserStatsRef = FirebaseFirestore.instance
          .collection('questions')
          .doc(question.id)
          .collection('questionUserStats')
          .doc(user.uid);

      final currentStats = await questionUserStatsRef.get();
      final currentFlagState = currentStats.data()?['isFlagged'] ?? false;
      final newFlagState = !currentFlagState;

      await questionUserStatsRef.set({
        'isFlagged': newFlagState,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        question.reference.update({'isFlagged': newFlagState});
      });

      debugPrint('Flag state updated for question: ${question.id}, isFlagged: $newFlagState');
    } catch (e) {
      debugPrint('Error toggling flag: $e');
    }
  }

  void showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 250,
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildListTile(
                  icon: Icons.check_box_outlined,
                  color: AppColors.gray100,
                  text: '問題の選択',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _buildListTile(
                  icon: Icons.add,
                  color: AppColors.gray100,
                  text: 'アプリから追加',
                  onTap: () async {
                    Navigator.pop(context);  // BottomSheetを閉じる
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuestionAddPage(
                          folderRef: widget.folder.reference,
                          questionSetRef: widget.questionSet.reference,
                        ),
                      ),
                    );
                    if (result == true) {
                      setState(() {});  // 画面を更新
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildListTile(
                  icon: Icons.upload,
                  color: AppColors.gray100,
                  text: 'ファイルから追加',
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(icon, size: 22, color: AppColors.gray600),
      ),
      title: Text(text, style: const TextStyle(fontSize: 18)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.questionSetName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => showBottomSheet(context),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("questions")
            .where('questionSetRef', isEqualTo: widget.questionSet.reference)
            .where('isDeleted', isEqualTo: false)
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
              // ※以下のquestionText, correctAnswerは _buildQuestionItem 内で最新のデータにより上書きされます。
              final questionText = question['questionText'] is String
                  ? question['questionText']
                  : '問題なし';
              final correctAnswer = question['correctChoiceText'] as String? ?? '正解なし';

              return _buildQuestionItem(
                context: context,
                question: question,
                questionText: questionText,
                correctAnswer: correctAnswer,
              );
            },
          );
        },
      ),
    );
  }

  // 修正箇所：各問題項目を個別のStreamBuilderで監視するように変更
  Widget _buildQuestionItem({
    required BuildContext context,
    required DocumentSnapshot question,
    required String questionText,
    required String correctAnswer,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: question.reference.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 個別項目の読み込み中は空のコンテナを返す（UIの変更はしない）
          return Container();
        }
        final updatedQuestion = snapshot.data!;
        final updatedQuestionText = updatedQuestion['questionText'] is String
            ? updatedQuestion['questionText']
            : '問題なし';
        final updatedCorrectAnswer = updatedQuestion['correctChoiceText'] as String? ?? '正解なし';
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestionEditPage(
                  question: updatedQuestion,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionAnswerRow(
                        label: "問",
                        text: updatedQuestionText,
                        labelColor: Colors.blue),
                    const SizedBox(height: 16),
                    _buildQuestionAnswerRow(
                        label: "答",
                        text: updatedCorrectAnswer,
                        labelColor: Colors.green),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            updatedQuestion['isFlagged'] == true
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: AppColors.gray400,
                          ),
                          onPressed: () async {
                            await _toggleFlag(updatedQuestion);
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
  }

  Widget _buildQuestionAnswerRow({
    required String label,
    required String text,
    required Color labelColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          alignment: Alignment.center,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: labelColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
