import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';
import 'package:repaso/utils/question_utils.dart';

class QuestionAddPage extends StatefulWidget {
  final DocumentReference folderRef;
  final DocumentReference questionSetRef;

  const QuestionAddPage({
    Key? key,
    required this.folderRef,
    required this.questionSetRef,
  }) : super(key: key);

  @override
  _QuestionAddPageState createState() => _QuestionAddPageState();
}

class _QuestionAddPageState extends State<QuestionAddPage> {
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _correctChoiceTextController = TextEditingController();
  final TextEditingController _incorrectChoice1TextController = TextEditingController();
  final TextEditingController _incorrectChoice2TextController = TextEditingController();
  final TextEditingController _incorrectChoice3TextController = TextEditingController();

  // 追加: 解説とヒントの入力用コントローラー
  final TextEditingController _explanationTextController = TextEditingController();
  final TextEditingController _hintTextController = TextEditingController();

  // 追加: 出題年月入力用のコントローラーと FocusNode（年・月の各入力ボックス）
  final TextEditingController _examYearController = TextEditingController();
  final TextEditingController _examMonthController = TextEditingController();
  final FocusNode _examYearFocusNode = FocusNode();
  final FocusNode _examMonthFocusNode = FocusNode();

  // 出題年月の内部保持（年と月のみ。日付は自動的に1日固定）
  DateTime? _selectedExamDate;
  // 追加: 出題年月の入力エラー状態を保持するフラグ
  bool _isExamDateError = false;

  // 各 TextField 用の FocusNode を用意
  final FocusNode _questionTextFocusNode = FocusNode();
  final FocusNode _correctChoiceTextFocusNode = FocusNode();
  final FocusNode _incorrectChoice1TextFocusNode = FocusNode();
  final FocusNode _incorrectChoice2TextFocusNode = FocusNode();
  final FocusNode _incorrectChoice3TextFocusNode = FocusNode();
  // 追加: 解説とヒント用の FocusNode
  final FocusNode _explanationTextFocusNode = FocusNode();
  final FocusNode _hintTextFocusNode = FocusNode();

  String _selectedQuestionType = 'true_false';
  bool _trueFalseAnswer = true;
  bool _isSaveEnabled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questionTextController.addListener(_onQuestionTextChanged);

