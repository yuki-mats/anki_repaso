import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';
import 'package:repaso/set_number_of_questions_page.dart';
import 'package:repaso/set_question_order_page.dart';
import 'package:repaso/set_question_set_page.dart';
import 'package:repaso/set_study_set_name_page.dart';

class StudySet {
  final String id; // ドキュメント ID を追加
  final String name;
  final List<String> questionSetIds;
  final int numberOfQuestions;
  final String selectedQuestionOrder;
  final RangeValues correctRateRange;
  final bool isFlagged;

  StudySet({
    required this.id, // ID をコンストラクタに追加
    required this.name,
    required this.questionSetIds,
    required this.numberOfQuestions,
    required this.selectedQuestionOrder,
    required this.correctRateRange,
    required this.isFlagged,
  });

  // Firestoreデータから生成するファクトリコンストラクタ
  factory StudySet.fromFirestore(String id, Map<String, dynamic> data) {
    return StudySet(
      id: id, // Firestore ドキュメント ID を設定
      name: data['name'] as String,
      questionSetIds: List<String>.from(data['questionSetIds'] ?? []),
      numberOfQuestions: data['numberOfQuestions'] as int,
      selectedQuestionOrder: data['selectedQuestionOrder'] as String,
      correctRateRange: RangeValues(
        (data['correctRateRange']?['start'] ?? 0.0) as double,
        (data['correctRateRange']?['end'] ?? 100.0) as double,
      ),
      isFlagged: data['isFlagged'] as bool? ?? false,
    );
  }

  // Firestoreに保存するためのMap形式に変換
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'questionSetIds': questionSetIds,
      'numberOfQuestions': numberOfQuestions,
      'selectedQuestionOrder': selectedQuestionOrder,
      'correctRateRange': {
        'start': correctRateRange.start,
        'end': correctRateRange.end,
      },
      'isFlagged': isFlagged,
    };
  }
}

class StudySetEditPage extends StatefulWidget {
  final String userId;
  final String studySetId;
  final StudySet initialStudySet;

  const StudySetEditPage({
    Key? key,
    required this.userId,
    required this.studySetId,
    required this.initialStudySet,
  }) : super(key: key);

  @override
  _StudySetEditPageState createState() => _StudySetEditPageState();
}

class _StudySetEditPageState extends State<StudySetEditPage> {
  late RangeValues _correctRateRange;
  late bool _isFlagged;
  late String? studySetName;
  late List<String> questionSetIds;
  late int? numberOfQuestions;
  late String? selectedQuestionOrder;

  final Map<String, String> orderOptions = {
    "random": "ランダム",
    "attemptsDescending": "試行回数が多い順",
    "attemptsAscending": "試行回数が少ない順",
    "accuracyDescending": "正答率が高い順",
    "accuracyAscending": "正答率が低い順",
    "studyTimeDescending": "学習時間が長い順",
    "studyTimeAscending": "学習時間が短い順",
    "responseTimeDescending": "平均回答時間が長い順",
    "responseTimeAscending": "平均回答時間が短い順",
    "lastStudiedDescending": "最終学習日の降順",
    "lastStudiedAscending": "最終学習日の昇順",
  };

  @override
  void initState() {
    super.initState();
    final studySet = widget.initialStudySet;
    studySetName = studySet.name;
    questionSetIds = studySet.questionSetIds;
    numberOfQuestions = studySet.numberOfQuestions;
    selectedQuestionOrder = studySet.selectedQuestionOrder;
    _correctRateRange = studySet.correctRateRange;
    _isFlagged = studySet.isFlagged;
  }

  Future<void> _updateStudySet() async {
    if (studySetName == null || studySetName!.isEmpty || questionSetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セット名と問題集を入力してください。')),
      );
      return;
    }

