// 画像から問題を生成するタブ用ウィジェット
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';   // ← 追加
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
      // ① 画像読み込み
      final XFile? picked =
      await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;

      // ② トリミング UI を表示（自由トリミング）
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(lockAspectRatio: false),
          IOSUiSettings(),
        ],
      );
      if (cropped == null) return;

      // ③ 完成バイト列を保持
      final bytes = await cropped.readAsBytes();
      setState(() => _selectedBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の取得に失敗しました')),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Image Source 選択モーダル（統一デザイン版）
  // ─────────────────────────────────────────────
  void _showImageSourceModal() async {
    final ImageSource? src = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 160,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('カメラで撮影', style: TextStyle(fontSize: 16)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.photo_outlined,
                        size: 22, color: AppColors.gray600),
                  ),
                  title:
                  const Text('ギャラリーから選択', style: TextStyle(fontSize: 16)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (src != null) {
      _pickImage(src);
    }
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
                border: Border.all(color: AppColors.gray300, width: 2),
              ),
              child: _selectedBytes == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_upload_outlined,
                      size: 48, color: AppColors.gray600),
                  SizedBox(height: 8),
                  Text('タップして画像をアップロード\n現在、開発中です。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gray600)),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _selectedBytes!,
                  fit: BoxFit
                      .contain, // ← 全体が見えるように cover → contain に変更
                  width: double.infinity,
                ),
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
