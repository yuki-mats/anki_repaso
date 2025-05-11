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
  bool _loading = false;
  bool _fetched = false;
  Map<String, dynamic>? _cachedData;

  void _toggleSection() {
    setState(() {
      _showQuestionSection = !_showQuestionSection;
    });

    if (_showQuestionSection && !_fetched) {
      // 初回開閉時にだけフェッチ
      print('[Debug] Fetching question for id=${widget.questionId}');
      setState(() => _loading = true);
      FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .get()
          .then((doc) {
        print('[Debug] Question fetched: ${doc.data()}');
        setState(() {
          _cachedData = doc.exists
              ? (doc.data()! as Map<String, dynamic>)
              : <String, dynamic>{};
          _fetched = true;
          _loading = false;
        });
      }).catchError((error) {
        print('[Debug] Error fetching question: $error');
        setState(() {
          _cachedData = null;
          _fetched = true;
          _loading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Padding(
        padding: _showQuestionSection
            ? const EdgeInsets.only(left: 2, top: 2, right: 2, bottom: 4)
            : const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // トグルボタン
            InkWell(
              onTap: _toggleSection,
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
            // 展開時のみ表示
            if (_showQuestionSection)
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (!_fetched || _cachedData == null || _cachedData!.isEmpty)
                const SizedBox()
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cachedData!['questionText'] as String? ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '<回答> ${_cachedData!['correctChoiceText'] as String? ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      if ((_cachedData!['examSource'] as String?)?.isNotEmpty ?? false)
                        Text(
                          '出典：${_cachedData!['examSource']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
