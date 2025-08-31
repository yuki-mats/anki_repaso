import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repaso/services/import_questions.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/services/question_count_update.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:repaso/widgets/add_page_widgets/question_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/add_page_widgets/image_generation_tab.dart';
import '../widgets/add_page_widgets/question_count_selector.dart';
import '../widgets/add_page_widgets/question_type_selector.dart';

class QuestionAddPage extends StatefulWidget {
  final String folderId;
  final String questionSetId;

  const QuestionAddPage({
    Key? key,
    required this.folderId,
    required this.questionSetId,
  }) : super(key: key);

  @override
  _QuestionAddPageState createState() => _QuestionAddPageState();
}

class _QuestionAddPageState extends State<QuestionAddPage> with SingleTickerProviderStateMixin {
  String _appBarTitle = '問題作成';
  List<String> _questionTags = [];
  List<String> _aggregatedTags = [];
  int _generateCount = 1;

  // コントローラー
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _correctChoiceTextController =
  TextEditingController();
  final TextEditingController _incorrectChoice1TextController =
  TextEditingController();
  final TextEditingController _incorrectChoice2TextController =
  TextEditingController();
  final TextEditingController _incorrectChoice3TextController =
  TextEditingController();
  final TextEditingController _explanationTextController =
  TextEditingController();
  final TextEditingController _hintTextController = TextEditingController();
  final TextEditingController _examYearController = TextEditingController();
  final TextEditingController _examMonthController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  // フォーカスノード
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
  bool _isSaveEnabled = false;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  // ローカル画像を保持するマップ（各TextField毎に）
  Map<TextEditingController, List<Uint8List>> _localImagesMap = {};

  Map<String, List<String>> uploadedImageUrls = {
    'questionImageUrls': [],
    'explanationImageUrls': [],
    'hintImageUrls': [],
  };

  // **現在フォーカスされているコントローラーを追跡**
  TextEditingController? _currentFocusedController;

  /// 「最後にフォーカスされていた TextField のコントローラー」を保持する変数
  TextEditingController? _lastFocusedController;

  /// フォーカスノードとコントローラーの逆引きマップ
  late final Map<TextEditingController, FocusNode> _controllerToFocusNodeMap;

  // フォーカスノードとコントローラーのマップ
  late final Map<FocusNode, TextEditingController> _focusToControllerMap;

  // 出題年月の内部保持（年と月のみ。日付は自動的に1日固定）
  DateTime? _selectedExamDate;

  // 追加: 出題年月の入力エラー状態を保持するフラグ
  bool _isExamDateError = false;
  late final TabController _tabController;

  bool _isGenerating = false;

  String _labelForQuestionType(String type) {
    switch (type) {
      case 'true_false':
        return '正誤問題';
      case 'flash_card':
        return 'カード';
      case 'single_choice':
        return '四択問題';
      default:
        return '';
    }
  }// AI 画像→問題生成の実行フラグ

