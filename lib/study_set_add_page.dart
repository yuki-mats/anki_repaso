import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/set_number_of_questions_page.dart';
import 'package:repaso/set_question_order_page.dart';
import 'package:repaso/set_question_set_page.dart';
import 'package:repaso/set_study_set_name_page.dart';
import 'package:repaso/widgets/set_memory_level_page.dart';

/// StudySet モデル（StudySetEditPage に合わせた追加フィールド付き）
class StudySet {
  final String name;
  final List<String> questionSetIds;
  final int numberOfQuestions;
  final String selectedQuestionOrder;
  final RangeValues correctRateRange;
  final bool isFlagged;
  // 追加フィールド
  final Map<String, int> memoryLevelStats;
  final Map<String, int> memoryLevelRatios;
  final int totalAttemptCount;
  final int studyStreakCount;
  final String lastStudiedDate;
  final List<String> selectedMemoryLevels;
  final Timestamp? createdAt;

  StudySet({
    required this.name,
    required this.questionSetIds,
    required this.numberOfQuestions,
    required this.selectedQuestionOrder,
    required this.correctRateRange,
    required this.isFlagged,
    required this.memoryLevelStats,
    required this.memoryLevelRatios,
    required this.totalAttemptCount,
    required this.studyStreakCount,
    required this.lastStudiedDate,
    required this.selectedMemoryLevels,
    this.createdAt,
  });

  // Firestoreデータから生成するファクトリコンストラクタ（存在しない場合はデフォルト値を設定）
  factory StudySet.fromFirestore(Map<String, dynamic> data) {
    return StudySet(
      name: data['name'] as String,
      questionSetIds: List<String>.from(data['questionSetIds'] ?? []),
      numberOfQuestions: data['numberOfQuestions'] as int,
      selectedQuestionOrder: data['selectedQuestionOrder'] as String,
      correctRateRange: RangeValues(
        (data['correctRateRange']?['start'] ?? 0.0).toDouble(),
        (data['correctRateRange']?['end'] ?? 100.0).toDouble(),
      ),
      isFlagged: data['isFlagged'] as bool? ?? false,
      memoryLevelStats: Map<String, int>.from(
          data['memoryLevelStats'] ?? {'again': 0, 'hard': 0, 'good': 0, 'easy': 0}),
      memoryLevelRatios: Map<String, int>.from(
          data['memoryLevelRatios'] ?? {'again': 0, 'hard': 0, 'good': 0, 'easy': 0}),
      totalAttemptCount: data['totalAttemptCount'] ?? 0,
      studyStreakCount: data['studyStreakCount'] ?? 0,
      lastStudiedDate: data['lastStudiedDate'] ?? "",
      selectedMemoryLevels: List<String>.from(data['selectedMemoryLevels'] ?? []),
      createdAt: data['createdAt'],
    );
  }

  // Firestore に保存するための Map 形式に変換
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isDeleted': false,
      'questionSetIds': questionSetIds,
      'numberOfQuestions': numberOfQuestions,
      'selectedQuestionOrder': selectedQuestionOrder,
      'correctRateRange': {
        'start': correctRateRange.start,
        'end': correctRateRange.end,
      },
      'isFlagged': isFlagged,
      'memoryLevelStats': memoryLevelStats,
      'memoryLevelRatios': memoryLevelRatios,
      'totalAttemptCount': totalAttemptCount,
      'studyStreakCount': studyStreakCount,
      'lastStudiedDate': lastStudiedDate,
      'selectedMemoryLevels': selectedMemoryLevels,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class StudySetAddPage extends StatefulWidget {
  final StudySet? studySet;

  const StudySetAddPage({
    Key? key,
    this.studySet,
  }) : super(key: key);

  @override
  _StudySetAddPageState createState() => _StudySetAddPageState();
}

class _StudySetAddPageState extends State<StudySetAddPage> {
  late RangeValues _correctRateRange;
  late bool _isFlagged;
  late String? studySetName;
  late List<String> questionSetIds;
  late int? numberOfQuestions;
  late String? selectedQuestionOrder;
  List<String> _cachedQuestionSetNames = [];
  List<String> _selectedMemoryLevels = ['again', 'hard', 'good', 'easy'];
  final Map<String, String> _memoryLevelLabels = {
    'again': 'もう一度',
    'hard': '難しい',
    'good': '普通',
    'easy': '簡単',
  };
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
    if (widget.studySet != null) {
      final studySet = widget.studySet!;
      studySetName = studySet.name;
      questionSetIds = studySet.questionSetIds;
      numberOfQuestions = studySet.numberOfQuestions;
      selectedQuestionOrder = studySet.selectedQuestionOrder;
      _correctRateRange = studySet.correctRateRange;
      _isFlagged = studySet.isFlagged;
    } else {
      studySetName = null;
      questionSetIds = [];
      numberOfQuestions = null;
      selectedQuestionOrder = null;
      _correctRateRange = const RangeValues(0, 100);
      _isFlagged = false;
    }
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

