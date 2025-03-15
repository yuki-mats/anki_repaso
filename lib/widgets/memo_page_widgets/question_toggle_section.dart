import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repaso/utils/app_colors.dart';

class QuestionToggleSection extends StatefulWidget {
  final String questionId;

  const QuestionToggleSection({
    Key? key,
    required this.questionId,
  }) : super(key: key);

  @override
  _QuestionToggleSectionState createState() => _QuestionToggleSectionState();
}

class _QuestionToggleSectionState extends State<QuestionToggleSection>
    with SingleTickerProviderStateMixin {
  bool _showQuestionSection = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Container(
        color: AppColors.gray50,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // トグルボタンとラベルは常時表示
              InkWell(
                onTap: () {
                  setState(() {
                    _showQuestionSection = !_showQuestionSection;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _showQuestionSection
                          ? Icons.arrow_drop_down_sharp
                          : Icons.arrow_right_sharp,
                      size: 28,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '問題',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // トグルON時にFirestoreから問題情報を取得して表示
              if (_showQuestionSection)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('questions')
                      .doc(widget.questionId)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox();
                    }
                    final questionData =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final questionText = questionData['questionText'] as String? ?? '';
                    final correctChoiceText =
                        questionData['correctChoiceText'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0,right: 8.0,bottom: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '問題: $questionText',
                            style: const TextStyle(
                                fontSize: 14,),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '回答: $correctChoiceText',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
