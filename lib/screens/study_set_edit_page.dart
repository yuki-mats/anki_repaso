// ignore_for_file: always_use_package_imports, avoid_print
// FolderListPage の実装を踏襲し、RevenueCat 経由で isPro を正確に取得します。
// UI / UX や既存の機能は一切変更していません。★ 印が追加・変更箇所です。

import 'dart:async'; // Future/Stream 用
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';                 // ★ 追加
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/screens/set_study_set_name_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/screens/set_number_of_questions_page.dart';
import 'package:repaso/screens/set_question_order_page.dart';
import 'package:repaso/screens/set_question_set_page.dart';
import 'package:repaso/widgets/set_memory_level_page.dart';

// ──────────────────────────────
// StudySet モデル
// ──────────────────────────────
class StudySet {
  final String id;
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

// ──────────────────────────────
// 画面
// ──────────────────────────────
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
  // 基本プロパティ
  late RangeValues _correctRateRange;
  late bool _isFlagged;
  late String? studySetName;
  late List<String> questionSetIds;
  late int? numberOfQuestions;
  late String? selectedQuestionOrder;
  late List<String> _selectedMemoryLevels;

  // Pro 判定
  bool _isPro = false;                                        // ★
  late final void Function(CustomerInfo) _customerInfoListener; // ★

  // メモリレベル表示用ラベル
  final Map<String, String> _memoryLevelLabels = {
    'again': 'もう一度',
    'hard': '難しい',
    'good': '普通',
    'easy': '簡単',
  };

  // キャッシュ
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

  // ──────────────────────────────
  // init
  // ──────────────────────────────
  @override
  void initState() {
    super.initState();

    debugPrint('[DEBUG] StudySetEditPage opened  user=${widget.userId}  set=${widget.studySetId}');

    final s = widget.initialStudySet;
    studySetName          = s.name;
    questionSetIds        = s.questionSetIds;
    numberOfQuestions     = s.numberOfQuestions;
    selectedQuestionOrder = s.selectedQuestionOrder;
    _correctRateRange     = s.correctRateRange;
    _isFlagged            = s.isFlagged;
    _selectedMemoryLevels = List.from(s.selectedMemoryLevels);

    _fetchAndCacheQuestionSetNames();

    // ─── RevenueCat から Pro ステータスを取得 ─── ★
    Purchases.getCustomerInfo().then((info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      debugPrint('[DEBUG] initial isPro status: $active');
      if (mounted) setState(() => _isPro = active);
    });

    _customerInfoListener = (CustomerInfo info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      debugPrint('[DEBUG] CustomerInfo updated isPro: $active');
      if (mounted && _isPro != active) setState(() => _isPro = active);
    };
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
  }

  // ──────────────────────────────
  // dispose
  // ──────────────────────────────
  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_customerInfoListener); // ★
    super.dispose();
  }

  // ──────────────────────────────
  // 問題集名取得
  // ──────────────────────────────
  Future<void> _fetchAndCacheQuestionSetNames() async {
    _cachedQuestionSetNames = await _fetchQuestionSetNames(questionSetIds);
    if (mounted) setState(() {});
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
          if (name != null) names.add(name);
        }
      }
      return names;
    } catch (e) {
      debugPrint('[DEBUG] _fetchQuestionSetNames error: $e');
      return [];
    }
  }

  // ──────────────────────────────
  // 保存処理
  // ──────────────────────────────
  Future<void> _updateStudySet() async {
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

    final updatedStudySet = StudySet(
      id: widget.studySetId,
      name: studySetName!,
      questionSetIds: questionSetIds,
      numberOfQuestions: numberOfQuestions!,
      selectedQuestionOrder: selectedQuestionOrder!,
      correctRateRange: _correctRateRange,
      isFlagged: _isFlagged,
      selectedMemoryLevels: _selectedMemoryLevels,
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
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

  // ──────────────────────────────
  // build
  // ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('暗記セットの編集'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[300], height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── セット名
          ListTile(
            title: Row(
              children: [
                const Icon(Icons.create, size: 22, color: AppColors.gray600),
                const SizedBox(width: 6),
                const SizedBox(width: 60, child: Text("セット名", style: TextStyle(fontSize: 14))),
                Expanded(
                  child: Text(
                    (studySetName?.trim().isEmpty ?? true) ? "入力してください。" : studySetName!,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray600),
            onTap: () async {
              final name = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetStudySetNamePage(initialName: studySetName ?? ""),
                ),
              );
              if (name is String) setState(() => studySetName = name);
            },
          ),

          // ── 問題集
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
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetQuestionSetPage(
                    userId: widget.userId,
                    selectedQuestionSetIds: questionSetIds,
                  ),
                ),
              );
              if (result is List<String>) {
                final List<String> validIds = [];
                final List<String> validNames = [];
                for (final id in result) {
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

          // ── 記憶度
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
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetMemoryLevelPage(initialSelection: _selectedMemoryLevels),
                ),
              );
              if (result is List<String>) setState(() => _selectedMemoryLevels = result);
            },
          ),

          // ── フラグあり
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
                onChanged: (v) => setState(() => _isFlagged = v),
              ),
            ),
            onTap: () => setState(() => _isFlagged = !_isFlagged),
          ),

          // ── 正答率
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                onTap: !_isPro
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaywallPage(
                        subtitle: '暗記セットで正答率フィルターを編集するには、Proプランが必要です。',
                      ),
                    ),
                  );
                }
                    : null,
                title: Row(
                  children: [
                    Icon(_isPro ? Icons.percent : Icons.lock,
                        size: 22, color: Colors.amber),
                    const SizedBox(width: 6),
                    const SizedBox(width: 80, child: Text("正答率", style: TextStyle(fontSize: 14))),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "${_correctRateRange.start.toInt()} 〜 ${_correctRateRange.end.toInt()}%",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isPro
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaywallPage(
                        subtitle: '正答率フィルターを編集するには Pro プランが必要です。',
                      ),
                    ),
                  );
                },
                child: AbsorbPointer(
                  absorbing: !_isPro,
                  child: SliderTheme(
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
                      onChanged: _isPro
                          ? (v) {
                        setState(() {
                          if ((v.end - v.start) >= 10) {
                            _correctRateRange = RangeValues(
                              (v.start / 10).round() * 10.0,
                              (v.end / 10).round() * 10.0,
                            );
                          }
                        });
                      }
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── 出題順
          ListTile(
            title: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(_isPro ? Icons.sort : Icons.lock,
                      size: 22, color: Colors.amber),
                ),
                const SizedBox(width: 6),
                const SizedBox(width: 55, child: Text("出題順", style: TextStyle(fontSize: 14))),
                if (selectedQuestionOrder != null)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          orderOptions[selectedQuestionOrder] ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
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
              if (selOrder is String) setState(() => selectedQuestionOrder = selOrder);
            },
          ),

          // ── 出題数
          ListTile(
            title: Row(
              children: [
                Icon(_isPro ? Icons.format_list_numbered : Icons.lock,
                    size: 22, color: Colors.amber),
                const SizedBox(width: 6),
                const SizedBox(width: 55, child: Text("出題数", style: TextStyle(fontSize: 14))),
                if (numberOfQuestions != null)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "最大 $numberOfQuestions 問",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
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
              if (selectedCount is int) setState(() => numberOfQuestions = selectedCount);
            },
          ),
        ],
      ),

      // ── 保存ボタン
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        child: Container(
          padding: const EdgeInsets.all(12),
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
