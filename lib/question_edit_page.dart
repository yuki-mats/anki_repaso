import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/services/question_count.dart';
import 'package:image/image.dart' as img;
import 'package:repaso/widgets/question_widgets.dart';

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
  final TextEditingController _tagController = TextEditingController();

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

  // **現在フォーカスされているコントローラーを追跡**
  TextEditingController? _currentFocusedController;

  // フォーカスノードとコントローラーのマップ（※late final ではなく、空のマップで初期化）
  final Map<FocusNode, TextEditingController> _focusToControllerMap = {};

  String _selectedQuestionType = 'true_false';
  bool _trueFalseAnswer = true;
  bool _isSaving = false;
  bool _isSaveEnabled = false;
  bool _isExamDateError = false;
  bool _isLoading = true;
  DateTime? _selectedExamDate;
  bool _isUploading = false; // 画像アップロードの状態を管理
  List<String> _questionTags = [];
  List<String> _aggregatedTags = [];

  Map<TextEditingController, List<Uint8List>> _localImagesMap = {};

  Map<String, List<String>> uploadedImageUrls = {
    'questionImageUrls': [],
    'explanationImageUrls': [],
    'hintImageUrls': [],
  };

  @override
  void initState() {
    super.initState();
    _questionTextController.addListener(_onQuestionTextChanged);
    _loadQuestionData();
    _loadAggregatedTags();

    // _focusToControllerMap を空のマップで初期化後、エントリーを追加
    _focusToControllerMap.addAll({
      _questionTextFocusNode: _questionTextController,
      _correctChoiceTextFocusNode: _correctChoiceTextController,
      _explanationTextFocusNode: _explanationTextController,
      _hintTextFocusNode: _hintTextController,
    });

    // 各 FocusNode にリスナーを設定して、現在フォーカスされているコントローラーを追跡
    for (var entry in _focusToControllerMap.entries) {
      entry.key.addListener(() {
        if (entry.key.hasFocus) {
          if (_currentFocusedController != entry.value) {
            setState(() {
              _currentFocusedController = entry.value;
              print("🔹 フォーカスが変更されました: ${entry.value.text} (Controller HashCode: ${entry.value.hashCode})");
            });
          }
        } else {
          if (_currentFocusedController == entry.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                print("🔹 フォーカスが外れました: ${entry.value.text} (Controller HashCode: ${entry.value.hashCode})");
                _currentFocusedController = null;
              });
            });
          }
        }
      });
    }
  }

  Future<void> _loadAggregatedTags() async {
    final data = widget.question.data() as Map<String, dynamic>;
    if (data.containsKey('questionSetRef')) {
      final questionSetRef = data['questionSetRef'] as DocumentReference;
      final folderRef = await _getFolderRef(questionSetRef);
      final folderDoc = await folderRef.get();
      setState(() {
        _aggregatedTags = List<String>.from(
            ((folderDoc.data() as Map<String, dynamic>)['aggregatedQuestionTags'] ?? [])
        );
      });
    }
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
      } else if (_selectedQuestionType == 'flash_card') {
        // flash_card の場合
        _correctChoiceTextController.text = data['correctChoiceText'] ?? '';
        uploadedImageUrls['correctChoiceImageUrls'] =
        List<String>.from(data['correctChoiceImageUrls'] ?? []);
      }

      // 出題年月（examDate）の読み込み
      if (data['examDate'] != null) {
        final Timestamp ts = data['examDate'] as Timestamp;
        _selectedExamDate = ts.toDate();
        _examYearController.text = _selectedExamDate!.year.toString();
        _examMonthController.text = _selectedExamDate!.month.toString().padLeft(2, '0');
      }
      _explanationTextController.text = data['explanationText'] ?? '';
      _hintTextController.text = data['hintText'] ?? '';

      // Firestore に保存済みの画像 URL を読み込む
      uploadedImageUrls['questionImageUrls'] =
      List<String>.from(data['questionImageUrls'] ?? []);
      uploadedImageUrls['explanationImageUrls'] =
      List<String>.from(data['explanationImageUrls'] ?? []);
      uploadedImageUrls['hintImageUrls'] =
      List<String>.from(data['hintImageUrls'] ?? []);
      // タグ情報の読み込み
      _questionTags = data['questionTags'] != null
          ? List<String>.from(data['questionTags'])
          : [];
      _isLoading = false;
    });
  }

  /// 年月テキストフィールドの入力内容から出題年月を更新する
  void _updateExamDateFromInput() {
    final yearText = _examYearController.text;
    final monthText = _examMonthController.text;
    if (yearText.isEmpty) {
      setState(() {
        _selectedExamDate = null;
        _isExamDateError = monthText.isNotEmpty;
      });
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
    _updateExamDateFromInput();
    if (!_isSaveEnabled || _isSaving || _isExamDateError) return;

    setState(() {
      _isSaving = true;
    });

    _showLoadingDialog(); // 🔹 ローディングダイアログを表示

    try {
      final questionRef = widget.question.reference;


      // 画像アップロード処理
      Map<String, List<Uint8List>> imageMap = {
        'questionImageUrls': _localImagesMap[_questionTextController] ?? [],
        'correctChoiceImageUrls': _localImagesMap[_correctChoiceTextController] ?? [],
        'explanationImageUrls': _localImagesMap[_explanationTextController] ?? [],
        'hintImageUrls': _localImagesMap[_hintTextController] ?? [],
      };

      Map<String, List<String>> newUploadedImageUrls = {};
      for (var entry in imageMap.entries) {
        newUploadedImageUrls[entry.key] =
        await _uploadImagesToStorage(questionRef.id, entry.key, entry.value);
      }

      final questionData = {
        'questionText': _questionTextController.text.trim(),
        'questionType': _selectedQuestionType,
        'explanationText': _explanationTextController.text.trim(),
        'hintText': _hintTextController.text.trim(),
        'examDate': _selectedExamDate != null ? Timestamp.fromDate(_selectedExamDate!) : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'questionImageUrls': [
          ...(uploadedImageUrls['questionImageUrls'] ?? []),
          ...newUploadedImageUrls['questionImageUrls']!
        ],
        'explanationImageUrls': [
          ...(uploadedImageUrls['explanationImageUrls'] ?? []),
          ...newUploadedImageUrls['explanationImageUrls']!
        ],
        'hintImageUrls': [
          ...(uploadedImageUrls['hintImageUrls'] ?? []),
          ...newUploadedImageUrls['hintImageUrls']!
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
            ...(uploadedImageUrls['correctChoiceImageUrls'] ?? []),
            ...newUploadedImageUrls['correctChoiceImageUrls']!
          ],
        });
      }
      Navigator.pop(context);

      await questionRef.update(questionData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が更新されました')),
      );

      _localImagesMap.clear();
      Navigator.pop(context);
    } catch (e) {
      print('❌ Firestore 更新エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の更新に失敗しました')),
      );
      Navigator.pop(context);
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
      final folderRef = await _getFolderRef(questionSetRef);
      await updateQuestionCounts(folderRef, questionSetRef);
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      await questionSetRef
          .collection('questionSetUserStats')
          .doc(currentUserId)
          .update({
        "memoryLevels.${widget.question.id}": FieldValue.delete()
      });
      await folderRef
          .collection('folderSetUserStats')
          .doc(currentUserId)
          .update({
        "memoryLevels.${widget.question.id}": FieldValue.delete()
      });
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

  void _deleteUploadedImage(String field, String url) {
    setState(() {
      uploadedImageUrls[field]?.remove(url);
    });
  }

  TextEditingController? _getFocusedController() {
    FocusNode? focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode != null && _focusToControllerMap.containsKey(focusedNode)) {
      return _focusToControllerMap[focusedNode];
    }
    return null;
  }

  void _insertImage() async {
    TextEditingController? targetController = _currentFocusedController ?? _getFocusedController();

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

    List<Uint8List> existingImages = _localImagesMap[targetController] ?? [];
    if (existingImages.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1つのフィールドには最大2枚まで画像を追加できます')),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      Uint8List? imageData = result.files.first.bytes;
      if (imageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像の読み込みに失敗しました')),
        );
        return;
      }

      setState(() {
        _localImagesMap.putIfAbsent(targetController, () => []).add(imageData);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    } catch (e) {
      print("❌ 画像選択エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の選択に失敗しました')),
      );
    }
  }

  void _removeImage(TextEditingController controller, Uint8List image) {
    setState(() {
      _localImagesMap[controller]?.remove(image);
      if (_localImagesMap[controller]?.isEmpty ?? false) {
        _localImagesMap.remove(controller);
      }
    });
  }

  Future<List<String>> _uploadImagesToStorage(String questionId, String field, List<Uint8List> images) async {
    if (images.isEmpty) return [];
    List<String> uploadedUrls = [];
    final storageRef = FirebaseStorage.instance.ref().child('question_images');
    for (int i = 0; i < images.length; i++) {
      try {
        img.Image? decodedImage = img.decodeImage(images[i]);
        if (decodedImage == null) {
          print("❌ 画像のデコードに失敗しました");
          continue;
        }
        Uint8List compressedImage = Uint8List.fromList(
            img.encodeJpg(decodedImage, quality: 40));
        String fileName = '$questionId-$field-$i.jpg';
        Reference imageRef = storageRef.child(fileName);
        UploadTask uploadTask = imageRef.putData(compressedImage);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      } catch (e) {
        print("画像アップロード失敗: $e");
      }
    }
    return uploadedUrls;
  }

  /// タグを追加する処理
  void _addTag(String tag) async {
    tag = tag.trim();
    if (tag.isEmpty || _questionTags.contains(tag)) return;

    setState(() {
      _questionTags.add(tag);
    });

    try {
      // 問題ドキュメントの questionTags を更新
      await widget.question.reference.update({
        'questionTags': FieldValue.arrayUnion([tag]),
      });

      // フォルダの aggregatedQuestionTags も更新
      final data = widget.question.data() as Map<String, dynamic>;
      final questionSetRef = data['questionSetRef'] as DocumentReference;
      final folderRef = await _getFolderRef(questionSetRef);
      await folderRef.update({
        'aggregatedQuestionTags': FieldValue.arrayUnion([tag]),
      });
    } catch (e) {
      print('❌ タグ追加エラー: $e');
      setState(() {
        _questionTags.remove(tag);
      });
    }
  }

  /// タグを削除する処理
  void _removeTag(String tag) async {
    setState(() {
      _questionTags.remove(tag);
    });

    try {
      await widget.question.reference.update({
        'questionTags': FieldValue.arrayRemove([tag]),
      });
    } catch (e) {
      print('❌ タグ削除エラー: $e');
      setState(() {
        _questionTags.add(tag);
      });
    }
  }


  /// **ローディングダイアログ**
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 🔹 ユーザーが閉じられないようにする
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue500),
                ),
                const SizedBox(height: 16),
                const Text("保存中...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChipWidget(
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
                    ChipWidget(
                      label: 'カード',
                      icon: Icons.filter_none_rounded,
                      isSelected: _selectedQuestionType == 'flash_card',
                      onTap: () {
                        setState(() {
                          _selectedQuestionType = 'flash_card';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChipWidget(
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
              ),
              const SizedBox(height: 16),
              ExpandableTextField(
                controller: _questionTextController,
                focusNode: _questionTextFocusNode,
                labelText: '問題文',
                textFieldHeight: 80,
                focusedHintText: '例）日本の首都は東京である。',
                imageUrls: uploadedImageUrls['questionImageUrls'] ?? [],
                localImageBytes: _localImagesMap[_questionTextController] ?? [],
                onRemoveLocalImage: (imgData) => _removeImage(_questionTextController, imgData),
                onDeleteUploadedImage: (url) => _deleteUploadedImage('questionImageUrls', url),
              ),
              const SizedBox(height: 16),
              if (_selectedQuestionType == 'true_false')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrueFalseTile(
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
                    TrueFalseTile(
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
              if (_selectedQuestionType == 'flash_card') ...[
                ExpandableTextField(
                  controller: _correctChoiceTextController,
                  focusNode: _correctChoiceTextFocusNode,
                  labelText: '正解の選択肢',
                  textFieldHeight: 18,
                  focusedHintText: '例）東京である。',
                  imageUrls: uploadedImageUrls['correctChoiceImageUrls'] ?? [],
                  localImageBytes: _localImagesMap[_correctChoiceTextController] ?? [],
                  onRemoveLocalImage: (imgData) => _removeImage(_correctChoiceTextController, imgData),
                  onDeleteUploadedImage: (url) => _deleteUploadedImage('correctChoiceImageUrls', url),
                ),
              ],
              if (_selectedQuestionType == 'single_choice') ...[
                ExpandableTextField(
                  controller: _correctChoiceTextController,
                  focusNode: _correctChoiceTextFocusNode,
                  labelText: '正解の選択肢',
                  textFieldHeight: 18,
                  focusedHintText: '例）東京である。',
                  imageUrls: uploadedImageUrls['correctChoiceImageUrls'] ?? [],
                  localImageBytes: _localImagesMap[_correctChoiceTextController] ?? [],
                  onRemoveLocalImage: (imgData) => _removeImage(_correctChoiceTextController, imgData),
                  onDeleteUploadedImage: (url) => _deleteUploadedImage('correctChoiceImageUrls', url),
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
              ExpandableTextField(
                controller: _explanationTextController,
                focusNode: _explanationTextFocusNode,
                labelText: '解説',
                textFieldHeight: 24,
                focusedHintText: '例）東京は、1869年（明治2年）に首都となりました',
                imageUrls: uploadedImageUrls['explanationImageUrls'] ?? [],
                localImageBytes: _localImagesMap[_explanationTextController] ?? [],
                onRemoveLocalImage: (imgData) => _removeImage(_explanationTextController, imgData),
                onDeleteUploadedImage: (url) => _deleteUploadedImage('explanationImageUrls', url),
              ),
              const SizedBox(height: 16),
              ExpandableTextField(
                controller: _hintTextController,
                focusNode: _hintTextFocusNode,
                labelText: 'ヒント',
                textFieldHeight: 24,
                focusedHintText: '関東地方にある都道府県です。',
                imageUrls: uploadedImageUrls['hintImageUrls'] ?? [],
                localImageBytes: _localImagesMap[_hintTextController] ?? [],
                onRemoveLocalImage: (imgData) => _removeImage(_hintTextController, imgData),
                onDeleteUploadedImage: (url) => _deleteUploadedImage('hintImageUrls', url),
              ),
              const SizedBox(height: 16),
              QuestionTagsInput(
                tags: _questionTags,
                tagController: _tagController,
                aggregatedTags: _aggregatedTags, // 追加
                onTagAdded: _addTag,
                onTagDeleted: _removeTag,
              ),
              const SizedBox(height: 16),
              ExamDateField(
                examYearController: _examYearController,
                examMonthController: _examMonthController,
                examYearFocusNode: _examYearFocusNode,
                examMonthFocusNode: _examMonthFocusNode,
                isExamDateError: _isExamDateError,
                onExamDateChanged: _updateExamDateFromInput, // ← コールバック
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text(
                    '問題を削除',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                        title: const Text(
                          '本当に削除しますか？',
                          style: TextStyle(color: Colors.black87, fontSize: 18),
                        ),
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
                ),
              ),
              const SizedBox(height: 300),
            ],
          ),
        ),
      ),
    );
  }
}
