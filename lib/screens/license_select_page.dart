// lib/screens/license_select_page.dart
//
// UI はそのまま。外側に GestureDetector を追加して、
// 画面のどこか（注意書きやリストなど）をタップすると
// TextField のフォーカスが外れキーボードが閉じるようにしただけ。

import 'package:flutter/material.dart';
import 'package:repaso/data/license_items.dart';
import 'package:repaso/utils/app_colors.dart';

class LicenseSelectPage extends StatefulWidget {
  /// すでに選択済みの資格名を渡す
  final List<String> initialSelected;
  const LicenseSelectPage({
    Key? key,
    this.initialSelected = const [],
  }) : super(key: key);

  @override
  State<LicenseSelectPage> createState() => _LicenseSelectPageState();
}

class _LicenseSelectPageState extends State<LicenseSelectPage> {
  late final Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
  }

  List<LicenseItem> get _filteredList {
    final q = _query.toLowerCase();
    final list = _query.isEmpty
        ? List<LicenseItem>.from(kLicenseList)
        : kLicenseList.where((l) {
      return l.name.toLowerCase().contains(q) ||
          l.katakana.toLowerCase().contains(q) ||
          l.furigana.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) =>
    _selected.contains(a.name) == _selected.contains(b.name)
        ? 0
        : _selected.contains(a.name)
        ? -1
        : 1);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: AppColors.blue600,
        primaryContainer: AppColors.blue100,
        onPrimaryContainer: AppColors.blue900,
        surface: Colors.white,
        surfaceContainerHighest: Colors.white,
        outlineVariant: AppColors.blue100,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          return states.contains(MaterialState.selected)
              ? AppColors.blue600
              : Colors.white;
        }),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.blue600,
        selectionHandleColor: AppColors.blue600,
        selectionColor: Color(0x332196F3),
      ),
    );

    return Theme(
      data: theme,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(), // ← フォーカス解除
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            title: const Text('資格の登録'),
          ),
          body: Column(
            children: [
              Card(
                color: theme.colorScheme.primary.withOpacity(.08),
                elevation: 0,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: const ListTile(
                  dense: true,
                  leading:
                  Icon(Icons.info_outline, color: AppColors.blue600),
                  title: Text('公開中の場合、過去問で学習できます。'),
                  subtitle: Text('その他の資格についても、順次、過去問を整備予定です！ぜひご登録ください。'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  cursorColor: AppColors.blue600,
                  decoration: InputDecoration(
                    prefixIcon:
                    const Icon(Icons.search, color: AppColors.gray700),
                    hintText: '検索',
                    filled: true,
                    fillColor: AppColors.gray100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: _filteredList.isEmpty
                    ? const Center(child: Text('該当する資格がありません'))
                    : ListView.separated(
                  padding:
                  const EdgeInsets.only(top: 4, bottom: 80),
                  itemCount: _filteredList.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 0, indent: 16, endIndent: 16),
                  itemBuilder: (context, idx) {
                    final lic = _filteredList[idx];
                    final checked = _selected.contains(lic.name);

                    return InkWell(
                      onTap: () => setState(() {
                        checked
                            ? _selected.remove(lic.name)
                            : _selected.add(lic.name);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 24),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: checked,
                                onChanged: (_) => setState(() {
                                  checked
                                      ? _selected.remove(lic.name)
                                      : _selected.add(lic.name);
                                }),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(lic.name,
                                      style: const TextStyle(
                                          fontWeight:
                                          FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    lic.furigana,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (lic.isOfficial)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(.1),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '公開中',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                    theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
          floatingActionButton: SizedBox(
            width: MediaQuery.of(context).size.width * .9,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, _selected.toList()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _selected.isEmpty ? '自分で問題を作成する' : '次へ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
