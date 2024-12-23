import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class StudySetAddPage extends StatefulWidget {
  const StudySetAddPage({Key? key}) : super(key: key);

  @override
  _StudySetAddPageState createState() => _StudySetAddPageState();
}

class _StudySetAddPageState extends State<StudySetAddPage> {
  RangeValues _correctRateRange = const RangeValues(0, 100);
  bool _isFlagged = false;
  String? selectedQuestionSetName;
  String? studySetName;
  List<String> selectedQuestionSetNames = [];
  List<String> questionSetIds = []; // 問題集IDのリスト

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しい学習セット'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Row(
              children: [
                const Icon(
                  Icons.create,
                  size: 30,
                  color: AppColors.gray600,
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 100,
                  child: Text(
                    "セット名",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$studySetName',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final name = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StudySetNameEditPage(
                    initialName: studySetName ?? "",
                  ),
                ),
              );
              if (name != null && name is String) {
                setState(() {
                  studySetName = name;
                });
              }
            },
          ),
          const Divider(),
          ListTile(
            title: Row(
              children: [
                Icon(
                  Icons.layers_rounded,
                  size: 30,
                  color: AppColors.gray600,
                ),
                SizedBox(width: 6),
                SizedBox(
                  width: 100,
                  child: Text(
                    "問題集",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                if (selectedQuestionSetNames.isNotEmpty) // 選択された名前がある場合のみ表示
                  Expanded(
                    child: Text(
                      selectedQuestionSetNames.join(', '),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FolderTreeView(
                      userId: FirebaseAuth.instance.currentUser!.uid,
                      selectedQuestionSetIds: questionSetIds,
                    ),
                  ),
                );
                if (result != null && result is Map<String, List<String>>) {
                  setState(() {
                    questionSetIds = result['questionSetIds'] ?? [];
                    selectedQuestionSetNames = result['selectedQuestionSetNames'] ?? [];
                  });
                }
              }
          ),
          const Divider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Row(
                  children: [
                    Icon(
                      Icons.percent,
                      size: 30,
                      color: AppColors.gray600,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "正答率",
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                trailing: Text(
                  "${_correctRateRange.start.toInt()} 〜 ${_correctRateRange.end.toInt()}%",
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey[300], // AppColors.gray300 を代用
                  inactiveTickMarkColor: Colors.grey[300], // AppColors.gray300 を代用
                  activeTrackColor: AppColors.blue500, // AppColors.blue500 を代用
                  activeTickMarkColor: AppColors.blue500, // AppColors.blue500 を代用
                ),
                child: RangeSlider(
                  values: _correctRateRange,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  labels: null,
                  onChanged: (values) {
                    setState(() {
                      if ((values.end - values.start) >= 10) {
                        _correctRateRange = RangeValues(
                          (values.start / 10).round() * 10.0,
                          (values.end / 10).round() * 10.0,
                        );
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            title: const Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.bookmark,
                    size: 30,
                    color: AppColors.gray600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  "フラグ",
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            value: _isFlagged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.blue500,
            inactiveThumbColor: Colors.black,
            onChanged: (value) {
              setState(() {
                _isFlagged = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            title: const Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Icon(
                    Icons.sort,
                    size: 30,
                    color: AppColors.gray600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  "出題順",
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // 画面遷移の処理
            },
          ),
          const Divider(),
          ListTile(
            title: const Row(
              children: [
                Icon(
                  Icons.format_list_numbered,
                  size: 30,
                  color: AppColors.gray600,
                ),
                SizedBox(width: 6),
                Text(
                  "出題数",
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // 画面遷移の処理
            },
          ),
        ],
      ),
    );
  }
}

class FolderTreeView extends StatefulWidget {
  final String userId; // ログイン中のユーザーID
  final List<String> selectedQuestionSetIds; // 初期選択済みの問題集ID

  const FolderTreeView({
    Key? key,
    required this.userId,
    required this.selectedQuestionSetIds,
  }) : super(key: key);

  @override
  _FolderTreeViewState createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
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


class StudySetNameEditPage extends StatelessWidget {
  final String initialName;

  const StudySetNameEditPage({Key? key, required this.initialName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: initialName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('セット名の編集'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, controller.text);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'セット名',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, controller.text);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}