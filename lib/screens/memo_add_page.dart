import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repaso/utils/app_colors.dart';

class MemoAddPage extends StatefulWidget {
  final String questionId;
  final String questionSetId;

  const MemoAddPage({
    Key? key,
    required this.questionId,
    required this.questionSetId,
  }) : super(key: key);

  @override
  _MemoAddPageState createState() => _MemoAddPageState();
}

class _MemoAddPageState extends State<MemoAddPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  // 選択可能な memoType の一覧
  final List<Map<String, String>> _memoTypes = [
    {'value': 'explanation', 'label': '解説'},
    {'value': 'question', 'label': '疑問'},
    {'value': 'knowledge', 'label': '知識・用語'},
    {'value': 'notice', 'label': '気づき'},
  ];

  String? _selectedMemoType; // 選択された memoType
  bool _isTitleRequired = false; // タイトルが必須かどうか

  /// メモ追加処理
  Future<void> _addMemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 「疑問」を選択している場合、タイトルが必須
    if (_selectedMemoType == 'question' && title.isEmpty) {
      setState(() {
        _isTitleRequired = true;
      });
      _titleFocusNode.requestFocus(); // タイトル入力欄にフォーカスを移動
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('「疑問」を選んでいる場合、タイトルを入力してください')),
      );
      return;
    }

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモの内容を入力してください')),
      );
      return;
    }

    if (_selectedMemoType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモの種類を選択してください')),
      );
      return;
    }

    final memoData = {
      'questionId': widget.questionId,
      'questionSetId': widget.questionSetId,
      'title': title,
      'content': content,
      'visibility': 'private',
      'contentFormat': 'plain_text',
      'memoType': _selectedMemoType, // 選択されたメモの種類を保存
      'createdById': user.uid,
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    };

    try {
      // メモの追加
      await FirebaseFirestore.instance.collection('memos').add(memoData);

      // countクエリを使用して、該当questionIdのメモ数を取得
      final Query memosQuery = FirebaseFirestore.instance
          .collection('memos')
          .where('questionId', isEqualTo: widget.questionId);
      final AggregateQuerySnapshot snapshot = await memosQuery.count().get();
      final int? count = snapshot.count;

      // 該当問題のmemoCountを更新
      await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .update({'memoCount': count});

      _titleController.clear();
      _contentController.clear();
      setState(() {
        _selectedMemoType = null; // 選択をリセット
        _isTitleRequired = false; // タイトル必須をリセット
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモが追加されました')),
      );
      Navigator.of(context).pop(); // 正常登録後、前の画面へ戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモの追加に失敗しました')),
      );
    }
  }


  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('メモを追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'メモの種類を選択',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),

              // メモの種類選択 (チップを横スクロール可能にする)
              SizedBox(
                height: 40, // チップの高さ調整
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // 横スクロールを有効にする
                  child: Row(
                    children: _memoTypes.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0), // 各チップ間にスペースを追加
                        child: ChoiceChip(
                          label: Text(type['label']!),
                          selected: _selectedMemoType == type['value'],
                          onSelected: (selected) {
                            setState(() {
                              _selectedMemoType = selected ? type['value'] : null;
                              _isTitleRequired = _selectedMemoType == 'question';
                            });
                          },
                          selectedColor: AppColors.blue500,
                          labelStyle: TextStyle(
                            color: _selectedMemoType == type['value'] ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16.0),
              _buildExpandableTextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                textFieldMinHeight: 160.0,
                labelText: '内容',
                focusedHintText: 'メモの内容を入力してください',
              ),
              const SizedBox(height: 16.0),

              // 「疑問」の場合、タイトル入力を必須にする
              _buildExpandableTextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                labelText: 'タイトル' + (_isTitleRequired ? ' *' : ''),
              ),
              const SizedBox(height: 32.0),
              Text(
                '  ※ 投稿したメモは全ユーザーに公開されます。',
                ),
              const SizedBox(height: 8.0),

              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue500,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _addMemo,
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// ExpandableTextField に似たカスタムテキストフィールドを作成
  Widget _buildExpandableTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    String? focusedHintText,
    double textFieldMinHeight = 16.0, // 最小高さ
    double? textFieldMaxHeight, // 最大高さ（nullの場合、無制限）
  }) {
    final bool hasFocus = focusNode.hasFocus;
    final bool isEmpty = controller.text.isEmpty;

    return Container(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(focusNode),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: textFieldMinHeight,
                maxHeight: textFieldMaxHeight ?? double.infinity, // nullなら無制限
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: textFieldMaxHeight != null ? null : null, // maxLinesの指定は不要
                style: const TextStyle(
                  fontSize: 13.0,
                  color: Colors.black,
                ),
                cursorColor: AppColors.blue500,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: labelText,
                  labelStyle: const TextStyle(
                    fontSize: 13.0,
                    color: Colors.black54,
                  ),
                  floatingLabelStyle: const TextStyle(
                    fontSize: 16.0,
                    color: AppColors.blue500,
                  ),
                  hintText: (hasFocus && isEmpty) ? focusedHintText : null,
                  hintStyle: const TextStyle(
                    fontSize: 13.0,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


