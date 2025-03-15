import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/main.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';

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

  // Firestore から isPublic が true かつ isDeleted が false のフォルダを取得
  Future<void> _fetchPublicFolders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('folders')
          .where('isPublic', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .get();

      setState(() {
        _folders = querySnapshot.docs
            .map((doc) => {
          ...doc.data(),
          'id': doc.id, // ドキュメントIDを追加
        })
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

        // permissions サブコレクションにユーザーの権限を追加
        final folderRef =
        FirebaseFirestore.instance.collection('folders').doc(folderId);
        final permissionRef = folderRef.collection('permissions').doc(userId);

        await permissionRef.set({
          'userRef':
          FirebaseFirestore.instance.collection('users').doc(userId),
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
                (Route<dynamic> route) => false,
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
          title: const Text('ホームに追加しますか？', style: TextStyle(fontSize: 16)),
          content: Text('「$folderName」をホームに追加します。'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
              ),
              child: const Text(
                '閉じる',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // モーダルを閉じる
                await _addViewerToFolder(folderId); // viewer を追加
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
              ),
              child: const Text(
                '追加する',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                    item.furigana
                        .toLowerCase()
                        .contains(sheetSearchKeyword) ||
                    item.katakana
                        .toLowerCase()
                        .contains(sheetSearchKeyword);
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
                            _selectedLicenseName = item.name;
                          });
                          _searchFoldersByLicense(item.name);
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
          .where('isDeleted', isEqualTo: false)
          .where('licenseName', isEqualTo: licenseName)
          .get();

      setState(() {
        _folders = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? '名前なし',
            'licenseName': data['licenseName'] ?? '資格名なし',
            'isPublic': data['isPublic'] ?? false,
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
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.gray100, height: 1.0),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4.0, right: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('公式問題'),
              IconButton(
                icon: Icon(
                  _selectedLicenseName.isNotEmpty ? Icons.clear : Icons.search,
                  size: 24,
                ),
                onPressed: () {
                  if (_selectedLicenseName.isNotEmpty) {
                    _clearSearchResults(); // 検索結果をクリア
                  }
                  _showSearchSheet(); // 検索シートを表示
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.gray50,
            height: 12, // **背景色付きの余白**
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _folders.isEmpty
                ? const Center(child: Text('該当するフォルダがありません'))
                : ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 2.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: InkWell(
                      onTap: () => _showAddViewerModal(
                        folder['id'],
                        folder['name'] ?? '名前なし',
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 18.0, bottom: 16.0, left: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // タイトル行
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                RoundedIconBox(
                                  icon: Icons.folder_outlined, // フォルダアイコン
                                  iconColor: Colors.orange, // アイコンの色
                                  backgroundColor: Colors.orange.withOpacity(0.2), // 薄いオレンジ色の背景// アイコンサイズ
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // フォルダ名
                                      Text(
                                        folder['name'] ?? '資格名なし',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // 資格名
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // #（灰色にする）
                                    Text(
                                      '# ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    // 資格名
                                    Text(
                                      folder['licenseName'] ?? '名前なし',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(width: 6), // 資格名と問題数の間に適度なスペース
                                    // 問題数（デフォルトで0を表示）
                                    Text(
                                      '　${folder['questionCount'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray700,
                                      ),
                                    ),
                                    Text(
                                      ' 問',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// サンプル資格データ
final List<LicenseItem> _originalList = [
  LicenseItem(name: '液化石油ガス設備士試験', furigana: 'えきかせきゆがすせつびし', katakana: 'エキカセキユガスセツビシ'),
  LicenseItem(name: 'エネルギー管理士試験', furigana: 'えねるぎーかんりし', katakana: 'エネルギーカンリシ'),
  LicenseItem(name: 'ガス主任技術者試験', furigana: 'がすしゅにんぎじゅつしゃ', katakana: 'ガスシュニンギジュツシャ'),
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
