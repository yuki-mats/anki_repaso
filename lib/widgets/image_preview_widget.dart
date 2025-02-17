import 'package:flutter/material.dart';

class ImagePreviewWidget extends StatelessWidget {
  final List<String> imageUrls;

  const ImagePreviewWidget({Key? key, required this.imageUrls}) : super(key: key);

  void _showImagePreview(BuildContext context, String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (imageUrl.isEmpty || uri == null || !uri.isAbsolute) return; // 無効なURLなら何もしない

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return Material(
          color: Colors.black,
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
                right: 0,
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

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final displayImages = imageUrls.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: _buildImageGrid(context, displayImages),
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> images) {
    switch (images.length) {
      case 1:
        return _buildSingleImage(context, images[0]);
      case 2:
        return _buildTwoImages(context, images);
      case 3:
        return _buildThreeImages(context, images);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSingleImage(BuildContext context, String imageUrl) {
    return _buildImageTile(context, imageUrl, 150, 100);
  }

  Widget _buildTwoImages(BuildContext context, List<String> images) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: _buildImageTile(context, images[index], 100, 90),
        );
      }),
    );
  }

  Widget _buildThreeImages(BuildContext context, List<String> images) {
    return Column(
      children: [
        _buildImageTile(context, images[0], 200, 200),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImageTile(context, images[1], 90, 90),
            const SizedBox(width: 6),
            _buildImageTile(context, images[2], 90, 90),
          ],
        ),
      ],
    );
  }

  Widget _buildImageTile(BuildContext context, String imageUrl, double width, double height) {
    final uri = Uri.tryParse(imageUrl);
    if (imageUrl.isEmpty || uri == null || !uri.isAbsolute) {
      return _errorPlaceholder(width, height);
    }
    return GestureDetector(
      onTap: () => _showImagePreview(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _loadingPlaceholder(width, height);
          },
          errorBuilder: (context, error, stackTrace) {
            return _errorPlaceholder(width, height);
          },
        ),
      ),
    );
  }

  Widget _loadingPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _errorPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}