  Future<void> _saveStudySet() async {
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください。')),
      );
      return;
    }

    // 新規作成時は追加フィールドはすべて初期値とする
    final newStudySet = StudySet(
      name: studySetName!,
      questionSetIds: questionSetIds,
      numberOfQuestions: numberOfQuestions!,
      selectedQuestionOrder: selectedQuestionOrder!,
      correctRateRange: _correctRateRange,
      isFlagged: _isFlagged,
      memoryLevelStats: {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      memoryLevelRatios: {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      totalAttemptCount: 0,
      studyStreakCount: 0,
      lastStudiedDate: "",
      selectedMemoryLevels: _selectedMemoryLevels,
    );

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.collection('studySets').add(newStudySet.toFirestore());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学習セットが保存されました。')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存中にエラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習セットの追加'),
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
          // セット名入力
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
                  width: 60,
                  child: Text(
                    "セット名",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Text(
                    (studySetName?.trim().isEmpty ?? true) ? "入力してください。" : studySetName!,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.end, // 右揃え
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray600),
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
          // 問題集選択
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
                  width: 50,
                  child: Text(
                    "問題集",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                if (_cachedQuestionSetNames.isNotEmpty)
                  Expanded(
                    child: Text(
                      _cachedQuestionSetNames.join(', '),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.end, // 右揃え
                    ),
                  ),

              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray600),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SetQuestionSetPage(
                    userId: FirebaseAuth.instance.currentUser!.uid,
                    selectedQuestionSetIds: questionSetIds,
                  ),
                ),
              );
              if (result != null && result is List<String>) {
                setState(() {
                  questionSetIds = result;
                  _fetchAndCacheQuestionSetNames(); // 問題集名を再取得
                });
              }
            },
          ),
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
                      width: 80,
                      child: Text(
                        "正答率",
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    Expanded( // 追加: `Expanded` で空白を作る
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          "${_correctRateRange.start.toInt()} 〜 ${_correctRateRange.end.toInt()}%",
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.end, // 右寄せ
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
                child: SizedBox(
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
              ),
              ListTile(
                title: Row(
                  children: [
                    const Icon(Icons.memory, size: 22, color: AppColors.gray600),
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 80,
                      child: Text("記憶度", style: TextStyle(fontSize: 14)),
                    ),
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
                      builder: (context) => SetMemoryLevelPage(
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
          ListTile(
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bookmark,
                  size: 22,
                  color: AppColors.gray600,
                ),
                SizedBox(width: 6),
                Text(
                  "フラグあり",
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            trailing: Transform.scale(
              scale: 0.8, // スイッチの大きさを変更（1.0がデフォルト）
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
                  width: 55,
                  child: Text(
                    "出題順",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
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
                  width: 55,
                  child: Text(
                    "最大",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: (questionSetIds.isNotEmpty &&
                studySetName != null &&
                studySetName!.isNotEmpty &&
                numberOfQuestions != null &&
                selectedQuestionOrder != null)
                ? _saveStudySet
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
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
