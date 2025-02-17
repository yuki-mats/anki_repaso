import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/main.dart';

class OfficialListPage extends StatefulWidget {
  const OfficialListPage({Key? key}) : super(key: key);

  @override
  State<OfficialListPage> createState() => _OfficialListPageState();
}

class _OfficialListPageState extends State<OfficialListPage> {
  List<Map<String, dynamic>> _folders = []; // Firestore から取得したフォルダデータ
  String _selectedLicenseName = ''; // 検索で選択した資格名
  bool _isLoading = true; // データ取得中フラグ

  @override
  void initState() {
    super.initState();
    _fetchPublicFolders(); // 初期表示用のデータ取得
  }

  // 検索結果をクリアする処理
  void _clearSearchResults() {
    setState(() {
      _selectedLicenseName = '';
      _fetchPublicFolders(); // フォルダ一覧を元の状態に戻す
    });
  }

  // Firestore から isPublic が true のフォルダを取得
  Future<void> _fetchPublicFolders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('folders')
          .where('isPublic', isEqualTo: true)
          .get();

      setState(() {
        _folders = querySnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id}) // ID を含めて格納
            .toList();
      });
    } catch (e) {
      print('エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addViewerToFolder(String folderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userId = user.uid;

        // ローディング画面を表示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('ホームに追加中...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          },
        );

        // 1秒待機
        await Future.delayed(const Duration(seconds: 1));

        // `permissions` サブコレクションにユーザーの権限を追加
        final folderRef = FirebaseFirestore.instance.collection('folders').doc(folderId);
        final permissionRef = folderRef.collection('permissions').doc(userId);

        await permissionRef.set({
          'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
          'role': 'viewer',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // ローディング画面を閉じる
        if (mounted) {
          Navigator.pop(context);
        }

        // SnackBar で通知
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ホームに追加しました')),
          );
        }

        // フォルダ一覧ページに遷移し、最新データを表示
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainPage()),
                (Route<dynamic> route) => false,  // 既存のページスタックをすべて削除
          );
        }

      } else {
        throw Exception('ユーザーがログインしていません');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // エラー時にローディング画面を閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加中にエラーが発生しました: $e')),
        );
      }
    }
  }

  // モーダルを表示して追加処理を実行
  void _showAddViewerModal(String folderId, String folderName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          backgroundColor: Colors.white,
          title: Text('ホームに追加しますか？', style: const TextStyle(fontSize: 16)),
          content: Text('「$folderName」をホームに追加します。'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey), // 灰色の外枠
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text(
                '閉じる',
                style: TextStyle(color: Colors.grey), // テキスト色を灰色に
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // モーダルを閉じる
                await _addViewerToFolder(folderId); // viewer を追加
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue500, // ボタンの背景色を青色に
                foregroundColor: Colors.white, // テキスト色を白に
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text('追加する',
                style: TextStyle(fontWeight: FontWeight.bold),),
            ),
          ],
        );
      },
    );
  }

  // 検索用のモーダルシートを表示
  void _showSearchSheet() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          String sheetSearchKeyword = ''; // 検索キーワード
          List<LicenseItem> filteredList = _originalList;

          // キーワードに基づくフィルタリング
          void filterList(String keyword) {
            setModalState(() {
              sheetSearchKeyword = keyword.toLowerCase();
              filteredList = _originalList.where((item) {
                return item.name.toLowerCase().contains(sheetSearchKeyword) ||
                    item.furigana.toLowerCase().contains(sheetSearchKeyword) ||
                    item.katakana.toLowerCase().contains(sheetSearchKeyword);
              }).toList();
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: filterList,
                  decoration: InputDecoration(
                    hintText: 'キーワードを入力',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.blue400),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return ListTile(
                        title: Text(item.name),
                        onTap: () {
                          Navigator.pop(context); // モーダルを閉じる
                          setState(() {
                            _selectedLicenseName = item.name; // 選択した資格名を設定
                          });
                          _searchFoldersByLicense(item.name); // 資格名で検索
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // Firestore から資格名で絞り込む
  Future<void> _searchFoldersByLicense(String licenseName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('folders')
          .where('isPublic', isEqualTo: true)
          .where('licenseName', isEqualTo: licenseName)
          .get();

      setState(() {
        _folders = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;  // 明示的な型キャスト
          return {
            'id': doc.id,  // Firestore ドキュメントIDの追加
            'name': data['name'] ?? '名前なし',  // null対策
            'licenseName': data['licenseName'] ?? '資格名なし',  // null対策
            'isPublic': data['isPublic'] ?? false,  // 必要なら boolean のデフォルト値も設定
          };
        }).toList();
        print('検索結果: $_folders');
      });
    } catch (e) {
      print('エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('検索中にエラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 4.0, right: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('公式問題'),
              IconButton(
                icon: Icon(
                  _selectedLicenseName.isNotEmpty ? Icons.clear : Icons.search,
                  size: 24,
                ),
                onPressed: () {
                  if (_selectedLicenseName.isNotEmpty) {
                    _clearSearchResults();  // 検索結果をクリア
                  }
                  _showSearchSheet();  // 検索シートを表示
                },
              ),
            ],
          ),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
          ? const Center(child: Text('該当するフォルダがありません'))
          : ListView.builder(
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          final folder = _folders[index];
          return Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 24.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _showAddViewerModal(
                    folder['id'], // フォルダID
                    folder['name'] ?? '名前なし', // フォルダ名
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 16.0, right: 8.0),
                            child: SizedBox(
                              width: 40,
                              child: Icon(
                                Icons.folder,
                                size: 28,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      folder['licenseName'] ?? '名前なし',
                                      style: const TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                Text(
                                  folder['name'] ?? '資格名なし',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// サンプル資格データ
final List<LicenseItem> _originalList = [
  LicenseItem(name: '液化石油ガス設備士', furigana: 'えきかせきゆがすせつびし', katakana: 'エキカセキユガスセツビシ'),
  LicenseItem(name: 'エネルギー管理士', furigana: 'えねるぎーかんりし', katakana: 'エネルギーカンリシ'),
  LicenseItem(name: 'ガス主任技術者', furigana: 'がすしゅにんぎじゅつしゃ', katakana: 'ガスシュニンギジュツシャ'),
];

class LicenseItem {
  final String name;
  final String furigana;
  final String katakana;

  LicenseItem({
    required this.name,
    required this.furigana,
    required this.katakana,
  });
}
