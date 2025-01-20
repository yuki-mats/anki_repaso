import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // 画像圧縮用ライブラリ
import 'dart:io';
import 'dart:typed_data';

class ProfileEditPage extends StatefulWidget {
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  String? userId;
  String profileImageUrl = 'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2FIcons.school.v3.png?alt=media&token=2fe984d6-b755-439e-a81e-afb8b707f495';
  String name = '未設定';
  bool isDataLoaded = false;
  bool isCompressing = false; // 圧縮中フラグ
  bool isUploading = false; // アップロード状態を管理
  late TextEditingController _nameController;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: name);
    _fetchUserData();
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
            _nameController.text = name; // TextFieldに反映
            isDataLoaded = true;
          });
        } else {
          setState(() {
            isDataLoaded = true;
          });
        }
      } else {
        setState(() {
          isDataLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        isDataLoaded = true;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();

      setState(() {
        isCompressing = true; // 画像選択前からロードを表示
      });

      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        print('画像が選択されました: ${pickedFile.path}');

        // 圧縮処理を実行
        File compressedFile = await _compressImage(File(pickedFile.path));

        setState(() {
          _selectedImageFile = compressedFile; // 圧縮した画像をセット
          isCompressing = false; // 圧縮終了後にロードを非表示
        });

        print('圧縮された画像をセットしました: ${compressedFile.path}');
      } else {
        print('画像の選択がキャンセルされました');
        setState(() {
          isCompressing = false; // キャンセル時もロードを非表示
        });
      }
    } catch (e) {
      print('画像選択中にエラーが発生しました: $e');
      setState(() {
        isCompressing = false; // エラー時もロードを非表示
      });
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final originalImage = file.readAsBytesSync();
      img.Image? decodedImage = img.decodeImage(originalImage);

      if (decodedImage == null) {
        throw Exception('サポートされていない画像形式です');
      }

      // 一度PNG形式に変換
      final tempDir = Directory.systemTemp;
      final pngFile = File('${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.png')
        ..writeAsBytesSync(img.encodePng(decodedImage));

      print('PNG形式に変換しました: ${pngFile.path}');
      _checkFileFormat(pngFile, expectedFormat: 'PNG');

      // 40%の品質で圧縮
      final compressedImage = img.encodeJpg(img.decodeImage(pngFile.readAsBytesSync())!, quality: 40);
      final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg')
        ..writeAsBytesSync(compressedImage);

      print('圧縮後の画像サイズ: ${compressedFile.lengthSync()} bytes');
      _checkFileFormat(compressedFile, expectedFormat: 'JPG');

      return compressedFile;
    } catch (e) {
      print('画像圧縮中にエラーが発生しました: $e');
      rethrow;
    }
  }

  void _checkFileFormat(File file, {required String expectedFormat}) {
    final Uint8List bytes = file.readAsBytesSync();
    String format;

    if (bytes.sublist(0, 4).toString() == '[137, 80, 78, 71]') {
      format = 'PNG';
    } else if (bytes.sublist(0, 3).toString() == '[255, 216, 255]') {
      format = 'JPG';
    } else {
      format = 'UNKNOWN';
    }

    print('ファイル形式確認: $format');
    if (format != expectedFormat) {
      throw Exception('ファイル形式が期待と異なります: 期待=$expectedFormat, 実際=$format');
    }
  }

  Future<void> _saveProfile() async {
    try {
      String? downloadUrl;

      // プロフィール画像のアップロード
      if (_selectedImageFile != null && userId != null) {
        // ユニークなファイル名を生成
        final uniqueFileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Firebase Storageのprofile_imagesフォルダに保存
        final storageRef = FirebaseStorage.instance.ref().child('profile_images/$uniqueFileName');
        print('圧縮された画像をアップロード開始: ${_selectedImageFile!.path}');

        final uploadTask = storageRef.putFile(_selectedImageFile!);

        // アップロード進行状況をログ
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          print('アップロード状況: ${snapshot.state}');
        });

        // アップロード完了を待つ
        final snapshot = await uploadTask;

        if (snapshot.state == TaskState.success) {
          downloadUrl = await snapshot.ref.getDownloadURL();
          print('アップロード成功: $downloadUrl');
        } else {
          throw Exception('アップロードに失敗しました: ${snapshot.state}');
        }
      }

      // Firestoreに最新の情報を保存
      print('Firestoreにプロフィール情報を保存します');
      final Map<String, dynamic> updateData = {
        'name': name, // ユーザー名を常に更新
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (downloadUrl != null) {
        updateData['profileImageUrl'] = downloadUrl; // プロフィール画像URLを更新
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update(updateData);
      print('Firestoreへの保存成功');

      // UIを更新
      setState(() {
        if (downloadUrl != null) {
          profileImageUrl = downloadUrl!;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロフィールが更新されました')),
      );
      Navigator.pop(context, true); // trueを返してMyPageでリロード
    } catch (e) {
      print('エラーの詳細: ${e.runtimeType} - ${e.toString()}');
      if (e is FirebaseException) {
        print('エラーコード: ${e.code}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('プロフィール編集'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
                onPressed: _saveProfile,
                child: Text('保存',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,),
                ),
            ),
          ),
        ],
      ),
      body: isDataLoaded
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileImageSection(),
            SizedBox(height: 20),
            _buildUsernameField(),
            Spacer(),
          ],
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage, // 全体をタップで画像選択処理を起動
        child: Stack(
          alignment: Alignment.center, // ローディングを中央に配置
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _selectedImageFile != null
                  ? FileImage(_selectedImageFile!)
                  : NetworkImage(profileImageUrl) as ImageProvider,
            ),
            if (isCompressing) // 圧縮中のみインジケーターを表示
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
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'ユーザー名',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          name = value;
        });
      },
    );
  }
}
