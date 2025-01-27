import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class SetQuestionSetPage extends StatefulWidget {
  final String userId; // ログイン中のユーザーID
  final List<String> selectedQuestionSetIds; // 初期選択済みの問題集ID

  const SetQuestionSetPage({
    Key? key,
    required this.userId,
    required this.selectedQuestionSetIds,
  }) : super(key: key);

  @override
  _SetQuestionSetPageState createState() => _SetQuestionSetPageState();
}

class _SetQuestionSetPageState extends State<SetQuestionSetPage> {
  Map<String, dynamic> folderData = {};
  Map<String, bool?> folderSelection = {};
  Map<String, bool> questionSetSelection = {};
  Map<String, bool> expandedState = {};
  List<String> selectedQuestionSetNames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeSelectedQuestionSets();
    fetchFoldersAndQuestionSets();
  }

  void initializeSelectedQuestionSets() {
    for (var questionSetId in widget.selectedQuestionSetIds) {
      questionSetSelection[questionSetId] = true;
    }
  }

  Future<void> fetchFoldersAndQuestionSets() async {
    try {
      // フォルダを一括取得
      final folderSnapshot = await FirebaseFirestore.instance
          .collection('folders')
          .get();

      final Map<String, dynamic> fetchedData = {};
      final Map<String, bool?> folderState = {};
      final Map<String, bool> expandedStateInit = {};

      // 各フォルダに対して権限を確認し、権限があるものだけ表示
      for (var folder in folderSnapshot.docs) {
        final folderId = folder.id;
        final folderName = folder['name'];

        // ユーザー権限の取得（permissions サブコレクション）
        final permissionSnapshot = await FirebaseFirestore.instance
            .collection('folders')
            .doc(folderId)
            .collection('permissions')
            .where(
          'userRef',
          isEqualTo:
          FirebaseFirestore.instance.doc('users/${widget.userId}'),
        )
            .where('role', whereIn: ['owner', 'editor', 'viewer'])
            .get();

        // 権限がない場合はスキップ
        if (permissionSnapshot.docs.isEmpty) {
          continue;
        }

        folderState[folderId] = false;
        expandedStateInit[folderId] = false;

        // フォルダに紐づく問題集を取得
        final questionSetsSnapshot = await FirebaseFirestore.instance
            .collection('questionSets')
            .where('folderRef', isEqualTo: folder.reference)
            .get();

        // 問題集の選択状態を初期化し、既に選択済みのものがあれば展開状態に設定
        final questionSets = questionSetsSnapshot.docs.map((doc) {
          final questionSetId = doc.id;
          final isSelected = widget.selectedQuestionSetIds.contains(questionSetId);

          if (!questionSetSelection.containsKey(questionSetId)) {
            questionSetSelection[questionSetId] = isSelected;
          }
          if (isSelected) {
            selectedQuestionSetNames.add(doc['name']);
            expandedStateInit[folderId] = true;
          }
          return {'id': questionSetId, 'name': doc['name']};
        }).toList();

        // フォルダ情報を格納
        fetchedData[folderId] = {
          'name': folderName,
          'questionSets': questionSets,
        };

        // フォルダ自体のチェック状態（全選択・一部選択・未選択）を計算
        folderState[folderId] = _calculateFolderSelection(
          questionSets.map((qs) => qs['id'] as String).toList(),
        );
      }

      // 状態を更新
      setState(() {
        folderData = fetchedData;
        folderSelection = folderState;
        expandedState = expandedStateInit;
        isLoading = false;
      });

    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  bool? _calculateFolderSelection(List<String> questionSetIds) {
    final allSelected = questionSetIds.every((id) => questionSetSelection[id] == true);
    final noneSelected = questionSetIds.every((id) => questionSetSelection[id] == false);

    if (allSelected) return true;
    if (noneSelected) return false;
    return null; // 一部のみチェックされている状態
  }

  void updateParentSelection(String folderId) {
    final questionSets = folderData[folderId]['questionSets'] as List<Map<String, dynamic>>;
    setState(() {
      folderSelection[folderId] = _calculateFolderSelection(
        questionSets.map((qs) => qs['id'] as String).toList(),
      );
      updateSelectedQuestionSetNames();
    });
  }

  void updateChildSelection(String folderId, bool isSelected) {
    final questionSets = folderData[folderId]['questionSets'] as List<Map<String, dynamic>>;
    setState(() {
      // フォルダ配下の問題集を一括で選択/解除
      for (var questionSet in questionSets) {
        questionSetSelection[questionSet['id']] = isSelected;
      }
      folderSelection[folderId] = isSelected ? true : false;
      expandedState[folderId] = true; // 必ず展開状態に設定
      updateSelectedQuestionSetNames();
    });
    print("Updated Child Selection for $folderId: $questionSetSelection");
    print("Updated Expanded State: $expandedState");
  }

  void updateSelectedQuestionSetNames() {
    selectedQuestionSetNames = questionSetSelection.entries
        .where((entry) => entry.value)
        .map(
          (entry) => folderData.values
          .expand((folder) => folder['questionSets'])
          .firstWhere((qs) => qs['id'] == entry.key)['name'] as String,
    )
        .toList();
  }

  void _onBackPressed() {
    // 選択された問題集IDのみ返却
    updateSelectedQuestionSetNames();
    Navigator.pop(
      context,
      questionSetSelection.keys
          .where((id) => questionSetSelection[id] == true)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集の選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBackPressed,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ListView.builder(
                itemCount: folderData.length,
                itemBuilder: (context, index) {
                  final folderId = folderData.keys.elementAt(index);
                  final folderInfo = folderData[folderId];
                  return ExpansionTile(
                    key: Key(folderId),
                    title: Row(
                      children: [
                        Checkbox(
                          tristate: true,
                          value: folderSelection[folderId],
                          onChanged: (value) {
                            setState(() {
                              updateChildSelection(folderId, value == true);
                            });
                          },
                        ),
                        const Icon(Icons.folder, color: AppColors.gray600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            folderInfo['name'],
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    initiallyExpanded: expandedState[folderId] ?? false,
                    onExpansionChanged: (isExpanded) {
                      setState(() {
                        expandedState[folderId] = isExpanded;
                      });
                      print("Folder $folderId expansion changed to: $isExpanded");
                    },
                    children: folderInfo['questionSets'].map<Widget>((questionSet) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: questionSetSelection[questionSet['id']],
                                  onChanged: (value) {
                                    setState(() {
                                      questionSetSelection[questionSet['id']] = value!;
                                      updateParentSelection(folderId);
                                      updateSelectedQuestionSetNames();
                                    });
                                  },
                                ),
                                const Icon(Icons.layers_rounded, color: AppColors.gray600),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    questionSet['name'],
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
