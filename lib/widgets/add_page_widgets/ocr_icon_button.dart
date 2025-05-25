import 'dart:convert';               // ← 追加
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../utils/app_colors.dart';

class OcrIconButton extends StatefulWidget {
  const OcrIconButton({super.key});

  @override
  State<OcrIconButton> createState() => _OcrIconButtonState();
}

class _OcrIconButtonState extends State<OcrIconButton> {
  static const _apiKey = 'AIzaSyBqiU79Sdv3c3TT7S087fdEDVaCx0bNGb8';

  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Gemini.init(apiKey: _apiKey);
  }

  Future<void> _runOcr() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(lockAspectRatio: false),
        IOSUiSettings(),
      ],
    );
    if (cropped == null) return;

    setState(() => _busy = true);

    try {
      // 1) バイト列を取得
      final Uint8List bytes = await cropped.readAsBytes();
      // 2) Base64 文字列にエンコード
      final String b64 = base64Encode(bytes);
      // 3) MIME タイプを推測
      final ext = cropped.path.split('.').last.toLowerCase();
      final String mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      // 4) InlineData に設定
      final inlineData = InlineData(data: b64, mimeType: mime);

      // 5) Gemini 呼び出し
      final response = await Gemini.instance.prompt(parts: [
        Part.inline(inlineData),
        Part.text(
          'この画像から読み取れる日本語テキストをそのまま抽出してください。'
              '改行も含め、余計な説明は不要です。',
        ),
      ]);

      final String text = response?.output ?? '';
      if (text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OCR 文字列をコピーしました')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文字が検出できませんでした')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR 失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _busy
          ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.document_scanner_outlined),
      color: AppColors.blue500,
      iconSize: 32,
      onPressed: _busy ? null : _runOcr,
      tooltip: '画像からテキスト抽出',
    );
  }
}
