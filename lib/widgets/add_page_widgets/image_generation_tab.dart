// 画像から問題を生成するタブ用ウィジェット
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';

class ImageGenerationTab extends StatefulWidget {
  /// 画像が選択され「問題を生成する」を押したときに呼ばれるコールバック
  /// bytes には JPEG/PNG のバイト列が渡る。
  final void Function(Uint8List bytes)? onGeneratePressed;

  const ImageGenerationTab({Key? key, this.onGeneratePressed}) : super(key: key);

  @override
  State<ImageGenerationTab> createState() => _ImageGenerationTabState();
}

class _ImageGenerationTabState extends State<ImageGenerationTab> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedBytes;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked =
      await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _selectedBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の取得に失敗しました')),
      );
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('フォトライブラリから選択'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSourceModal,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gray300,
                  width: 2,
                ),
              ),
              child: _selectedBytes == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_upload_outlined,
                      size: 48, color: AppColors.gray600),
                  SizedBox(height: 8),
                  Text('タップして画像をアップロード',
                      style: TextStyle(color: AppColors.gray600)),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_selectedBytes!,
                    fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedBytes != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue500,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('問題を生成する'),
              onPressed: () {
                if (widget.onGeneratePressed != null && _selectedBytes != null) {
                  widget.onGeneratePressed!(_selectedBytes!);
                }
              },
            ),
        ],
      ),
    );
  }
}
