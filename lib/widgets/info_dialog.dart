import 'package:flutter/material.dart';

class InfoDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<String>? imageUrls; // 🔹 画像URLリスト
  final String buttonText;
  final VoidCallback? onClose;
  final TextStyle? titleTextStyle;
  final TextStyle? contentTextStyle;
  final TextStyle? buttonTextStyle;
  final ShapeBorder? dialogShape;
  final Color? backgroundColor;

  const InfoDialog({
    Key? key,
    required this.title,
    required this.content,
    this.imageUrls,
    this.buttonText = '閉じる',
    this.onClose,
    this.titleTextStyle,
    this.contentTextStyle,
    this.buttonTextStyle,
    this.dialogShape,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: dialogShape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: backgroundColor ?? Colors.white,
      title: Text(
        title,
        style: titleTextStyle ?? const TextStyle(color: Colors.black, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              content,
              style: contentTextStyle ?? const TextStyle(color: Colors.black),
            ),
          ),
          if (imageUrls != null && imageUrls!.isNotEmpty)
            _buildImageList(context, imageUrls!), // 🔹 画像リストを追加
        ],
      ),
      actions: [
        TextButton(
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          child: Text(
            buttonText,
            style: buttonTextStyle ?? const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
      ],
    );
  }

  /// **画像リストの表示**
  Widget _buildImageList(BuildContext context, List<String> urls) {
    return SizedBox(
      height: 100, // 画像の高さ
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // 🔹 横スクロール可能にする
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: urls.map((url) {
            return GestureDetector(
              onTap: () => _showImagePreview(context, url), // 🔹 画像をタップでプレビュー表示
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 100, // 画像の幅
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
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// **画像プレビューを表示**
  void _showImagePreview(BuildContext context, String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (imageUrl.isEmpty || uri == null || !uri.isAbsolute) return; // 無効なURLなら何もしない

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return Material(
          color: Colors.black.withOpacity(0.8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 600,  // 最大幅を設定
                    maxHeight: 600, // 最大高さを設定
                  ),
                  child: imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.isAbsolute == true
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _loadingPlaceholder(300, 200);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _errorPlaceholder(300, 200);
                    },
                  )
                      : _errorPlaceholder(300, 200),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// **ローディングプレースホルダー**
  Widget _loadingPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// **エラープレースホルダー**
  Widget _errorPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}