  @override
  void initState() {
    super.initState();
    _loadAggregatedTags();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        FocusScope.of(context).unfocus();
      }
    });

    _questionTextController.addListener(_onQuestionTextChanged);

    // フォーカスノードとコントローラーのマップ
    _focusToControllerMap = {
      _questionTextFocusNode: _questionTextController,
      _correctChoiceTextFocusNode: _correctChoiceTextController,
      _explanationTextFocusNode: _explanationTextController,
      _hintTextFocusNode: _hintTextController,
    };

    // 逆引きマップを生成
    _controllerToFocusNodeMap = _focusToControllerMap
        .map((focusNode, controller) => MapEntry(controller, focusNode));

    // フォーカスリスナー
    for (var entry in _focusToControllerMap.entries) {
      entry.key.addListener(() {
        if (entry.key.hasFocus) {
          _lastFocusedController = entry.value;
        }
      });
    }
  }

  @override
  void dispose() {
    _questionTextController.removeListener(_onQuestionTextChanged);

    for (var node in _focusToControllerMap.keys) {
      node.removeListener(() {});
    }

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
    _tagController.dispose();
    _tabController.dispose();

    super.dispose();
  }

  Uint8List _compressForGemini(Uint8List rawBytes,
      {required String mimeType}) {
    img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return rawBytes;
    }

    const int maxSide = 1024;
    if (decoded.width > maxSide || decoded.height > maxSide) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: maxSide);
      } else {
        decoded = img.copyResize(decoded, height: maxSide);
      }
    }

    if (mimeType == "image/png") {
      return Uint8List.fromList(img.encodePng(decoded, level: 6));
    } else {
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 50));
    }
  }

  String _guessMime(String path) =>
      path.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg";

  Future<void> _scanTextFromImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR を利用するにはログインが必要です')),
      );
      return;
    }

    final TextEditingController? target = _lastFocusedController;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まず貼り付け先のテキストフィールドをタップしてください')),
      );
      return;
    }

    // ───────── モーダル（角丸 + ハンドル + 統一デザイン）─────────
    final ImageSource? src = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft : Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 160,
            child: Column(
              children: [
                // ドラッグハンドル
                Center(
                  child: Container(
                    width : 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ─── ① カメラ ───
                ListTile(
                  leading: Container(
                    width : 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title : const Text('カメラで撮影', style: TextStyle(fontSize: 16)),
                  onTap : () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                // ─── ② ギャラリー ───
                ListTile(
                  leading: Container(
                    width : 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.photo_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title : const Text('ギャラリーから選択', style: TextStyle(fontSize: 16)),
                  onTap : () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (src == null) return;

    // 以降は元の処理そのまま --------------------------
    final XFile? picked = await _picker.pickImage(source: src);
    if (picked == null) return;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(lockAspectRatio: false),
        IOSUiSettings(),
      ],
    );
    if (cropped == null) return;

    final Uint8List rawBytes = await cropped.readAsBytes();
    final String mime = _guessMime(cropped.path);

    final Uint8List compressedBytes =
    _compressForGemini(rawBytes, mimeType: mime);
    debugPrint(
        "[DEBUG] raw size=${rawBytes.lengthInBytes} bytes, compressed size=${compressedBytes.lengthInBytes} bytes, mime=$mime");

    _showLoadingDialog();
    try {
      final res = await FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('extractTextFromImage')({
        'base64Image': base64Encode(compressedBytes),
        'mimeType': mime,
      });
      if (!mounted) return;
      Navigator.pop(context);

      final extracted = (res.data['text'] ?? '').toString().trim();
      if (extracted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字が検出できませんでした')),
        );
        return;
      }

      final int pos = target.selection.baseOffset;
      if (pos >= 0) {
        target.text = target.text.replaceRange(pos, pos, extracted);
        target.selection =
            TextSelection.collapsed(offset: pos + extracted.length);
      } else {
        target.text += extracted;
      }

      final focusNode = _controllerToFocusNodeMap[target];
      if (focusNode != null) {
        FocusScope.of(context).requestFocus(focusNode);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 失敗: ${e.code}')),
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR に失敗しました')),
      );
    }
  }

  // ───────── ボトムシートでタイプを選択 ─────────
  Future<String?> _showQuestionTypeModal() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildTypeTile('true_false', '正誤問題', Icons.check_circle_outline),
            _buildTypeTile('flash_card', 'カード', Icons.filter_none_rounded),
            _buildTypeTile('single_choice', '四択問題', Icons.list_alt),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

// １行分のタイル
  Widget _buildTypeTile(String value, String label, IconData icon) {
    final isSelected = value == _selectedQuestionType;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppColors.blue500 : AppColors.gray600),
      title: Text(label,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.blue500)
          : null,
      onTap: () => Navigator.pop(context, value),
    );
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
    _questionTags.clear();
    _tagController.clear();
    _selectedExamDate = null;
    _isExamDateError = false;

    setState(() {
      _trueFalseAnswer = true;
      _isSaveEnabled = false;
      _localImagesMap.clear();
    });

    FocusScope.of(context).requestFocus(_questionTextFocusNode);
  }

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
    if (year == null ||
        yearText.length != 4 ||
        (year < 1900 || year > 2099)) {
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

  TextEditingController? _getFocusedController() {
    FocusNode? focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode != null && _focusToControllerMap.containsKey(focusedNode)) {
      return _focusToControllerMap[focusedNode];
    }
    return null;
  }

  void _insertImage() async {
    // ① 画像を挿入する対象フィールドを特定
    TextEditingController? targetController =
        _currentFocusedController ?? _getFocusedController();

    // 誤答フィールドには追加できないガード
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

    // ② キーボードを閉じる
    FocusScope.of(context).unfocus();

    // 1フィールド最大2枚まで
    final existingImages = _localImagesMap[targetController] ?? [];
    if (existingImages.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1つのフィールドには最大2枚まで画像を追加できます')),
      );
      return;
    }

    // ───────── ③ showModalBottomSheet を _scanTextFromImage と同じ見た目に ─────────
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ドラッグハンドル ──
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── ① カメラで撮影 ──
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gray100,
                radius: 20,
                child: const Icon(Icons.camera_alt_outlined, size: 22, color: AppColors.gray600),
              ),
              title: const Text('カメラで撮影', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            // ── ② ギャラリーから選択 ──
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gray100,
                radius: 20,
                child: const Icon(Icons.photo_outlined, size: 22, color: AppColors.gray600),
              ),
              title: const Text('ギャラリーから選択', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const SizedBox(height: 16), // 下に少し余白を入れる
          ],
        );
      },
    );
    if (choice == null) return;

    Uint8List? imageData;
    try {
      // ④ 選択肢に応じて画像取得
      if (choice == 'camera' || choice == 'gallery') {
        final src = (choice == 'camera') ? ImageSource.camera : ImageSource.gallery;
        final XFile? picked = await _picker.pickImage(source: src);
        if (picked == null) return;
        imageData = await picked.readAsBytes();
      } else if (choice == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        imageData = result.files.first.bytes;
      }

      if (imageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像の読み込みに失敗しました')),
        );
        return;
      }

      // ⑤ 画像をローカルマップに追加して UI 更新
      setState(() {
        _localImagesMap.putIfAbsent(targetController, () => []).add(imageData!);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } catch (e) {
      print('❌ 画像選択エラー: $e');
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

  void _addTag(String tag) {
    if (!_questionTags.contains(tag)) {
      setState(() {
        _questionTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _questionTags.remove(tag);
    });
  }

  Future<void> _loadAggregatedTags() async {
    final folderDoc = await FirebaseFirestore.instance
        .collection('folders')
        .doc(widget.folderId)
        .get();
    setState(() {
      _aggregatedTags = List<String>.from(
          ((folderDoc.data() as Map<String, dynamic>)['aggregatedQuestionTags'] ??
              []));
    });
  }

  Future<List<String>> _uploadImagesToStorage(
      String questionId, String field, List<Uint8List> images) async {
    if (images.isEmpty) return [];

    final List<String> uploadedUrls = [];
    final storageRef = FirebaseStorage.instance.ref().child('question_images');

    const int jpegQuality = 40;

    for (int i = 0; i < images.length; i++) {
      try {
        img.Image? decoded = img.decodeImage(images[i]);
        if (decoded == null) {
          print('❌ 画像デコード失敗');
          continue;
        }

        final Uint8List compressed =
        Uint8List.fromList(img.encodeJpg(decoded, quality: jpegQuality));

        final String fileName = '$questionId-$field-$i.jpg';
        final Reference ref = storageRef.child(fileName);

        final TaskSnapshot snap = await ref.putData(
          compressed,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final String url = await snap.ref.getDownloadURL();
        uploadedUrls.add(url);

        print('✅ 画像アップロード成功: $url');
      } catch (e) {
        print('❌ 画像アップロード失敗: $e');
      }
    }

    return uploadedUrls;
  }

  Future<void> _addQuestion() async {
    _updateExamDateFromInput();
    if (!_isSaveEnabled || _isSaving || _isExamDateError) return;

    setState(() {
      _isSaving = true;
    });

    _showLoadingDialog();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。問題を保存するにはログインしてください。')),
      );
      Navigator.pop(context);
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final questionDocRef =
    FirebaseFirestore.instance.collection('questions').doc();

    Map<String, List<Uint8List>> imageMap = {
      'questionImageUrls': _localImagesMap[_questionTextController] ?? [],
      'correctChoiceImageUrls': _localImagesMap[_correctChoiceTextController] ??
          [],
      'explanationImageUrls': _localImagesMap[_explanationTextController] ?? [],
      'hintImageUrls': _localImagesMap[_hintTextController] ?? [],
    };

    Map<String, List<String>> uploadedImageUrls = {};
    for (var entry in imageMap.entries) {
      uploadedImageUrls[entry.key] = await _uploadImagesToStorage(
          questionDocRef.id, entry.key, entry.value);
    }

    final questionData = {
      'questionSetId': widget.questionSetId,
      'questionText': _questionTextController.text.trim(),
      'questionType': _selectedQuestionType,
      'examDate': _selectedExamDate != null ? Timestamp.fromDate(_selectedExamDate!) : null,
      'createdById': user.uid,
      'updatedById': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'explanationText': _explanationTextController.text.trim(),
      'hintText': _hintTextController.text.trim(),
      'questionImageUrls': uploadedImageUrls['questionImageUrls'],
      'explanationImageUrls': uploadedImageUrls['explanationImageUrls'],
      'hintImageUrls': uploadedImageUrls['hintImageUrls'],
      'isOfficial': false,
      'isDeleted': false,
      'isFlagged': false,
      'questionTags': _questionTags,
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
        'correctChoiceImageUrls': uploadedImageUrls['correctChoiceImageUrls'],
      });
    }

    try {
      await questionDocRef.set(questionData);
      if (_questionTags.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('folders')
            .doc(widget.folderId)
            .update({
          'aggregatedQuestionTags': FieldValue.arrayUnion(_questionTags),
        });
      }
      await questionCountsUpdate(widget.folderId, widget.questionSetId);

      _clearFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が保存されました')),
      );
    } catch (e) {
      print('❌ Firestore保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の保存に失敗しました')),
      );
    } finally {
      Navigator.pop(context);
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue500),
                ),
                SizedBox(height: 16),
                Text("保存中...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateQuestionFromImage(
      Uint8List rawBytes, {
        required String mimeType,
      }) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    // デバッグ用に questionType を出力
    debugPrint('📝 _generateQuestionFromImage: questionType=$_selectedQuestionType, count=$_generateCount');

    final Uint8List compressed = _compressForGemini(rawBytes, mimeType: mimeType);

    _showLoadingDialog();
    try {
      final res = await FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('generateQuestionFromImage')({
        'base64Image'   : base64Encode(compressed),
        'mimeType'      : mimeType,
        'questionSetId' : widget.questionSetId,
        'folderId'      : widget.folderId,
        'questionType'  : _selectedQuestionType,
        'generateCount' : _generateCount,
      });

      // Cloud Functions 側で返却する配列を受け取る
      final List<dynamic> ids = (res.data['questionIds'] as List<dynamic>?) ?? [];

      if (ids.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length} 問を追加しました')),
        );
      } else {
        throw Exception('questionIds が取得できませんでした');
      }
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失敗: ${e.code}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題生成に失敗しました: $e')),
      );
    } finally {
      if (mounted) Navigator.pop(context); // ローディングダイアログを閉じる
      setState(() => _isGenerating = false);
    }
  }




  void _showImportModal(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_file, size: 48, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                '問題文、答え、選択肢、解説、ヒント等を含んだ\nXLSXをインポートできます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  const url =
                      'https://docs.google.com/spreadsheets/d/1615CKsezB_8KvybWLqlxhtAXkm1hFn-d-9oD9M_PbTY/edit?usp=sharing';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URLを開けませんでした')),
                    );
                  }
                },
                child: const Text(
                  'XLSXサンプル',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  ImportQuestionsService service = ImportQuestionsService();
                  await service.pickFileAndImport(
                      context, widget.folderId, widget.questionSetId);
                },
                child: const Text('ファイルを選択'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                const Text('キャンセル', style: TextStyle(color: Colors.black87)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen =
        MediaQuery.of(context).viewInsets.bottom > 0;
    final bool canSave = _isSaveEnabled && !_isSaving && !_isExamDateError;

    final bool isAnyTextFieldFocused = _questionTextFocusNode.hasFocus ||
        _correctChoiceTextFocusNode.hasFocus ||
        _incorrectChoice1TextFocusNode.hasFocus ||
        _incorrectChoice2TextFocusNode.hasFocus ||
        _incorrectChoice3TextFocusNode.hasFocus ||
        _examYearFocusNode.hasFocus ||
        _examMonthFocusNode.hasFocus ||
        _explanationTextFocusNode.hasFocus ||
        _hintTextFocusNode.hasFocus;

    final bool showBottomSaveButton = isKeyboardOpen && isAnyTextFieldFocused;

    return DefaultTabController(
      length: 2,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: Text(_appBarTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.1),
                ),
              ),
              height: 32,
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 36),
                indicatorWeight: 2.5,
                indicatorColor: AppColors.blue500,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                onTap: (_) => FocusScope.of(context).unfocus(),
                tabs: const [
                  Tab(text: '入力して作成'),
                  Tab(text: '画像から生成'),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.upload_file_rounded,
                    color: Colors.black54,
                    size: 24,
                  ),
                  onPressed: () => _showImportModal(context),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ],
        ),
        bottomSheet: showBottomSaveButton
            ? Container(
          color: AppColors.gray50,
          padding: const EdgeInsets.only(
              bottom: 0.0, right: 16.0, left: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.photo_size_select_actual_outlined,
                      color: AppColors.blue500,
                      size: 32,
                    ),
                    onPressed: _insertImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.document_scanner_outlined,
                        color: AppColors.blue500, size: 32),
                    onPressed: _scanTextFromImage,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  canSave ? AppColors.blue500 : Colors.grey,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
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
        body: TabBarView(
          controller: _tabController,
          children: [
            GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {});
              },
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12,),
                    // ───── 質問形式セレクタ ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: QuestionTypeSelector(
                        selectedType: _selectedQuestionType,
                        onTypeChanged: (t) => setState(() => _selectedQuestionType = t),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ───── 下のまとまり（Padding で囲む） ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExpandableTextField(
                            controller: _questionTextController,
                            focusNode: _questionTextFocusNode,
                            labelText: '問題文',
                            textFieldHeight: 80,
                            focusedHintText: '例）日本の首都は東京である。',
                            imageUrls: [],
                            localImageBytes:
                            _localImagesMap[_questionTextController] ?? [],
                            onRemoveLocalImage: (image) {
                              _removeImage(_questionTextController, image);
                            },
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
                            GestureDetector(
                              child: ExpandableTextField(
                                controller: _correctChoiceTextController,
                                focusNode: _correctChoiceTextFocusNode,
                                labelText: '正答の選択肢',
                                textFieldHeight: 80,
                                focusedHintText: '例）東京である。',
                                imageUrls: [],
                                localImageBytes:
                                _localImagesMap[_correctChoiceTextController] ??
                                    [],
                                onRemoveLocalImage: (image) {
                                  _removeImage(
                                      _correctChoiceTextController, image);
                                },
                              ),
                            ),
                          ],
                          if (_selectedQuestionType == 'single_choice') ...[
                            ExpandableTextField(
                              controller: _correctChoiceTextController,
                              focusNode: _correctChoiceTextFocusNode,
                              labelText: '正答の選択肢',
                              textFieldHeight: 18,
                              focusedHintText: '例）東京である。',
                              imageUrls: [],
                              localImageBytes:
                              _localImagesMap[_correctChoiceTextController] ??
                                  [],
                              onRemoveLocalImage: (image) {
                                _removeImage(_correctChoiceTextController, image);
                              },
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
                          GestureDetector(
                            child: ExpandableTextField(
                              controller: _explanationTextController,
                              focusNode: _explanationTextFocusNode,
                              labelText: '解説',
                              textFieldHeight: 24,
                              focusedHintText:
                              '例）東京は、1869年（明治2年）に首都となりました',
                              localImageBytes:
                              _localImagesMap[_explanationTextController] ??
                                  [],
                              onRemoveLocalImage: (image) {
                                _removeImage(_explanationTextController, image);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          ExpandableTextField(
                            controller: _hintTextController,
                            focusNode: _hintTextFocusNode,
                            labelText: 'ヒント',
                            textFieldHeight: 24,
                            focusedHintText: '関東地方にある都道府県です。',
                            localImageBytes:
                            _localImagesMap[_hintTextController] ?? [],
                            onRemoveLocalImage: (image) {
                              _removeImage(_hintTextController, image);
                            },
                          ),
                          const SizedBox(height: 16),
                          QuestionTagsInput(
                            tags: _questionTags,
                            aggregatedTags: _aggregatedTags,
                            tagController: _tagController,
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
                            onExamDateChanged: _updateExamDateFromInput,
                          ),
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            color: AppColors.gray50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                canSave ? AppColors.blue500 : Colors.grey,
                                padding:
                                const EdgeInsets.symmetric(vertical: 9),
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: canSave ? _addQuestion : null,
                              child: Text(
                                '保存',
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                  canSave ? Colors.white : Colors.black45,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 300),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 画像生成タブ
            Column(
              children: [
                const SizedBox(height: 24),
                // ───── 質問形式セレクタ ─────
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: QuestionTypeSelector(
                    selectedType: _selectedQuestionType,
                    onTypeChanged: (t) => setState(() => _selectedQuestionType = t),
                  ),
                ),
                const SizedBox(height: 12),
                // ───── 問題数セレクター ─────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: QuestionCountSelector(
                    selectedCount: _generateCount,
                    onCountChanged: (cnt) => setState(() => _generateCount = cnt),
                  ),
                ),
                ImageGenerationTab(
                  onGeneratePressed: (Uint8List bytes) async {
                    // 画像種別をダミーで推定（必要なら実装を調整）
                    final String mime = _guessMime('dummy.jpg');
                    // AI 生成関数を呼び出し
                    await _generateQuestionFromImage(bytes, mimeType: mime);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
