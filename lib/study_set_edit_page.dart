import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
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
  List<String> _cachedQuestionSetNames = []; // キャッシュされた問題集名

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
    _fetchAndCacheQuestionSetNames(); // 初回の名前取得
  }

  Future<void> _fetchAndCacheQuestionSetNames() async {
    _cachedQuestionSetNames = await _fetchQuestionSetNames(questionSetIds);
    setState(() {}); // 名前取得後に再描画
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
        const SnackBar(content: Text('暗記セットが更新されました。')),
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('暗記セットの編集'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0), // 線の高さ
          child: Container(
            color: Colors.grey[300], // 薄いグレーの線
            height: 1.0,
          ),
        ),
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
                    userId: widget.userId,
                    selectedQuestionSetIds: questionSetIds,
                  ),
                ),
              );

              if (result != null && result is List<String>) {
                List<String> validIds = [];
                List<String> validNames = [];

                for (var id in result) {
                  final doc = await FirebaseFirestore.instance
                      .collection('questionSets')
                      .doc(id)
                      .get();

                  // 削除済みの問題集を除外
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
        padding: const EdgeInsets.only(left:16.0, right:16.0, bottom: 24.0),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: (questionSetIds.isNotEmpty && studySetName != null && studySetName!.isNotEmpty)
                ? _updateStudySet
                : null, // 必要な条件を満たさない場合は無効化
            style: ElevatedButton.styleFrom(
              backgroundColor: (questionSetIds.isNotEmpty && studySetName != null && studySetName!.isNotEmpty)
                  ? AppColors.blue500 // 有効時の色
                  : Colors.grey,      // 無効時の色
              minimumSize: const Size.fromHeight(48), // ボタンの高さを設定
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