    final updatedStudySet = StudySet(
      id: widget.studySetId,
      name: studySetName!,
      questionSetIds: questionSetIds,
      numberOfQuestions: numberOfQuestions!,
      selectedQuestionOrder: selectedQuestionOrder!,
      correctRateRange: _correctRateRange,
      isFlagged: _isFlagged,
    );

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.collection('studySets').doc(widget.studySetId).update(updatedStudySet.toFirestore());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学習セットが更新されました。')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新中にエラーが発生しました: $e')),
      );
    }
  }

  Future<List<String>> _fetchQuestionSetNames(List<String> ids) async {
    try {
      final List<String> names = [];
      for (final id in ids) {
        final doc = await FirebaseFirestore.instance
            .collection('questionSets')
            .doc(id)
            .get();
        if (doc.exists) {
          final name = doc.data()?['name'] as String?;
          if (name != null) {
            names.add(name);
          }
        }
      }
      return names;
    } catch (e) {
      print('Error fetching question set names: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習セットの編集'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              child: Text(
                '保存',
                style: TextStyle(
                  color: (questionSetIds.isNotEmpty && studySetName != null && studySetName!.isNotEmpty)
                      ? AppColors.blue500 // 有効時の色
                      : Colors.grey,      // 無効時の色
                  fontSize: 18,
                ),
              ),
              onPressed: (questionSetIds.isNotEmpty && studySetName != null && studySetName!.isNotEmpty)
                  ? _updateStudySet
                  : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Row(
              children: [
                const Icon(
                  Icons.create,
                  size: 22,
                  color: AppColors.gray600,
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 100,
                  child: Text(
                    "セット名",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(
                  child: Text(
                    (studySetName?.trim().isEmpty ?? true) ? "入力してください。" : studySetName!,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              final name = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SetStudySetNamePage(
                    initialName: studySetName ?? "",
                  ),
                ),
              );
              if (name != null && name is String) {
                setState(() {
                  studySetName = name;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Row(
              children: [
                const Icon(
                  Icons.layers_rounded,
                  size: 22,
                  color: AppColors.gray600,
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 100,
                  child: Text(
                    "問題集",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                if (questionSetIds.isNotEmpty)
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: _fetchQuestionSetNames(questionSetIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            '読み込み中...',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Text(
                            'エラーが発生しました',
                            style: TextStyle(fontSize: 18, color: Colors.red),
                          );
                        }
                        final names = snapshot.data ?? [];
                        return Text(
                          names.join(', '),
                          style: const TextStyle(fontSize: 18),
                        );
                      },
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SetQuestionSetPage(
                    userId: widget.userId,
                    selectedQuestionSetIds: questionSetIds,
                  ),
                ),
              );
              if (result != null && result is List<String>) {
                setState(() {
                  questionSetIds = result;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Row(
                  children: [
                    const Icon(
                      Icons.percent,
                      size: 22,
                      color: AppColors.gray600,
                    ),
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 100,
                      child: Text(
                        "正答率",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    Text(
                      "${_correctRateRange.start.toInt()} 〜 ${_correctRateRange.end.toInt()}%",
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey[300],
                  inactiveTickMarkColor: Colors.grey[300],
                  activeTrackColor: AppColors.blue500,
                  activeTickMarkColor: AppColors.blue500,
                ),
                child: RangeSlider(
                  values: _correctRateRange,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  labels: null,
                  onChanged: (values) {
                    setState(() {
                      if ((values.end - values.start) >= 10) {
                        _correctRateRange = RangeValues(
                          (values.start / 10).round() * 10.0,
                          (values.end / 10).round() * 10.0,
                        );
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.bookmark,
                    size: 22,
                    color: AppColors.gray600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  "フラグあり",
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            value: _isFlagged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.blue500,
            inactiveThumbColor: Colors.black,
            inactiveTrackColor: Colors.white,
            onChanged: (value) {
              setState(() {
                _isFlagged = value;
              });
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Icon(
                    Icons.sort,
                    size: 22,
                    color: AppColors.gray600,
                  ),
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 100,
                  child: Text(
                    "出題順",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                if (selectedQuestionOrder != null)
                  Expanded(
                    child: Text(
                      orderOptions[selectedQuestionOrder] ?? '',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              final selectedOrder = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SetQuestionOrderPage(
                    initialSelection: selectedQuestionOrder,
                  ),
                ),
              );
              if (selectedOrder != null && selectedOrder is String) {
                setState(() {
                  selectedQuestionOrder = selectedOrder;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Row(
              children: [
                const Icon(
                  Icons.format_list_numbered,
                  size: 22,
                  color: AppColors.gray600,
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 100,
                  child: Text(
                    "出題数",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                if (numberOfQuestions != null)
                  Text(
                    "$numberOfQuestions 問",
                    style: const TextStyle(fontSize: 20),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              final selectedCount = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SetNumberOfQuestionsPage(
                    initialSelection: numberOfQuestions,
                  ),
                ),
              );
              if (selectedCount != null && selectedCount is int) {
                setState(() {
                  numberOfQuestions = selectedCount;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
