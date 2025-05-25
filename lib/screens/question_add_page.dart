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
import 'package:repaso/services/question_count.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:repaso/widgets/add_page_widgets/question_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/add_page_widgets/image_generation_tab.dart';
import '../widgets/add_page_widgets/ocr_icon_button.dart';

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

class _QuestionAddPageState extends State<QuestionAddPage> {
  String _appBarTitle = '問題作成';
  List<String> _questionTags = [];
  List<String> _aggregatedTags = [];
  // コントローラー
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

  // フォーカスノードとコントローラーのマップ
  late final Map<FocusNode, TextEditingController> _focusToControllerMap;


  // 出題年月の内部保持（年と月のみ。日付は自動的に1日固定）
  DateTime? _selectedExamDate;
  // 追加: 出題年月の入力エラー状態を保持するフラグ
  bool _isExamDateError = false;

  @override
  void initState() {
    super.initState();
    _loadAggregatedTags();

    _questionTextController.addListener(_onQuestionTextChanged);

    _focusToControllerMap = {
      _questionTextFocusNode: _questionTextController,
      _correctChoiceTextFocusNode: _correctChoiceTextController,
      _explanationTextFocusNode: _explanationTextController,
      _hintTextFocusNode: _hintTextController,
    };

    // 🔹 フォーカスリスナーを適切に設定
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

  @override
  void dispose() {
    // _questionTextController のリスナー解除
    _questionTextController.removeListener(_onQuestionTextChanged);

    // フォーカスノードのリスナー解除（既存のコードのまま）
    for (var node in _focusToControllerMap.keys) {
      node.removeListener(() {});
    }


    // コントローラーと FocusNode の dispose
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

    super.dispose();
  }

// 画像圧縮＋MIME判定
  Uint8List _compress(Uint8List raw, {required bool asPng}) {
    var decoded = img.decodeImage(raw)!;
    if (decoded.width > 2048 || decoded.height > 2048) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: 2048)
          : img.copyResize(decoded, height: 2048);
    }
    return asPng
        ? Uint8List.fromList(img.encodePng(decoded, level: 6))
        : Uint8List.fromList(img.encodeJpg(decoded, quality: 70));
  }
  String _guessMime(String path) =>
      path.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg";

  Future<void> _scanTextFromImage() async {
    print("[DEBUG] _scanTextFromImage start");

    // ① ソース選択
    final ImageSource? src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title : const Text('カメラ'),
            onTap : () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title : const Text('ギャラリー'),
            onTap : () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;

    // ② 取得＋トリミング
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

    // ③ 圧縮＋MIME
    final raw = await cropped.readAsBytes();
    final mime = _guessMime(cropped.path);
    final data = _compress(raw, asPng: mime == "image/png");
    print("[DEBUG] raw=${raw.length} compressed=${data.length} mime=$mime");

    // ④ 呼び出し
    _showLoadingDialog();
    try {
      final res = await FirebaseFunctions
          .instanceFor(region: "us-central1")
          .httpsCallable('callGeminiOCR')({
        'imageBase64': base64Encode(data),
        'mimeType'   : mime,
      });
      Navigator.pop(context);

      final extracted = (res.data['text'] ?? '').toString();
      print("[DEBUG] extracted.len=${extracted.length}");
      if (extracted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字が検出できませんでした')),
        );
        return;
      }

      final ctrl = _currentFocusedController ?? _getFocusedController();
      if (ctrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テキストフィールドを選択してください')),
        );
        return;
      }
      final pos = ctrl.selection.baseOffset;
      if (pos >= 0) {
        ctrl.text = ctrl.text.replaceRange(pos, pos, extracted);
        ctrl.selection = TextSelection.collapsed(offset: pos + extracted.length);
      } else {
        ctrl.text += extracted;
      }
    } on FirebaseFunctionsException catch (e) {
      Navigator.pop(context);
      print("[DEBUG] FFE code=${e.code}, msg=${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 失敗: ${e.code}')),
      );
    } catch (e) {
      Navigator.pop(context);
      print("[DEBUG] Unexpected error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR に失敗しました')),
      );
    }
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
      _localImagesMap.clear(); // 🔹 画像データをクリア
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

  /// **現在フォーカスされている `TextEditingController` を取得**
  TextEditingController? _getFocusedController() {
    FocusNode? focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode != null && _focusToControllerMap.containsKey(focusedNode)) {
      return _focusToControllerMap[focusedNode];
    }
    return null;
  }

  /// **画像を挿入するメソッド**
  void _insertImage() async {
    // ① フォーカス中のコントローラー取得
    final ctrl = _currentFocusedController ?? _getFocusedController();
    if (ctrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像を挿入するフィールドを選択してください')),
      );
      return;
    }

    // ② 誤答／非フラッシュカード正答には禁止
    if (ctrl == _incorrectChoice1TextController ||
        ctrl == _incorrectChoice2TextController ||
        ctrl == _incorrectChoice3TextController) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('誤答には画像を挿入できません')),
      );
      return;
    }
    if (_selectedQuestionType != 'flash_card' && ctrl == _correctChoiceTextController) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正答の画像はフラッシュカードでのみ追加可能です')),
      );
      return;
    }

    // ③ キーボードを閉じる
    FocusScope.of(context).unfocus();

    // ④ ギャラリーから画像を選択
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // ⑤ トリミング（不要ならこのブロック全部を削除して OK）
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '画像をトリミング',
          toolbarColor: AppColors.blue500,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: '画像をトリミング',
          cancelButtonTitle: 'キャンセル',
          doneButtonTitle: '完了',
          aspectRatioLockEnabled: false,
        ),
      ],
    );
    if (cropped == null) return;

    // ⑥ バイト列を状態に追加
    final bytes = await cropped.readAsBytes();
    setState(() {
      final list = _localImagesMap.putIfAbsent(ctrl, () => []);
      if (list.length < 2) {
        list.add(bytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('1つのフィールドには最大2枚まで画像を追加できます')),
        );
      }
    });
  }

  /// 画像削除メソッド
  void _removeImage(TextEditingController controller, Uint8List image) {
    setState(() {
      _localImagesMap[controller]?.remove(image);
      if (_localImagesMap[controller]?.isEmpty ?? false) {
        _localImagesMap.remove(controller);
      }
    });
  }

  /// タグ追加処理
  void _addTag(String tag) {
    if (!_questionTags.contains(tag)) {
      setState(() {
        _questionTags.add(tag);
        _tagController.clear();
      });
    }
  }

  /// タグ削除処理
  void _removeTag(String tag) {
    setState(() {
      _questionTags.remove(tag);
    });
  }

  Future<void> _loadAggregatedTags() async {
    // folderId を用いてフォルダドキュメントを取得
    final folderDoc = await FirebaseFirestore.instance
        .collection('folders')
        .doc(widget.folderId)
        .get();
    setState(() {
      _aggregatedTags = List<String>.from(
          ((folderDoc.data() as Map<String, dynamic>)['aggregatedQuestionTags'] ?? [])
      );
    });
  }

  /// 画像を 256 px までリサイズ＋JPEG 品質60で圧縮し、Firebase Storage へアップロード
  Future<List<String>> _uploadImagesToStorage(
      String questionId, String field, List<Uint8List> images) async {
    if (images.isEmpty) return [];

    final List<String> uploadedUrls = [];
    final storageRef   = FirebaseStorage.instance.ref().child('question_images');

    const int maxSize = 256; // 長辺 256px に統一（ProfileEditPage と同じ方針）
    const int jpegQuality = 60;

    for (int i = 0; i < images.length; i++) {
      try {
        /* ① デコード */
        img.Image? decoded = img.decodeImage(images[i]);
        if (decoded == null) {
          print('❌ 画像デコード失敗');
          continue;
        }

        /* ② リサイズ（長辺256px未満ならスキップ） */
        if (decoded.width > maxSize || decoded.height > maxSize) {
          decoded = decoded.width >= decoded.height
              ? img.copyResize(decoded, width: maxSize)
              : img.copyResize(decoded, height: maxSize);
        }

        /* ③ JPEG へ再エンコード（品質60） */
        final Uint8List compressed =
        Uint8List.fromList(img.encodeJpg(decoded, quality: jpegQuality));

        /* ④ Firebase Storage へアップロード */
        final String fileName = '$questionId-$field-$i.jpg';
        final Reference ref   = storageRef.child(fileName);

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

    final questionDocRef = FirebaseFirestore.instance.collection('questions').doc();

    // 画像のアップロード
    Map<String, List<Uint8List>> imageMap = {
      'questionImageUrls': _localImagesMap[_questionTextController] ?? [],
      'correctChoiceImageUrls': _localImagesMap[_correctChoiceTextController] ?? [],
      'explanationImageUrls': _localImagesMap[_explanationTextController] ?? [],
      'hintImageUrls': _localImagesMap[_hintTextController] ?? [],
    };

    // 各画像フィールドごとにアップロードを実行
    Map<String, List<String>> uploadedImageUrls = {};
    for (var entry in imageMap.entries) {
      uploadedImageUrls[entry.key] = await _uploadImagesToStorage(questionDocRef.id, entry.key, entry.value);
    }

    // Firestoreに保存するデータ
    final questionData = {
      'questionSetId': widget.questionSetId,
      'questionText': _questionTextController.text.trim(),
      'questionType': _selectedQuestionType,
      'examDate': _selectedExamDate != null ? Timestamp.fromDate(_selectedExamDate!) : null,
      'createdByRef': FirebaseFirestore.instance.collection('users').doc(user.uid),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'explanationText': _explanationTextController.text.trim(),
      'hintText': _hintTextController.text.trim(),
      'questionImageUrls': uploadedImageUrls['questionImageUrls'],
      'explanationImageUrls': uploadedImageUrls['explanationImageUrls'],
      'hintImageUrls': uploadedImageUrls['hintImageUrls'],
      'isOfficialQuestion': false,
      'isDeleted': false,
      'isFlagged': false,
      // タグを追加
      'questionTags': _questionTags,
    };

    // 選択問題ごとの追加フィールド
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
      // フォルダの aggregatedQuestionTags を更新（既存タグと重複せず追加）
      if (_questionTags.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('folders')
            .doc(widget.folderId)
            .update({
          'aggregatedQuestionTags': FieldValue.arrayUnion(_questionTags),
        });
      }
      await updateQuestionCounts(widget.folderId, widget.questionSetId);

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
                  const url = 'https://docs.google.com/spreadsheets/d/1615CKsezB_8KvybWLqlxhtAXkm1hFn-d-9oD9M_PbTY/edit?usp=sharing';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                    decoration: TextDecoration.none, // 下線を非表示
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  ImportQuestionsService service = ImportQuestionsService();
                  await service.pickFileAndImport(context, widget.folderId, widget.questionSetId);
                },
                child: const Text('ファイルを選択'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(color: Colors.black87)),
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

    final bool showBottomSaveButton = isKeyboardOpen && isAnyTextFieldFocused;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: Text(_appBarTitle),
          bottom: const TabBar(
            tabs: [
              Tab(text: '手入力'),
              Tab(text: '画像から生成'),
            ],
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black45,
            indicatorColor: AppColors.blue500,
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
          padding: const EdgeInsets.only(bottom: 0.0, right: 16.0, left: 16.0),
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
                  const OcrIconButton(),
                ],
              ),
              const SizedBox(width: 16),
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
        body: TabBarView(
          children: [
            // 手入力タブ
            GestureDetector(
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
                      imageUrls: [],
                      localImageBytes: _localImagesMap[_questionTextController] ?? [],
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
                          localImageBytes: _localImagesMap[_correctChoiceTextController] ?? [],
                          onRemoveLocalImage: (image) {
                            _removeImage(_correctChoiceTextController, image);
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
                        localImageBytes: _localImagesMap[_correctChoiceTextController] ?? [],
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
                        focusedHintText: '例）東京は、1869年（明治2年）に首都となりました',
                        localImageBytes: _localImagesMap[_explanationTextController] ?? [],
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
                      localImageBytes: _localImagesMap[_hintTextController] ?? [],
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
                          backgroundColor: canSave ? AppColors.blue500 : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: canSave ? _addQuestion : null,
                        child: Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 16,
                            color: canSave ? Colors.white : Colors.black45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 300),
                  ],
                ),
              ),
            ),

            // 画像生成タブ
            ImageGenerationTab(
              onGeneratePressed: (Uint8List bytes) {
                // OCRやAI連携の処理をここに記述
                print("画像から問題生成：${bytes.lengthInBytes}バイト");
              },
            ),
          ],
        ),
      ),
    );
  }
}