    // ページ表示後に問題文フィールドへフォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_questionTextFocusNode);
    });
  }

  @override
  void dispose() {
    _questionTextController.removeListener(_onQuestionTextChanged);
    _questionTextController.dispose();
    _correctChoiceTextController.dispose();
    _incorrectChoice1TextController.dispose();
    _incorrectChoice2TextController.dispose();
    _incorrectChoice3TextController.dispose();
    _explanationTextController.dispose();
    _hintTextController.dispose();
    _examYearController.dispose();
    _examMonthController.dispose();

    _questionTextFocusNode.dispose();
    _correctChoiceTextFocusNode.dispose();
    _incorrectChoice1TextFocusNode.dispose();
    _incorrectChoice2TextFocusNode.dispose();
    _incorrectChoice3TextFocusNode.dispose();
    _examYearFocusNode.dispose();
    _examMonthFocusNode.dispose();
    _explanationTextFocusNode.dispose();
    _hintTextFocusNode.dispose();
    super.dispose();
  }

  void _onQuestionTextChanged() {
    setState(() {
      _isSaveEnabled = _questionTextController.text.trim().isNotEmpty;
    });
  }

  void _clearFields() {
    _questionTextController.clear();
    _correctChoiceTextController.clear();
    _incorrectChoice1TextController.clear();
    _incorrectChoice2TextController.clear();
    _incorrectChoice3TextController.clear();
    _explanationTextController.clear();
    _hintTextController.clear();
    _examYearController.clear();
    _examMonthController.clear();
    _selectedExamDate = null;
    _isExamDateError = false;

    setState(() {
      _trueFalseAnswer = true;
      _selectedQuestionType = 'true_false';
      _isSaveEnabled = false;
    });

    FocusScope.of(context).requestFocus(_questionTextFocusNode);
  }

  // 修正箇所:
  // 年と月の入力内容から出題年月を更新する（年は4桁、月は1桁・2桁を許容）
  // 年のみの入力の場合は、デフォルトで1月とする。
  // さらに、年が1900年代または2000年代以外の場合もエラーとする。
  // ※ただし、年が空で月も空の場合はエラー状態としない。
  // ※エラー更新は onEditingComplete 時にのみ実行する。
  void _updateExamDateFromInput() {
    final yearText = _examYearController.text;
    final monthText = _examMonthController.text;
    if (yearText.isEmpty) {
      if (monthText.isNotEmpty) {
        setState(() {
          _selectedExamDate = null;
          _isExamDateError = true;
        });
        print("ExamDate updated: $_selectedExamDate, isExamDateError: $_isExamDateError");
      } else {
        setState(() {
          _selectedExamDate = null;
          _isExamDateError = false;
        });
        print("ExamDate updated: $_selectedExamDate, isExamDateError: $_isExamDateError");
      }
      return;
    }
    final year = int.tryParse(yearText);
    if (year == null || yearText.length != 4 || (year < 1900 || year > 2099)) {
      setState(() {
        _selectedExamDate = null;
        _isExamDateError = true;
      });
      print("ExamDate updated: $_selectedExamDate, isExamDateError: $_isExamDateError");
      return;
    }
    if (monthText.isEmpty) {
      setState(() {
        _selectedExamDate = DateTime(year, 1, 1);
        _isExamDateError = false;
      });
      print("ExamDate updated: $_selectedExamDate, isExamDateError: $_isExamDateError");
    } else {
      final month = int.tryParse(monthText);
      if (month == null || month < 1 || month > 12) {
        setState(() {
          _selectedExamDate = null;
          _isExamDateError = true;
        });
        print("ExamDate updated: $_selectedExamDate, isExamDateError: $_isExamDateError");
      } else {
        setState(() {
          _selectedExamDate = DateTime(year, month, 1);
          _isExamDateError = false;
        });
        print("ExamDate updated: $_selectedExamDate, isExamDateError: $_isExamDateError");
      }
    }
  }

  Future<void> _addQuestion() async {
    // 保存前に最新のExamDateを更新
    _updateExamDateFromInput();
    if (!_isSaveEnabled || _isSaving || _isExamDateError) return;
    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。問題を保存するにはログインしてください。')),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final folderRef = widget.folderRef;
    final questionSetRef = widget.questionSetRef;

    final questionData = {
      'questionSetRef': questionSetRef,
      'questionText': _questionTextController.text.trim(),
      'questionType': _selectedQuestionType,
      'tags': [],
      'isDeleted': false,
      'isFlagged': false,
      'isOfficialQuestion': false,
      'examDate': _selectedExamDate != null ? Timestamp.fromDate(_selectedExamDate!) : null,
      'createdByRef': FirebaseFirestore.instance.collection('users').doc(user.uid),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'explanationText': _explanationTextController.text.trim(),
      'hintText': _hintTextController.text.trim(),
    };

    if (_selectedQuestionType == 'true_false') {
      questionData.addAll({
        'correctChoiceText': _trueFalseAnswer ? '正しい' : '間違い',
        'incorrectChoice1Text': !_trueFalseAnswer ? '正しい' : '間違い',
      });
    } else if (_selectedQuestionType == 'single_choice') {
      questionData.addAll({
        'correctChoiceText': _correctChoiceTextController.text.trim(),
        'incorrectChoice1Text': _incorrectChoice1TextController.text.trim(),
        'incorrectChoice2Text': _incorrectChoice2TextController.text.trim(),
        'incorrectChoice3Text': _incorrectChoice3TextController.text.trim(),
      });
    }

    try {
      await FirebaseFirestore.instance.collection('questions').add(questionData);
      await updateQuestionCounts(folderRef, questionSetRef);

      _clearFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が保存されました')),
      );
    } catch (e) {
      print('Error saving question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の保存に失敗しました')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildExamDateField() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isExamDateError ? Colors.red : Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '出題年月',
            style: TextStyle(fontSize: 14, color: _isExamDateError ? Colors.red : Colors.black54),
          ),
          const SizedBox(width: 32),
          Container(
            width: 72,
            child: TextField(
              controller: _examYearController,
              focusNode: _examYearFocusNode,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'yyyy',
                border: InputBorder.none,
              ),
              onChanged: (value) {
                if (value.length == 4) {
                  FocusScope.of(context).requestFocus(_examMonthFocusNode);
                }
              },
              onEditingComplete: () {
                _updateExamDateFromInput();
              },
            ),
          ),
          Text(
            '/',
            style: TextStyle(fontSize: 14, color: _isExamDateError ? Colors.red : Colors.black54),
          ),
          Container(
            width: 48,
            child: TextField(
              controller: _examMonthController,
              focusNode: _examMonthFocusNode,
              maxLength: 2,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'mm',
                border: InputBorder.none,
              ),
              onChanged: (_) {
                // エラー更新は onEditingComplete で実施
              },
              onEditingComplete: () {
                _updateExamDateFromInput();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool canSave = _isSaveEnabled && !_isSaving && !_isExamDateError;
    final bool isAnyTextFieldFocused =
        _questionTextFocusNode.hasFocus ||
            _correctChoiceTextFocusNode.hasFocus ||
            _incorrectChoice1TextFocusNode.hasFocus ||
            _incorrectChoice2TextFocusNode.hasFocus ||
            _incorrectChoice3TextFocusNode.hasFocus ||
            _examYearFocusNode.hasFocus ||
            _examMonthFocusNode.hasFocus ||
            _explanationTextFocusNode.hasFocus ||
            _hintTextFocusNode.hasFocus;
    final bool showBottomSaveButton = isKeyboardOpen && isAnyTextFieldFocused && _isSaveEnabled;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('問題作成'),
        actions: [
          TextButton(
            onPressed: canSave ? _addQuestion : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '保存',
                style: TextStyle(
                  color: canSave ? AppColors.blue500 : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: showBottomSaveButton
          ? Container(
        color: AppColors.gray50,
        padding: const EdgeInsets.only(bottom: 4.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canSave ? AppColors.blue500 : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: canSave ? _addQuestion : null,
              child: Text(
                '保存',
                style: TextStyle(
                  fontSize: 14,
                  color: canSave ? Colors.white : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      )
          : null,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {});
        },
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildChip(
                    label: '正誤問題',
                    icon: Icons.check_circle_outline,
                    isSelected: _selectedQuestionType == 'true_false',
                    onTap: () {
                      setState(() {
                        _selectedQuestionType = 'true_false';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    label: '四択問題',
                    icon: Icons.list_alt,
                    isSelected: _selectedQuestionType == 'single_choice',
                    onTap: () {
                      setState(() {
                        _selectedQuestionType = 'single_choice';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildExpandableTextField(
                controller: _questionTextController,
                labelText: '問題文',
                textFieldHeight: 80,
                focusedHintText: '例）日本の首都は東京である。',
              ),
              const SizedBox(height: 16),
              if (_selectedQuestionType == 'true_false')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrueFalseSelectionTile(
                      label: '正しい',
                      value: true,
                      groupValue: _trueFalseAnswer,
                      onTap: () {
                        setState(() {
                          _trueFalseAnswer = true;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildTrueFalseSelectionTile(
                      label: '間違い',
                      value: false,
                      groupValue: _trueFalseAnswer,
                      onTap: () {
                        setState(() {
                          _trueFalseAnswer = false;
                        });
                      },
                    ),
                  ],
                ),
              if (_selectedQuestionType == 'single_choice') ...[
                _buildExpandableTextField(
                  controller: _correctChoiceTextController,
                  labelText: '正解の選択肢',
                  textFieldHeight: 18,
                  focusedHintText: '例）東京である。',
                ),
                const SizedBox(height: 16),
                _buildExpandableTextField(
                  controller: _incorrectChoice1TextController,
                  labelText: '誤答1',
                  textFieldHeight: 18,
                  focusedHintText: '例）大阪である。',
                ),
                const SizedBox(height: 16),
                _buildExpandableTextField(
                  controller: _incorrectChoice2TextController,
                  labelText: '誤答2',
                  textFieldHeight: 16,
                  focusedHintText: '例）京都である。',
                ),
                const SizedBox(height: 16),
                _buildExpandableTextField(
                  controller: _incorrectChoice3TextController,
                  labelText: '誤答3',
                  textFieldHeight: 18,
                  focusedHintText: '例）名古屋である。',
                ),
              ],
              const SizedBox(height: 32),
              _buildExamDateField(),
              const SizedBox(height: 16),
              _buildExpandableTextField(
                controller: _explanationTextController,
                labelText: '解説',
                textFieldHeight: 24,
                focusedHintText: '例）東京は、1869年（明治2年）に首都となりました',
              ),
              const SizedBox(height: 16),
              _buildExpandableTextField(
                controller: _hintTextController,
                labelText: 'ヒント',
                textFieldHeight: 24,
                focusedHintText: '関東地方にある都道府県です。',
              ),
              const SizedBox(height: 300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue100 : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isSelected ? AppColors.gray50 : AppColors.gray50,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.blue500 : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.blue500 : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrueFalseSelectionTile({
    required String label,
    required bool value,
    required bool groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.gray50 : AppColors.gray50,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: isSelected ? AppColors.blue500 : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableTextField({
    required TextEditingController controller,
    required String labelText,
    double textFieldHeight = 16,
    String? focusedHintText,
  }) {
    FocusNode? focusNode;
    if (controller == _questionTextController) {
      focusNode = _questionTextFocusNode;
    } else if (controller == _correctChoiceTextController) {
      focusNode = _correctChoiceTextFocusNode;
    } else if (controller == _incorrectChoice1TextController) {
      focusNode = _incorrectChoice1TextFocusNode;
    } else if (controller == _incorrectChoice2TextController) {
      focusNode = _incorrectChoice2TextFocusNode;
    } else if (controller == _incorrectChoice3TextController) {
      focusNode = _incorrectChoice3TextFocusNode;
    } else if (controller == _explanationTextController) {
      focusNode = _explanationTextFocusNode;
    } else if (controller == _hintTextController) {
      focusNode = _hintTextFocusNode;
    }
    final bool hasFocus = focusNode?.hasFocus ?? false;
    final bool isEmpty = controller.text.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.transparent,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: textFieldHeight),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 1,
          maxLines: null,
          style: const TextStyle(height: 1.2),
          cursorColor: AppColors.blue500,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: labelText,
            labelStyle: const TextStyle(
              fontSize: 14.0,
              color: Colors.black54,
            ),
            floatingLabelStyle: const TextStyle(
              fontSize: 16.0,
              color: AppColors.blue500,
            ),
            hintText: (hasFocus && isEmpty) ? focusedHintText : null,
            hintStyle: const TextStyle(
              fontSize: 14.0,
              color: Colors.grey,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }
}
