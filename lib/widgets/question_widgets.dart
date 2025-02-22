import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'dart:typed_data';

// 問題タイプの選択ウィジェット
class ChipWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const ChipWidget({
    Key? key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

// 正誤問題用の選択ウィジェット
class TrueFalseTile extends StatelessWidget {
  final String label;
  final bool value;
  final bool groupValue;
  final VoidCallback onTap;

  const TrueFalseTile({
    Key? key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

// 正答、誤答の入力フィールド
class ExpandableTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final double textFieldHeight;
  final String? focusedHintText;
  final List<String> imageUrls;
  final List<Uint8List> localImageBytes;
  final Function(Uint8List)? onRemoveLocalImage; // ローカル画像削除コールバック
  final Function(String)? onDeleteUploadedImage; // アップロード済み画像削除コールバック

  const ExpandableTextField({
    Key? key,
    required this.controller,
    this.focusNode,
    required this.labelText,
    this.textFieldHeight = 16,
    this.focusedHintText,
    this.imageUrls = const [],
    this.localImageBytes = const [],
    this.onRemoveLocalImage, // ★ 修正: ローカル画像削除コールバック
    this.onDeleteUploadedImage, // ★ 修正: アップロード済み画像削除コールバック
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasFocus = focusNode?.hasFocus ?? false;
    final bool isEmpty = controller.text.isEmpty;

    return Container(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (focusNode != null) {
                FocusScope.of(context).requestFocus(focusNode);
              }
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: textFieldHeight),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: null,
                style: const TextStyle(
                  fontSize: 13.0,
                  color: Colors.black,
                ),
                cursorColor: AppColors.blue500,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: labelText,
                  labelStyle: const TextStyle(
                    fontSize: 13.0,
                    color: Colors.black54,
                  ),
                  floatingLabelStyle: const TextStyle(
                    fontSize: 16.0,
                    color: AppColors.blue500,
                  ),
                  hintText: (hasFocus && isEmpty) ? focusedHintText : null,
                  hintStyle: const TextStyle(
                    fontSize: 13.0,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
                ),
              ),
            ),
          ),
          if (localImageBytes.isNotEmpty || imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildScrollableImageList(),
          ],
        ],
      ),
    );
  }

  /// **ローカル画像 & アップロード画像を横並びで表示**
  Widget _buildScrollableImageList() {
    return SizedBox(
      height: 100, // 画像の高さ固定
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._buildImageWidgets(localImageBytes, isNetworkImage: false),
              ..._buildImageWidgets(imageUrls, isNetworkImage: true),
            ],
          ),
        ),
      ),
    );
  }

  /// **画像ウィジェットをリストで生成**
  List<Widget> _buildImageWidgets(List<dynamic> images, {required bool isNetworkImage}) {
    return images.map((imgData) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isNetworkImage
                  ? Image.network(
                imgData,
                width: 100, // 画像サイズ統一
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  );
                },
              )
                  : Image.memory(
                imgData,
                width: 100,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () {
                  if (isNetworkImage && onDeleteUploadedImage != null) {
                    onDeleteUploadedImage!(imgData);
                  } else if (!isNetworkImage && onRemoveLocalImage != null) {
                    onRemoveLocalImage!(imgData);
                  }
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

/// タグ入力用のウィジェット（共通化）
/// [tags]：すでに追加されているタグ（問題に設定済み）
/// [aggregatedTags]：フォルダの aggregatedQuestionTags の候補リスト
/// [tagController]：入力用の TextEditingController
/// [onTagAdded]：タグ追加時のコールバック
/// [onTagDeleted]：タグ削除時のコールバック
class QuestionTagsInput extends StatefulWidget {
  final List<String> tags;
  final List<String> aggregatedTags;
  final TextEditingController tagController;
  final Function(String) onTagAdded;
  final Function(String) onTagDeleted;

  const QuestionTagsInput({
    Key? key,
    required this.tags,
    required this.aggregatedTags,
    required this.tagController,
    required this.onTagAdded,
    required this.onTagDeleted,
  }) : super(key: key);

  @override
  _QuestionTagsInputState createState() => _QuestionTagsInputState();
}

class _QuestionTagsInputState extends State<QuestionTagsInput> {
  final FocusNode _tagFocusNode = FocusNode();
  List<String> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    widget.tagController.addListener(_filterSuggestions);
    _filterSuggestions();
  }

  @override
  void dispose() {
    widget.tagController.removeListener(_filterSuggestions);
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _filterSuggestions() {
    final input = widget.tagController.text.trim();
    setState(() {
      if (input.isEmpty) {
        // 入力がない場合は、既に追加されていない aggregatedTags を全て表示
        _filteredSuggestions = widget.aggregatedTags
            .where((tag) => !widget.tags.contains(tag))
            .toList();
      } else {
        // 入力内容にマッチする候補を絞り込む
        _filteredSuggestions = widget.aggregatedTags
            .where((tag) =>
        tag.toLowerCase().contains(input.toLowerCase()) &&
            !widget.tags.contains(tag))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // タグ入力フィールドと既存タグの表示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gray100, width: 1.0),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            alignment: WrapAlignment.start,
            children: [
              // 既存のタグを表示
              ...widget.tags.map((tag) => Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.gray500, width: 1),
                  ),
                  backgroundColor: AppColors.gray50,
                  deleteIcon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.gray500,
                  ),
                  onDeleted: () => widget.onTagDeleted(tag),
                ),
              )),
              // タグ入力用の TextField（動的な幅）
              IntrinsicWidth(
                child: TextField(
                  controller: widget.tagController,
                  focusNode: _tagFocusNode,
                  cursorColor: AppColors.blue500,
                  style: const TextStyle(
                    fontSize: 13.0,
                    height: 1.5,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'タグ追加',
                    hintStyle: TextStyle(fontSize: 13.0, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  ),
                  onSubmitted: (value) {
                    final tag = value.trim();
                    if (tag.isNotEmpty) {
                      widget.onTagAdded(tag);
                      widget.tagController.clear();
                      Future.delayed(const Duration(milliseconds: 50), () {
                        FocusScope.of(context).requestFocus(_tagFocusNode);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // 候補表示（入力中、またはフォーカス中）
        if (_tagFocusNode.hasFocus && _filteredSuggestions.isNotEmpty)
          Container(
            // 見た目を「プルダウン」風にする
            margin: const EdgeInsets.only(top: 4),
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200), // 候補リストの最大高さ
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.gray100, width: 1.0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _filteredSuggestions[index];
                return InkWell(
                  onTap: () {
                    widget.onTagAdded(suggestion);
                    widget.tagController.clear();
                    _filterSuggestions();
                    FocusScope.of(context).requestFocus(_tagFocusNode);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class ExamDateField extends StatelessWidget {
  final TextEditingController examYearController;
  final TextEditingController examMonthController;
  final FocusNode examYearFocusNode;
  final FocusNode examMonthFocusNode;
  final bool isExamDateError;
  final VoidCallback onExamDateChanged;

  const ExamDateField({
    Key? key,
    required this.examYearController,
    required this.examMonthController,
    required this.examYearFocusNode,
    required this.examMonthFocusNode,
    required this.isExamDateError,
    required this.onExamDateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Container全体がタップされたときに、yearフィールドにフォーカスを移す
      onTap: () {
        FocusScope.of(context).requestFocus(examYearFocusNode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isExamDateError ? Colors.red : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '出題年月',
              style: TextStyle(
                fontSize: 13,
                color: isExamDateError ? Colors.red : Colors.black54,
              ),
            ),
            const SizedBox(width: 32),
            SizedBox(
              width: 72,
              child: TextField(
                controller: examYearController,
                focusNode: examYearFocusNode,
                cursorColor: AppColors.blue500,
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
                    FocusScope.of(context).requestFocus(examMonthFocusNode);
                  }
                },
                onEditingComplete: onExamDateChanged,
              ),
            ),
            Text(
              '/',
              style: TextStyle(
                fontSize: 14,
                color: isExamDateError ? Colors.red : Colors.black54,
              ),
            ),
            SizedBox(
              width: 48,
              child: TextField(
                controller: examMonthController,
                focusNode: examMonthFocusNode,
                cursorColor: AppColors.blue500,
                maxLength: 2,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'mm',
                  border: InputBorder.none,
                ),
                onEditingComplete: onExamDateChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


