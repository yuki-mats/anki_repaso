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
              // ★ 修正: タップ時にフォーカスを取得
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal, // **横スクロール可能**
              child: Row(
                children: [
                  // ローカル画像
                  ...localImageBytes.map((image) => _buildImageItem(image, isNetworkImage: false)).toList(),

                  // アップロード済み画像
                  ...imageUrls.map((url) => _buildImageItemList(url, isNetworkImage: true)).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// **画像リストの表示**
  Widget _buildImageList(List<dynamic> images, {required bool isNetworkImage}) {
    return SizedBox(
      height: 100,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: images.map((imgData) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isNetworkImage
                          ? Image.network(
                        imgData,
                        width: 100, // ★ 修正: 画像幅を調整
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
                        width: 100, // ★ 修正: 画像幅を調整
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
            }).toList(),
          ),
        ),
      ),
    );
  }
}

