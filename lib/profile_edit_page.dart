import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'utils/app_colors.dart';

class ProfileEditPage extends StatefulWidget {
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  String? userId;
  // Firestore上のプロフィール画像URLまたはデフォルト値
  String profileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/repaso-rbaqy4.appspot.com/o/profile_images%2FIcons.school.v3.png?alt=media&token=2fe984d6-b755-439e-a81e-afb8b707f495';
  String name = '未設定';
  bool isDataLoaded = false;
  late TextEditingController _nameController;
  late final FocusNode _focusNode;
  // 端末からの画像選択ではなく、公式アイコンURLを保持
  String? _selectedIconUrl;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: name);
    _focusNode = FocusNode();
    _fetchUserData();

    // ページ遷移後にテキストフィールドへ自動フォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // 入力の変更を監視し、保存ボタンの有効状態を更新
    _nameController.addListener(() {
      final currentText = _nameController.text.trim();
      setState(() {
        // 入力が空でなければ有効（公式アイコンが選択されている場合も有効）
        _isButtonEnabled = currentText.isNotEmpty || _selectedIconUrl != null;
      });
    });

    // フォーカス状態を監視し、UIを更新
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
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

  /// Firebase Storageの official_icon_images フォルダ内の全アイコンURLを取得
  Future<List<String>> _fetchOfficialIcons() async {
    final storageRef =
    FirebaseStorage.instance.ref().child('official_icon_images');
    final result = await storageRef.listAll();
    List<String> urls = [];
    for (var item in result.items) {
      final url = await item.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  /// ユーザーがタップすると、すぐにモーダルが表示され、内部でアイコン一覧が非同期で読み込まれる
  Future<void> _selectOfficialIcon() async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      // 角を丸くする
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      builder: (context) {
        return _IconSelectionModal(
          onIconSelected: (iconUrl) {
            setState(() {
              _selectedIconUrl = iconUrl;
              _isButtonEnabled = true;
            });
            Navigator.of(context).pop();
          },
          fetchIcons: _fetchOfficialIcons,
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    try {
      String? downloadUrl;
      // 公式アイコンが選択されていればそのURLを使用
      if (_selectedIconUrl != null) {
        downloadUrl = _selectedIconUrl!;
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);
      print('Firestoreへの保存成功');

      // UIを更新
      setState(() {
        if (downloadUrl != null) {
          profileImageUrl = downloadUrl;
          _selectedIconUrl = null; // 選択状態をリセット
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロフィールが更新されました')),
      );
      Navigator.pop(context, true); // trueを返してMyPageでリロード
    } catch (e) {
      print('エラーの詳細: ${e.runtimeType} - ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: ${e.toString()}')),
      );
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
      appBar: AppBar(
        title: Text('プロフィール編集'),
      ),
      body: isDataLoaded
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileImageSection(),
            SizedBox(height: 20),
            _buildUsernameField(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            Spacer(),
          ],
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  /// 保存ボタン
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
          _isButtonEnabled ? AppColors.blue600 : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _isButtonEnabled ? _saveProfile : null,
        child: Text(
          '保存',
          style: TextStyle(
            color: _isButtonEnabled ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  /// プロフィール画像表示部（タップで公式アイコン選択モーダルを起動）
  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _selectOfficialIcon,
        child: CircleAvatar(
          radius: 50,
          backgroundImage: (_selectedIconUrl != null)
              ? NetworkImage(_selectedIconUrl!)
              : NetworkImage(profileImageUrl),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    final bool hasFocus = _focusNode.hasFocus;
    final bool hasText = _nameController.text.isNotEmpty;

    return Container(
      alignment: Alignment.center,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.transparent,
          width: 2.0,
        ),
      ),
      child: TextField(
        focusNode: _focusNode,
        controller: _nameController,
        minLines: 1,
        maxLines: 1,
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
          floatingLabelStyle: const TextStyle(
            color: AppColors.blue600,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {
            name = value;
            _isButtonEnabled =
                value.trim().isNotEmpty || _selectedIconUrl != null;
          });
        },
      ),
    );
  }
}

/// モーダル内で公式アイコンを非同期で取得し、読み込み中はローディングインジケーターを表示、取得完了後はグリッドで表示
class _IconSelectionModal extends StatefulWidget {
  final Future<List<String>> Function() fetchIcons;
  final Function(String) onIconSelected;
  const _IconSelectionModal({
    required this.fetchIcons,
    required this.onIconSelected,
  });

  @override
  _IconSelectionModalState createState() => _IconSelectionModalState();
}

class _IconSelectionModalState extends State<_IconSelectionModal> {
  late Future<List<String>> _iconFuture;

  @override
  void initState() {
    super.initState();
    _iconFuture = widget.fetchIcons();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'アイコンを選択',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          FutureBuilder<List<String>>(
            future: _iconFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // アイコン取得中はローディングインジケーターを表示
                return Container(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue600),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Container(
                  height: 300,
                  child: Center(child: Text('アイコンの取得に失敗しました')),
                );
              }
              final iconUrls = snapshot.data!;
              return Container(
                height: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: AlwaysScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: iconUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        widget.onIconSelected(iconUrls[index]);
                      },
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(iconUrls[index]),
                        radius: 30,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
