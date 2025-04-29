import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:repaso/utils/app_colors.dart';
import 'dart:io';
import 'dart:typed_data';

class ProfileEditPage extends StatefulWidget {
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  String? userId;
  String profileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2FIcons.school.v3.png?alt=media&token=2fe984d6-b755-439e-a81e-afb8b707f495';
  String name = '未設定';
  bool isDataLoaded = false;
  bool isCompressing = false;
  late TextEditingController _nameController;
  late final FocusNode _focusNode;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: name);
    _focusNode = FocusNode();
    _fetchUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _focusNode.addListener(() {
      setState(() {});
    });

    _nameController.addListener(() {
      setState(() {
        name = _nameController.text;
      });
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            profileImageUrl = data?['profileImageUrl'] ?? profileImageUrl;
            name = data?['name'] ?? name;
            _nameController.text = name;
            isDataLoaded = true;
          });
        } else {
          setState(() => isDataLoaded = true);
        }
      } else {
        setState(() => isDataLoaded = true);
      }
    } catch (e) {
      setState(() => isDataLoaded = true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      setState(() => isCompressing = true);
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final compressedFile = await _compressImage(File(pickedFile.path));
        setState(() {
          _selectedImageFile = compressedFile;
          isCompressing = false;
        });
      } else {
        setState(() => isCompressing = false);
      }
    } catch (e) {
      print('画像選択中にエラー: $e');
      setState(() => isCompressing = false);
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final originalImage = file.readAsBytesSync();
      img.Image? decodedImage = img.decodeImage(originalImage);
      if (decodedImage == null) throw Exception('画像形式エラー');

      const int maxSize = 256;
      if (decodedImage.width > maxSize || decodedImage.height > maxSize) {
        decodedImage = decodedImage.width > decodedImage.height
            ? img.copyResize(decodedImage, width: maxSize)
            : img.copyResize(decodedImage, height: maxSize);
      }

      final tempDir = Directory.systemTemp;
      final pngFile = File('${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.png')
        ..writeAsBytesSync(img.encodePng(decodedImage));

      _checkFileFormat(pngFile, expectedFormat: 'PNG');

      final reDecodedPng = img.decodeImage(pngFile.readAsBytesSync())!;
      final compressedImage = img.encodeJpg(reDecodedPng, quality: 60);
      final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg')
        ..writeAsBytesSync(compressedImage);

      _checkFileFormat(compressedFile, expectedFormat: 'JPG');

      return compressedFile;
    } catch (e) {
      print('圧縮エラー: $e');
      rethrow;
    }
  }

  void _checkFileFormat(File file, {required String expectedFormat}) {
    final bytes = file.readAsBytesSync();
    String format;
    if (bytes.sublist(0, 4).toString() == '[137, 80, 78, 71]') {
      format = 'PNG';
    } else if (bytes.sublist(0, 3).toString() == '[255, 216, 255]') {
      format = 'JPG';
    } else {
      format = 'UNKNOWN';
    }
    if (format != expectedFormat) {
      throw Exception('形式不一致: $format ≠ $expectedFormat');
    }
  }

  Future<void> _saveProfile() async {
    try {
      String? downloadUrl;
      if (_selectedImageFile != null && userId != null) {
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child('profile_images/$fileName');
        final uploadTask = ref.putFile(_selectedImageFile!);
        final snapshot = await uploadTask;
        if (snapshot.state == TaskState.success) {
          downloadUrl = await ref.getDownloadURL();
        } else {
          throw Exception('アップロード失敗');
        }
      }

      final updateData = {
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (downloadUrl != null) updateData['profileImageUrl'] = downloadUrl;

      await FirebaseFirestore.instance.collection('users').doc(userId).update(updateData);

      setState(() {
        if (downloadUrl != null) profileImageUrl = downloadUrl!;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('プロフィールが更新されました')));
      Navigator.pop(context, true);
    } catch (e) {
      print('保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(title: Text('プロフィール編集')),
      body: isDataLoaded
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileImageSection(),
            SizedBox(height: 20),
            _buildUsernameField(),
            SizedBox(height: 24),
            _buildSaveButton(),
            Spacer(),
          ],
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          '保存',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _selectedImageFile != null
                  ? FileImage(_selectedImageFile!)
                  : NetworkImage(profileImageUrl) as ImageProvider,
            ),
            if (isCompressing)
              Positioned.fill(
                child: CircleAvatar(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    final hasFocus = _focusNode.hasFocus;
    final hasText = _nameController.text.isNotEmpty;

    return Container(
      alignment: Alignment.center,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent, width: 2),
      ),
      child: TextField(
        controller: _nameController,
        focusNode: _focusNode,
        style: const TextStyle(height: 1.5),
        cursorColor: AppColors.blue600,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: (hasFocus || hasText) ? 'ユーザー名' : null,
          hintText: (!hasFocus && !hasText)
              ? 'ユーザー名'
              : (hasFocus && !hasText)
              ? '例）暗記 太郎'
              : null,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          floatingLabelStyle: const TextStyle(color: AppColors.blue600),
          border: InputBorder.none,
        ),
        onChanged: (value) => setState(() => name = value),
      ),
    );
  }
}
