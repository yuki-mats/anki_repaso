
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
      final folderSnapshot = await FirebaseFirestore.instance
          .collection('folders')
          .where('userRoles.${widget.userId}', whereIn: ['owner', 'editor', 'viewer'])
          .get();

      final Map<String, dynamic> fetchedData = {};
      final Map<String, bool?> folderState = {};
      final Map<String, bool> expandedStateInit = {};

      for (var folder in folderSnapshot.docs) {
        final folderId = folder.id;
        final folderName = folder['name'];
        folderState[folderId] = false;
        expandedStateInit[folderId] = false;

        final questionSetsSnapshot = await FirebaseFirestore.instance
            .collection('questionSets')
            .where('folderRef', isEqualTo: folder.reference)
            .get();

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

        fetchedData[folderId] = {
          'name': folderName,
          'questionSets': questionSets,
        };

        folderState[folderId] = _calculateFolderSelection(
          questionSets.map((qs) => qs['id'] as String).toList(),
        );
      }

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
    return null;
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
        .map((entry) => folderData.values
        .expand((folder) => folder['questionSets'])
        .firstWhere((qs) => qs['id'] == entry.key)['name'] as String)
        .toList();
  }

  void _onBackPressed() {
    updateSelectedQuestionSetNames();
    Navigator.pop(
      context,
      {
        'questionSetIds': questionSetSelection.keys.where((id) => questionSetSelection[id] == true).toList(),
        'selectedQuestionSetNames': selectedQuestionSetNames,
      },
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
          const SizedBox(height: 16),
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
                        Text(folderInfo['name']),
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
                            title: Text(questionSet['name']),
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
