import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/services/question_count_update.dart';
import '../services/memory_level_sync.dart';
import '../widgets/add_page_widgets/question_type_selector.dart';
import '../widgets/add_page_widgets/question_widgets.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';

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
  // ────────────────────────────────
  // テキストコントローラ
  // ────────────────────────────────
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _correctChoiceTextController = TextEditingController();
  final TextEditingController _incorrectChoice1TextController = TextEditingController();
  final TextEditingController _incorrectChoice2TextController = TextEditingController();
  final TextEditingController _incorrectChoice3TextController = TextEditingController();
  final TextEditingController _explanationTextController = TextEditingController();
  final TextEditingController _hintTextController = TextEditingController();
  final TextEditingController _examYearController = TextEditingController();
  final TextEditingController _examMonthController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  // ────────────────────────────────
  // フォーカスノード
  // ────────────────────────────────
  final FocusNode _questionTextFocusNode = FocusNode();
  final FocusNode _correctChoiceTextFocusNode = FocusNode();
  final FocusNode _incorrectChoice1TextFocusNode = FocusNode();
  final FocusNode _incorrectChoice2TextFocusNode = FocusNode();
  final FocusNode _incorrectChoice3TextFocusNode = FocusNode();
  final FocusNode _explanationTextFocusNode = FocusNode();
  final FocusNode _hintTextFocusNode = FocusNode();
  final FocusNode _examYearFocusNode = FocusNode();
  final FocusNode _examMonthFocusNode = FocusNode();

  // 現在フォーカスされているコントローラを追跡
  TextEditingController? _currentFocusedController;

  // フォーカスノード → コントローラのマップ
  final Map<FocusNode, TextEditingController> _focusToControllerMap = {};

  // ────────────────────────────────
  // 状態
  // ────────────────────────────────
  String _selectedQuestionType = 'true_false';
  bool _trueFalseAnswer = true;
  bool _isSaving = false;
  bool _isSaveEnabled = false;
  bool _isExamDateError = false;
  bool _isLoading = true;
  DateTime? _selectedExamDate;

  List<String> _questionTags = [];
  List<String> _aggregatedTags = [];

  // 画面上（未アップロード）のローカル画像
  final Map<TextEditingController, List<Uint8List>> _localImagesMap = {};

  // 既に Firestore に保存されている画像URL
  final Map<String, List<String>> uploadedImageUrls = {
    'questionImageUrls': [],
    'explanationImageUrls': [],
    'hintImageUrls': [],
    'correctChoiceImageUrls': [],
  };

  @override
  void initState() {
    super.initState();
    _questionTextController.addListener(_onQuestionTextChanged);
    _loadQuestionData();
    _loadAggregatedTags();

    _focusToControllerMap.addAll({
      _questionTextFocusNode: _questionTextController,
      _correctChoiceTextFocusNode: _correctChoiceTextController,
      _explanationTextFocusNode: _explanationTextController,
      _hintTextFocusNode: _hintTextController,
    });

    for (final entry in _focusToControllerMap.entries) {
      entry.key.addListener(() {
        if (entry.key.hasFocus) {
          if (_currentFocusedController != entry.value) {
            setState(() => _currentFocusedController = entry.value);
          }
        } else {
          if (_currentFocusedController == entry.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _currentFocusedController = null);
            });
          }
        }
      });
    }
  }

  // ────────────────────────────────
  // データ読み込み
  // ────────────────────────────────
  void _loadQuestionData() {
    final data = (widget.question.data() as Map<String, dynamic>? ?? {});
    setState(() {
      _questionTextController.text = data['questionText'] ?? '';
      _selectedQuestionType = data['questionType'] ?? 'true_false';

      if (_selectedQuestionType == 'true_false') {
        _trueFalseAnswer = data['correctChoiceText'] == '正しい';
      } else if (_selectedQuestionType == 'single_choice') {
        _correctChoiceTextController.text = data['correctChoiceText'] ?? '';
        _incorrectChoice1TextController.text = data['incorrectChoice1Text'] ?? '';
        _incorrectChoice2TextController.text = data['incorrectChoice2Text'] ?? '';
        _incorrectChoice3TextController.text = data['incorrectChoice3Text'] ?? '';
      } else if (_selectedQuestionType == 'flash_card') {
        _correctChoiceTextController.text = data['correctChoiceText'] ?? '';
        uploadedImageUrls['correctChoiceImageUrls'] =
        List<String>.from(data['correctChoiceImageUrls'] ?? const []);
      }

      if (data['examDate'] != null) {
        final ts = data['examDate'] as Timestamp;
        _selectedExamDate = ts.toDate();
        _examYearController.text = _selectedExamDate!.year.toString();
        _examMonthController.text = _selectedExamDate!.month.toString().padLeft(2, '0');
      }

      _explanationTextController.text = data['explanationText'] ?? '';
      _hintTextController.text = data['hintText'] ?? '';

      uploadedImageUrls['questionImageUrls'] =
      List<String>.from(data['questionImageUrls'] ?? const []);
      uploadedImageUrls['explanationImageUrls'] =
      List<String>.from(data['explanationImageUrls'] ?? const []);
      uploadedImageUrls['hintImageUrls'] =
      List<String>.from(data['hintImageUrls'] ?? const []);

      _questionTags = List<String>.from(data['questionTags'] ?? const []);
      _isLoading = false;
    });
  }

  Future<void> _loadAggregatedTags() async {
    try {
      final qData = (widget.question.data() as Map<String, dynamic>? ?? {});
      final questionSetRef = _getQuestionSetRefSafe(qData);
      final folderRef = await _getFolderRefSafe(questionSetRef);
      final folderDoc = await folderRef.get();
      final folderData = folderDoc.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _aggregatedTags =
        List<String>.from(folderData['aggregatedQuestionTags'] ?? const []);
      });
    } catch (e) {
      debugPrint('loadAggregatedTags error: $e');
    }
  }

  // ────────────────────────────────
  // 入力変更
  // ────────────────────────────────
  void _onQuestionTextChanged() {
    setState(() {
      _isSaveEnabled = _questionTextController.text.trim().isNotEmpty;
    });
  }

  void _updateExamDateFromInput() {
    final yearText = _examYearController.text.trim();
    final monthText = _examMonthController.text.trim();

    if (yearText.isEmpty) {
      setState(() {
        _selectedExamDate = null;
        _isExamDateError = monthText.isNotEmpty;
      });
      return;
    }

    final year = int.tryParse(yearText);
    if (year == null || yearText.length != 4 || year < 1900 || year > 2099) {
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
      return;
    }

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

  Future<void> _updateQuestion() async {
    _updateExamDateFromInput();
    if (!_isSaveEnabled || _isSaving || _isExamDateError) return;

    setState(() => _isSaving = true);
    _showLoadingDialog();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログインが必要です')),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final questionRef = widget.question.reference;

      // 新規に追加されたローカル画像をアップロード
      final imageMap = <String, List<Uint8List>>{
        'questionImageUrls': _localImagesMap[_questionTextController] ?? const [],
        'correctChoiceImageUrls': _localImagesMap[_correctChoiceTextController] ?? const [],
        'explanationImageUrls': _localImagesMap[_explanationTextController] ?? const [],
        'hintImageUrls': _localImagesMap[_hintTextController] ?? const [],
      };

      final Map<String, List<String>> newUploadedImageUrls = {};
      for (final entry in imageMap.entries) {
        newUploadedImageUrls[entry.key] =
        await _uploadImagesToStorage(questionRef.id, entry.key, entry.value);
      }

      final Map<String, dynamic> questionData = {
        'questionText': _questionTextController.text.trim(),
        'questionType': _selectedQuestionType,
        'explanationText': _explanationTextController.text.trim(),
        'hintText': _hintTextController.text.trim(),
        'examDate': _selectedExamDate != null ? Timestamp.fromDate(_selectedExamDate!) : null,

        // ルール用メタ
        'updatedById': uid,
        'updatedAt': FieldValue.serverTimestamp(),

        // 既存URLに今回アップロード分を結合
        'questionImageUrls': [
          ...uploadedImageUrls['questionImageUrls'] ?? const [],
          ...newUploadedImageUrls['questionImageUrls'] ?? const [],
        ],
        'explanationImageUrls': [
          ...uploadedImageUrls['explanationImageUrls'] ?? const [],
          ...newUploadedImageUrls['explanationImageUrls'] ?? const [],
        ],
        'hintImageUrls': [
          ...uploadedImageUrls['hintImageUrls'] ?? const [],
          ...newUploadedImageUrls['hintImageUrls'] ?? const [],
        ],
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
      } else if (_selectedQuestionType == 'flash_card') {
        questionData.addAll({
          'correctChoiceText': _correctChoiceTextController.text.trim(),
          'correctChoiceImageUrls': [
            ...uploadedImageUrls['correctChoiceImageUrls'] ?? const [],
            ...newUploadedImageUrls['correctChoiceImageUrls'] ?? const [],
          ],
        });
      }

      if (mounted) Navigator.pop(context);
      await questionRef.update(questionData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が更新されました')),
      );
      _localImagesMap.clear();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Firestore 更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題の更新に失敗しました')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteQuestion() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 一覧のダイアログと同一レイアウト
    final result = await DeleteConfirmationDialog.show(
      context,
      title: '問題を削除',
      description: '選択中の1 問が削除されます。\nこの操作は取り消しできません。',
      bulletPoints: const ['選択中の1 問'],
      confirmText: '削除',
      cancelText: 'キャンセル',
      confirmColor: Colors.redAccent,
    );
    if (result == null || !result.confirmed) return;

    try {
      final qData = (widget.question.data() as Map<String, dynamic>? ?? {});
      final questionRef = widget.question.reference;

      // 参照を安全に取得
      final questionSetRef = _getQuestionSetRefSafe(qData);
      final folderRef = await _getFolderRefSafe(questionSetRef);

      // 1) 質問ドキュメントを「削除済み」化（isDeleted を true に）
      await questionRef.update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedById': uid,
      });

      // 2) 記憶度の同期（questionSet / folder の両方から該当IDを除去）
      await removeMemoryLevelsOnQuestionDeleteForUser(
        userId: uid,
        folderId: folderRef.id,
        questionSetId: questionSetRef.id,
        questionIds: [questionRef.id],
      );

      // 3) 件数の再計算（問題集 → フォルダ）
      await questionCountsUpdate(folderRef.id, questionSetRef.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が削除されました')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error deleting question: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題の削除に失敗しました: $e')),
      );
    }
  }

  // ────────────────────────────────
  // 参照取得（安全に）: 古いデータで questionSetRef / folderRef が欠けている場合に対応
  // ────────────────────────────────
  DocumentReference _getQuestionSetRefSafe(Map<String, dynamic> qData) {
    final refField = qData['questionSetRef'];
    if (refField is DocumentReference) return refField;

    final String? id = qData['questionSetId'] as String?;
    if (id != null && id.isNotEmpty) {
      return FirebaseFirestore.instance.collection('questionSets').doc(id);
    }
    throw StateError('question ${widget.question.id} に questionSetRef / questionSetId がありません');
  }

  Future<DocumentReference> _getFolderRefSafe(DocumentReference questionSetRef) async {
    final snap = await questionSetRef.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};

    final folderRefField = data['folderRef'];
    if (folderRefField is DocumentReference) return folderRefField;

    final String? folderId = data['folderId'] as String?;
    if (folderId != null && folderId.isNotEmpty) {
      return FirebaseFirestore.instance.collection('folders').doc(folderId);
    }
    throw StateError('questionSet ${snap.id} に folderRef / folderId がありません');
  }

  // ────────────────────────────────
  // 画像操作
  // ────────────────────────────────
  void _deleteUploadedImage(String field, String url) {
    setState(() {
      uploadedImageUrls[field]?.remove(url);
    });
  }

  TextEditingController? _getFocusedController() {
    final focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode != null && _focusToControllerMap.containsKey(focusedNode)) {
      return _focusToControllerMap[focusedNode];
    }
    return null;
  }

  Future<void> _insertImage() async {
    final targetController = _currentFocusedController ?? _getFocusedController();

    if (targetController == _incorrectChoice1TextController ||
        targetController == _incorrectChoice2TextController ||
        targetController == _incorrectChoice3TextController) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('誤答には画像を挿入できません')),
      );
      return;
    }

    if (_selectedQuestionType != 'flash_card' &&
        targetController == _correctChoiceTextController) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正答の画像はフラッシュカードでのみ追加可能です')),
      );
      return;
    }

    if (targetController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像を挿入するテキストフィールドを選択してください')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final existingImages = _localImagesMap[targetController] ?? <Uint8List>[];
    if (existingImages.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1つのフィールドには最大2枚まで画像を追加できます')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final imageData = result.files.first.bytes;
      if (imageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像の読み込みに失敗しました')),
        );
        return;
      }

      setState(() {
        _localImagesMap.putIfAbsent(targetController, () => <Uint8List>[]).add(imageData);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint("❌ 画像選択エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の選択に失敗しました')),
      );
    }
  }

  void _removeImage(TextEditingController controller, Uint8List image) {
    setState(() {
      _localImagesMap[controller]?.remove(image);
      if ((_localImagesMap[controller]?.isEmpty ?? false)) {
        _localImagesMap.remove(controller);
      }
    });
  }

  Future<List<String>> _uploadImagesToStorage(
      String questionId,
      String field,
      List<Uint8List> images,
      ) async {
    if (images.isEmpty) return const [];
    final List<String> uploadedUrls = [];
    final storageRef = FirebaseStorage.instance.ref().child('question_images');

    for (int i = 0; i < images.length; i++) {
      try {
        final decoded = img.decodeImage(images[i]);
        if (decoded == null) {
          debugPrint("❌ 画像のデコードに失敗しました");
          continue;
        }
        final compressed = Uint8List.fromList(img.encodeJpg(decoded, quality: 40));
        final fileName = '$questionId-$field-$i.jpg';
        final imageRef = storageRef.child(fileName);
        final snapshot = await imageRef.putData(compressed).whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(url);
      } catch (e) {
        debugPrint("画像アップロード失敗: $e");
      }
    }
    return uploadedUrls;
  }

  // ────────────────────────────────
  // タグ
  // ────────────────────────────────
  Future<void> _addTag(String tag) async {
    tag = tag.trim();
    if (tag.isEmpty || _questionTags.contains(tag)) return;

    setState(() => _questionTags.add(tag));

    try {
      await widget.question.reference.update({
        'questionTags': FieldValue.arrayUnion([tag]),
      });

      // フォルダ側の集計タグも更新
      final qData = (widget.question.data() as Map<String, dynamic>? ?? {});
      final questionSetRef = _getQuestionSetRefSafe(qData);
      final folderRef = await _getFolderRefSafe(questionSetRef);

      await folderRef.update({
        'aggregatedQuestionTags': FieldValue.arrayUnion([tag]),
      });
    } catch (e) {
      debugPrint('❌ タグ追加エラー: $e');
      setState(() => _questionTags.remove(tag));
    }
  }

  Future<void> _removeTag(String tag) async {
    setState(() => _questionTags.remove(tag));

    try {
      await widget.question.reference.update({
        'questionTags': FieldValue.arrayRemove([tag]),
      });
    } catch (e) {
      debugPrint('❌ タグ削除エラー: $e');
      setState(() => _questionTags.add(tag));
    }
  }

  // ────────────────────────────────
  // ローディングダイアログ
  // ────────────────────────────────
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue500),
              ),
              SizedBox(height: 16),
              Text("保存中...", style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────
  // Widget
  // ────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final canSave = _isSaveEnabled && !_isSaving && !_isExamDateError;
    final isAnyTextFieldFocused =
        _questionTextFocusNode.hasFocus ||
            _correctChoiceTextFocusNode.hasFocus ||
            _incorrectChoice1TextFocusNode.hasFocus ||
            _incorrectChoice2TextFocusNode.hasFocus ||
            _incorrectChoice3TextFocusNode.hasFocus ||
            _examYearFocusNode.hasFocus ||
            _examMonthFocusNode.hasFocus ||
            _explanationTextFocusNode.hasFocus ||
            _hintTextFocusNode.hasFocus;
    final showBottomSaveButton = isKeyboardOpen && isAnyTextFieldFocused && _isSaveEnabled;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('問題編集'),
        actions: [
          TextButton(
            onPressed: canSave ? _updateQuestion : null,
            child: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text(
                '保存',
                style: TextStyle(
                  color: AppColors.blue500,
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
        padding: const EdgeInsets.only(bottom: 0.0, right: 16.0, left: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(
                Icons.photo_size_select_actual_outlined,
                color: AppColors.blue500,
                size: 32,
              ),
              onPressed: _insertImage,
            ),
            const SizedBox(width: 16),
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
              // 形式セレクタ
              QuestionTypeSelector(
                selectedType: _selectedQuestionType,
                onTypeChanged: (t) => setState(() => _selectedQuestionType = t),
              ),
              const SizedBox(height: 16),

              // 問題文
              ExpandableTextField(
                controller: _questionTextController,
                focusNode: _questionTextFocusNode,
                labelText: '問題文',
                textFieldHeight: 80,
                focusedHintText: '例）日本の首都は東京である。',
                imageUrls: uploadedImageUrls['questionImageUrls'] ?? const [],
                localImageBytes: _localImagesMap[_questionTextController] ?? const [],
                onRemoveLocalImage: (imgData) => _removeImage(_questionTextController, imgData),
                onDeleteUploadedImage: (url) => _deleteUploadedImage('questionImageUrls', url),
              ),
              const SizedBox(height: 16),

              // true/false
              if (_selectedQuestionType == 'true_false')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrueFalseTile(
                      label: '正しい',
                      value: true,
                      groupValue: _trueFalseAnswer,
                      onTap: () => setState(() => _trueFalseAnswer = true),
                    ),
                    const SizedBox(height: 8),
                    TrueFalseTile(
                      label: '間違い',
                      value: false,
                      groupValue: _trueFalseAnswer,
                      onTap: () => setState(() => _trueFalseAnswer = false),
                    ),
                  ],
                ),

              // flash card
              if (_selectedQuestionType == 'flash_card') ...[
                ExpandableTextField(
                  controller: _correctChoiceTextController,
                  focusNode: _correctChoiceTextFocusNode,
                  labelText: '正解の選択肢',
                  textFieldHeight: 18,
                  focusedHintText: '例）東京である。',
                  imageUrls: uploadedImageUrls['correctChoiceImageUrls'] ?? const [],
                  localImageBytes: _localImagesMap[_correctChoiceTextController] ?? const [],
                  onRemoveLocalImage: (imgData) =>
                      _removeImage(_correctChoiceTextController, imgData),
                  onDeleteUploadedImage: (url) =>
                      _deleteUploadedImage('correctChoiceImageUrls', url),
                ),
              ],

              // 単一選択
              if (_selectedQuestionType == 'single_choice') ...[
                ExpandableTextField(
                  controller: _correctChoiceTextController,
                  focusNode: _correctChoiceTextFocusNode,
                  labelText: '正解の選択肢',
                  textFieldHeight: 18,
                  focusedHintText: '例）東京である。',
                  imageUrls: uploadedImageUrls['correctChoiceImageUrls'] ?? const [],
                  localImageBytes: _localImagesMap[_correctChoiceTextController] ?? const [],
                  onRemoveLocalImage: (imgData) =>
                      _removeImage(_correctChoiceTextController, imgData),
                  onDeleteUploadedImage: (url) =>
                      _deleteUploadedImage('correctChoiceImageUrls', url),
                ),
                const SizedBox(height: 16),
                ExpandableTextField(
                  controller: _incorrectChoice1TextController,
                  focusNode: _incorrectChoice1TextFocusNode,
                  labelText: '誤答1',
                  textFieldHeight: 18,
                  focusedHintText: '例）大阪である。',
                ),
                const SizedBox(height: 16),
                ExpandableTextField(
                  controller: _incorrectChoice2TextController,
                  focusNode: _incorrectChoice2TextFocusNode,
                  labelText: '誤答2',
                  textFieldHeight: 16,
                  focusedHintText: '例）京都である。',
                ),
                const SizedBox(height: 16),
                ExpandableTextField(
                  controller: _incorrectChoice3TextController,
                  focusNode: _incorrectChoice3TextFocusNode,
                  labelText: '誤答3',
                  textFieldHeight: 18,
                  focusedHintText: '例）名古屋である。',
                ),
              ],
              const SizedBox(height: 16),

              // 解説
              ExpandableTextField(
                controller: _explanationTextController,
                focusNode: _explanationTextFocusNode,
                labelText: '解説',
                textFieldHeight: 24,
                focusedHintText: '例）東京は、1869年（明治2年）に首都となりました',
                imageUrls: uploadedImageUrls['explanationImageUrls'] ?? const [],
                localImageBytes: _localImagesMap[_explanationTextController] ?? const [],
                onRemoveLocalImage: (imgData) =>
                    _removeImage(_explanationTextController, imgData),
                onDeleteUploadedImage: (url) =>
                    _deleteUploadedImage('explanationImageUrls', url),
              ),
              const SizedBox(height: 16),

              // ヒント
              ExpandableTextField(
                controller: _hintTextController,
                focusNode: _hintTextFocusNode,
                labelText: 'ヒント',
                textFieldHeight: 24,
                focusedHintText: '関東地方にある都道府県です。',
                imageUrls: uploadedImageUrls['hintImageUrls'] ?? const [],
                localImageBytes: _localImagesMap[_hintTextController] ?? const [],
                onRemoveLocalImage: (imgData) => _removeImage(_hintTextController, imgData),
                onDeleteUploadedImage: (url) => _deleteUploadedImage('hintImageUrls', url),
              ),
              const SizedBox(height: 16),

              // タグ
              QuestionTagsInput(
                tags: _questionTags,
                tagController: _tagController,
                aggregatedTags: _aggregatedTags,
                onTagAdded: _addTag,
                onTagDeleted: _removeTag,
              ),
              const SizedBox(height: 16),

              // 試験年月
              ExamDateField(
                examYearController: _examYearController,
                examMonthController: _examMonthController,
                examYearFocusNode: _examYearFocusNode,
                examMonthFocusNode: _examMonthFocusNode,
                isExamDateError: _isExamDateError,
                onExamDateChanged: _updateExamDateFromInput,
              ),
              const SizedBox(height: 32),

              // 削除ボタン（ダイアログは一覧と統一）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                  ),
                  onPressed: _deleteQuestion,
                  child: const Text(
                    '問題を削除',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                    ),
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

  // ────────────────────────────────
  // 破棄
  // ────────────────────────────────
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
    _tagController.dispose();

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
}
