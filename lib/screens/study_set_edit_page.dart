import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/set_study_set_name_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/screens/set_number_of_questions_page.dart';
import 'package:repaso/screens/set_question_order_page.dart';
import 'package:repaso/screens/set_question_set_page.dart';
import 'package:repaso/widgets/set_memory_level_page.dart'; // ← メモリレベル選択ページを利用

class StudySet {
  final String id; // ドキュメント ID
  final String name;
  final List<String> questionSetIds;
  final int numberOfQuestions;
  final String selectedQuestionOrder;
  final RangeValues correctRateRange;
  final bool isFlagged;
  final List<String> selectedMemoryLevels;

  StudySet({
    required this.id,
    required this.name,
    required this.questionSetIds,
    required this.numberOfQuestions,
    required this.selectedQuestionOrder,
    required this.correctRateRange,
    required this.isFlagged,
    required this.selectedMemoryLevels,
  });

  // Firestoreデータから生成するファクトリコンストラクタ
  factory StudySet.fromFirestore(String id, Map<String, dynamic> data) {
    return StudySet(
      id: id,
      name: data['name'] as String,
      questionSetIds: List<String>.from(data['questionSetIds'] ?? []),
      numberOfQuestions: data['numberOfQuestions'] as int,
      selectedQuestionOrder: data['selectedQuestionOrder'] as String,
      correctRateRange: RangeValues(
        (data['correctRateRange']?['start'] ?? 0.0) as double,
        (data['correctRateRange']?['end'] ?? 100.0) as double,
      ),
      isFlagged: data['isFlagged'] as bool? ?? false,
      selectedMemoryLevels: List<String>.from(
        data['selectedMemoryLevels'] ?? ['again', 'hard', 'good', 'easy'],
      ),
    );
  }

  // Firestore に保存するためのMap形式に変換
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
      'selectedMemoryLevels': selectedMemoryLevels,
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
  late List<String> _selectedMemoryLevels;

  // メモリレベルのラベル（UI表示用）
  final Map<String, String> _memoryLevelLabels = {
    'again': 'もう一度',
    'hard': '難しい',
    'good': '普通',
    'easy': '簡単',
  };

  // 問題集名のキャッシュ
  List<String> _cachedQuestionSetNames = [];

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
    final s = widget.initialStudySet;
    studySetName = s.name;
    questionSetIds = s.questionSetIds;
    numberOfQuestions = s.numberOfQuestions;
    selectedQuestionOrder = s.selectedQuestionOrder;
    _correctRateRange = s.correctRateRange;
    _isFlagged = s.isFlagged;
    _selectedMemoryLevels = List.from(s.selectedMemoryLevels);

