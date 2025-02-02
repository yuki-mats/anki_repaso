import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';
import 'package:repaso/utils/question_utils.dart';

class QuestionEditPage extends StatefulWidget {
  final DocumentSnapshot question; // 編集する問題のドキュメント

  const QuestionEditPage({
    Key? key,
    required this.question,
  }) : super(key: key);

  @override
  _QuestionEditPageState createState() => _QuestionEditPageState();
}

class _QuestionEditPageState extends State<QuestionEditPage> {
  // 各入力用コントローラー
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _correctChoiceTextController = TextEditingController();
  final TextEditingController _incorrectChoice1TextController = TextEditingController();
  final TextEditingController _incorrectChoice2TextController = TextEditingController();
  final TextEditingController _incorrectChoice3TextController = TextEditingController();
  final TextEditingController _explanationTextController = TextEditingController();
  final TextEditingController _hintTextController = TextEditingController();
  final TextEditingController _examYearController = TextEditingController();
  final TextEditingController _examMonthController = TextEditingController();

  // 各 FocusNode
  final FocusNode _questionTextFocusNode = FocusNode();
  final FocusNode _correctChoiceTextFocusNode = FocusNode();
  final FocusNode _incorrectChoice1TextFocusNode = FocusNode();
  final FocusNode _incorrectChoice2TextFocusNode = FocusNode();
  final FocusNode _incorrectChoice3TextFocusNode = FocusNode();
  final FocusNode _explanationTextFocusNode = FocusNode();
  final FocusNode _hintTextFocusNode = FocusNode();
  final FocusNode _examYearFocusNode = FocusNode();
  final FocusNode _examMonthFocusNode = FocusNode();

  String _selectedQuestionType = 'true_false';
  bool _trueFalseAnswer = true;
  bool _isSaving = false;
  bool _isSaveEnabled = false;
  bool _isExamDateError = false;
  bool _isLoading = true;
  DateTime? _selectedExamDate;

  @override
  void initState() {
    super.initState();
    _questionTextController.addListener(_onQuestionTextChanged);
    _loadQuestionData();
  }

  void _onQuestionTextChanged() {
    setState(() {
      _isSaveEnabled = _questionTextController.text.trim().isNotEmpty;
    });
  }

  void _loadQuestionData() {
    final data = widget.question.data() as Map<String, dynamic>;
    setState(() {
      _questionTextController.text = data['questionText'] ?? '';
      _selectedQuestionType = data['questionType'] ?? 'true_false';

      if (_selectedQuestionType == 'true_false') {
        // 正誤問題の場合
        _trueFalseAnswer = data['correctChoiceText'] == '正しい';
      } else if (_selectedQuestionType == 'single_choice') {
        // 四択問題の場合
        _correctChoiceTextController.text = data['correctChoiceText'] ?? '';
        _incorrectChoice1TextController.text = data['incorrectChoice1Text'] ?? '';
        _incorrectChoice2TextController.text = data['incorrectChoice2Text'] ?? '';
        _incorrectChoice3TextController.text = data['incorrectChoice3Text'] ?? '';
      }
      // 出題年月（examDate）の読み込み
      if (data['examDate'] != null) {
        final Timestamp ts = data['examDate'] as Timestamp;
        _selectedExamDate = ts.toDate();
        _examYearController.text = _selectedExamDate!.year.toString();
        _examMonthController.text = _selectedExamDate!.month.toString().padLeft(2, '0');
      }
      _explanationTextController.text = data['explanationText'] ?? '';
      _hintTextController.text = data['hint'] ?? '';

      _isLoading = false;
    });
  }

  /// 年月テキストフィールドの入力内容から出題年月を更新する
  void _updateExamDateFromInput() {
    final yearText = _examYearController.text;
    final monthText = _examMonthController.text;
    if (yearText.isEmpty) {
      if (monthText.isNotEmpty) {
        setState(() {
          _selectedExamDate = null;
          _isExamDateError = true;
        });
      } else {
        setState(() {
          _selectedExamDate = null;
          _isExamDateError = false;
        });
      }
      return;
    }
    final year = int.tryParse(yearText);
    if (year == null || yearText.length != 4 || (year < 1900 || year > 2099)) {
      setState(() {
        _selectedExamDate = null;
        _isExamDateError = true;
      });
      return;
    }
    if (monthText.isEmpty) {
      setState(() {
        _selectedExamDate = DateTime(year, 1, 1);
        _isExamDateError = false;
      });
    } else {
      final month = int.tryParse(monthText);
      if (month == null || month < 1 || month > 12) {
        setState(() {
          _selectedExamDate = null;
          _isExamDateError = true;
        });
      } else {
        setState(() {
          _selectedExamDate = DateTime(year, month, 1);
          _isExamDateError = false;
        });
      }
    }
  }

  Future<void> _updateQuestion() async {
    // 入力内容から最新の出題年月を反映
    _updateExamDateFromInput();
    if (!_isSaveEnabled || _isSaving || _isExamDateError) return;
    setState(() {
      _isSaving = true;
    });

    final questionData = {
      'questionText': _questionTextController.text.trim(),
      'questionType': _selectedQuestionType,
      'explanationText': _explanationTextController.text.trim(),
      'hintText': _hintTextController.text.trim(),
      'examDate': _selectedExamDate != null ? Timestamp.fromDate(_selectedExamDate!) : null,
      'updatedByRef': FirebaseFirestore.instance.collection('users').doc('currentUserId'),
      'updatedAt': FieldValue.serverTimestamp(),
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
      await widget.question.reference.update(questionData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が更新されました')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error updating question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の更新に失敗しました')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteQuestion() async {
    final deletionData = {
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedByRef': FirebaseFirestore.instance.collection('users').doc('currentUserId'),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await widget.question.reference.update(deletionData);

      final questionSetRef = widget.question['questionSetRef'] as DocumentReference;
      final folderRef = await _getFolderRef(questionSetRef); // フォルダ参照の取得
      await updateQuestionCounts(folderRef, questionSetRef); // 共通メソッドを使用

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が削除されました')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print('Error deleting question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の削除に失敗しました')),
      );
    }
  }

  Future<DocumentReference> _getFolderRef(DocumentReference questionSetRef) async {
    final questionSetDoc = await questionSetRef.get();
    return questionSetDoc['folderRef'] as DocumentReference;
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
    _explanationTextFocusNode.dispose();
    _hintTextFocusNode.dispose();
    _examYearFocusNode.dispose();
    _examMonthFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('問題編集'),
        actions: [
          TextButton(
            onPressed: canSave ? _updateQuestion : null,
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
              onPressed: canSave ? _updateQuestion : null,
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
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // 角丸の大きさを調整
                        ),
                        backgroundColor: Colors.white,
                        title: const Text('本当に削除しますか？',
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18))
                        ,
                        content: const Text('削除した問題を復元することはできません。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('戻る', style: TextStyle(color: Colors.black87)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      _deleteQuestion();
                    }
                  },
                  child: const Text(
                    '問題を削除',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.red,),
                  ),
                ),
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
            color: AppColors.gray50,
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
            color: AppColors.gray50,
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
              decoration: const InputDecoration(
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
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'mm',
                border: InputBorder.none,
              ),
              onEditingComplete: () {
                _updateExamDateFromInput();
              },
            ),
          ),
        ],
      ),
    );
  }
}