    // 問題集名を取得
    _fetchAndCacheQuestionSetNames();
  }

  Future<void> _fetchAndCacheQuestionSetNames() async {
    _cachedQuestionSetNames = await _fetchQuestionSetNames(questionSetIds);
    setState(() {});
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

  Future<void> _updateStudySet() async {
    // バリデーション
    if (studySetName == null ||
        studySetName!.isEmpty ||
        questionSetIds.isEmpty ||
        numberOfQuestions == null ||
        selectedQuestionOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セット名と問題集、出題数・出題順を入力してください。')),
      );
      return;
    }

    // 保存用データ作成
    final updatedStudySet = StudySet(
      id: widget.studySetId,
      name: studySetName!,
      questionSetIds: questionSetIds,
      numberOfQuestions: numberOfQuestions!,
      selectedQuestionOrder: selectedQuestionOrder!,
      correctRateRange: _correctRateRange,
      isFlagged: _isFlagged,
      selectedMemoryLevels: _selectedMemoryLevels, // ← これが重要
    );

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      // Firestore へ反映
      await userRef
          .collection('studySets')
          .doc(widget.studySetId)
          .update(updatedStudySet.toFirestore());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暗記セットが更新されました。')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新中にエラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('暗記セットの編集'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // セット名
          ListTile(
            title: Row(
              children: [
                const Icon(Icons.create, size: 22, color: AppColors.gray600),
                const SizedBox(width: 6),
                const SizedBox(width: 60, child: Text("セット名", style: TextStyle(fontSize: 14))),
                Expanded(
                  child: Text(
                    (studySetName?.trim().isEmpty ?? true)
                        ? "入力してください。"
                        : studySetName!,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray600),
            onTap: () async {
              final name = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SetStudySetNamePage(
                    initialName: studySetName ?? "",
                  ),
                ),
              );
              if (name != null && name is String) {
                setState(() => studySetName = name);
              }
            },
          ),
          // 問題集
          ListTile(
            title: Row(
              children: [
                const Icon(Icons.layers_rounded, size: 22, color: AppColors.gray600),
                const SizedBox(width: 6),
                const SizedBox(width: 50, child: Text("問題集", style: TextStyle(fontSize: 14))),
                if (_cachedQuestionSetNames.isNotEmpty)
                  Expanded(
                    child: Text(
                      _cachedQuestionSetNames.join(', '),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray600),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SetQuestionSetPage(
                    userId: widget.userId,
                    selectedQuestionSetIds: questionSetIds,
                  ),
                ),
              );
              if (result != null && result is List<String>) {
                // 削除済みを除外
                List<String> validIds = [];
                List<String> validNames = [];
                for (var id in result) {
                  final doc = await FirebaseFirestore.instance
                      .collection('questionSets')
                      .doc(id)
                      .get();
                  if (doc.exists && (doc.data()?['isDeleted'] ?? false) == false) {
                    validIds.add(id);
                    validNames.add(doc.data()?['name'] as String);
                  }
                }
                setState(() {
                  questionSetIds = validIds;
                  _cachedQuestionSetNames = validNames;
                });
              }
            },
          ),
          // 正答率
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Row(
                  children: [
                    const Icon(Icons.percent, size: 22, color: AppColors.gray600),
                    const SizedBox(width: 6),
                    const SizedBox(width: 80, child: Text("正答率", style: TextStyle(fontSize: 14))),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          "${_correctRateRange.start.toInt()} 〜 ${_correctRateRange.end.toInt()}%",
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.end,
                        ),
                      ),
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

              // ▼ 記憶度
              ListTile(
                title: Row(
                  children: [
                    const Icon(Icons.memory, size: 22, color: AppColors.gray600),
                    const SizedBox(width: 6),
                    const SizedBox(width: 80, child: Text("記憶度", style: TextStyle(fontSize: 14))),
                    Expanded(
                      child: Text(
                        _selectedMemoryLevels.length == 4
                            ? "すべて"
                            : _selectedMemoryLevels
                            .map((e) => _memoryLevelLabels[e] ?? e)
                            .join(', '),
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray600),
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SetMemoryLevelPage(
                        initialSelection: _selectedMemoryLevels,
                      ),
                    ),
                  );
                  if (result != null && result is List<String>) {
                    setState(() {
                      _selectedMemoryLevels = result;
                    });
                  }
                },
              ),
            ],
          ),
          // フラグあり
          ListTile(
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark, size: 22, color: AppColors.gray600),
                SizedBox(width: 6),
                Text("フラグあり", style: TextStyle(fontSize: 14)),
              ],
            ),
            trailing: Transform.scale(
              scale: 0.8,
              child: Switch(
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
            ),
            onTap: () {
              setState(() {
                _isFlagged = !_isFlagged;
              });
            },
          ),
          // 出題順
          ListTile(
            title: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Icon(Icons.sort, size: 22, color: AppColors.gray600),
                ),
                const SizedBox(width: 6),
                const SizedBox(width: 55, child: Text("出題順", style: TextStyle(fontSize: 14))),
                if (selectedQuestionOrder != null)
                  Expanded(
                    child: Text(
                      orderOptions[selectedQuestionOrder] ?? '',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              final selOrder = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetQuestionOrderPage(
                    initialSelection: selectedQuestionOrder,
                  ),
                ),
              );
              if (selOrder != null && selOrder is String) {
                setState(() {
                  selectedQuestionOrder = selOrder;
                });
              }
            },
          ),
          // 最大
          ListTile(
            title: Row(
              children: [
                const Icon(Icons.format_list_numbered, size: 22, color: AppColors.gray600),
                const SizedBox(width: 6),
                const SizedBox(width: 55, child: Text("最大", style: TextStyle(fontSize: 14))),
                if (numberOfQuestions != null)
                  Expanded(
                    child: Text(
                      "$numberOfQuestions 問",
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              final selectedCount = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetNumberOfQuestionsPage(
                    initialSelection: numberOfQuestions,
                  ),
                ),
              );
              if (selectedCount != null && selectedCount is int) {
                setState(() => numberOfQuestions = selectedCount);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left:16.0, right:16.0, bottom:24.0),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: (questionSetIds.isNotEmpty &&
                studySetName != null &&
                studySetName!.isNotEmpty &&
                numberOfQuestions != null &&
                selectedQuestionOrder != null)
                ? _updateStudySet
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: (questionSetIds.isNotEmpty &&
                  studySetName != null &&
                  studySetName!.isNotEmpty &&
                  numberOfQuestions != null &&
                  selectedQuestionOrder != null)
                  ? AppColors.blue500
                  : Colors.grey,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: const Text('保存', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
