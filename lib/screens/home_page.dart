// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repaso/screens/study_set_answer_page.dart';
import '../widgets/home_page_widgets/question_set_picker_page.dart';
import '../widgets/home_page_widgets/study_set_picker_page.dart';
import '../widgets/list_page_widgets/reusable_progress_card.dart';
import '../widgets/home_page_widgets/weekly_chart_toggle.dart';
import '../utils/app_colors.dart';
import 'answer_page.dart';

/// ─────────────────────────────────────────────
/// HomePage  ─ アプリ起動直後に表示するホーム画面
/// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --------------- ダミー週間データ ----------------
  static const _counts   = <int>[45, 30, 75, 50, 90, 20, 35];
  static const _accuracy = <int>[40, 60, 55, 80, 35, 70, 50];

  // --------------- 今すぐ学習リスト ----------------
  final List<Map<String, dynamic>> _learningNowCards = [];

  // --------------- 試験日カウントダウン用ステート ----------------
  DateTime? _examDate;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ──────────── タイマー開始 ────────────
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_examDate == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = _examDate!.difference(DateTime.now());
      setState(() {
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      });
      if (diff.isNegative) _countdownTimer?.cancel();
    });
  }

  // ──────────── 時間フォーマット ────────────
  String _formattedTimeLeft() {
    final hours   = _timeLeft.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy年M月d日 EEEE', 'ja').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ───── ヘッダー ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildHeader(context, today),
              ),
            ),
            // ───── ステータス行 ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: _buildStatsRow(),
              ),
            ),
            // ───── 週間学習グラフ ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: WeeklyChartToggle(
                  counts: _counts,
                  accuracy: _accuracy,
                  barHeight: 160,
                ),
              ),
            ),
            // ───── 今すぐ学習 見出し ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text('今すぐ学習',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.black87)),
                    const Spacer(),
                    // ───── プラスボタン ─────
                    GestureDetector(
                      onTap: _openAddMenu,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            size: 18, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ───── 今すぐ学習リスト ─────
            _learningNowCards.isEmpty
                ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: GestureDetector(
                  onTap: _openAddMenu,
                  child: _buildEmptyLearningNowCard(),
                ),
              ),
            )
                : SliverList.separated(
              itemCount: _learningNowCards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, idx) {
                final m = _learningNowCards[idx];
                return ReusableProgressCard(
                  iconData: m['iconData'] as IconData,
                  iconColor: m['iconColor'] as Color,
                  iconBgColor: m['iconBg'] as Color,
                  title: m['title'] as String,
                  isVerified: m['verified'] as bool,
                  memoryLevels: m['memoryLevels'] as Map<String, int>,
                  correctAnswers: m['correct'] as int,
                  totalAnswers: m['totalAns'] as int,
                  count: m['count'] as int,
                  countSuffix: m['suffix'] as String,
                  onTap: () {
                    final icon = m['iconData'] as IconData;
                    if (icon == Icons.quiz_outlined) {
                      final folderId = m['folderId'] as String?;
                      final questionSetId = m['id'] as String;
                      final title = m['title'] as String;
                      if (folderId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnswerPage(
                              folderId: folderId,
                              questionSetId: questionSetId,
                              questionSetName: title,
                            ),
                          ),
                        );
                      }
                    } else if (icon == Icons.school_outlined) {
                      final studySetId = m['id'] as String;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudySetAnswerPage(studySetId: studySetId)),
                      );
                    }
                  },
                  onMorePressed: () => _showLearningCardOptionsModal(idx),
                  selectionMode: false,
                  cardId: m['id'] as String,
                  selectedId: null,
                  onSelected: null,
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ───────── 今すぐ学習 未設定カード ─────────
  Widget _buildEmptyLearningNowCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, size: 24, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '今すぐ学習にセット',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // 今すぐ学習カードのオプションモーダル
  // ──────────────────────────────────────────
  void _showLearningCardOptionsModal(int idx) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ─── 変更 ───
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(Icons.edit_outlined, size: 22, color: AppColors.gray600),
              ),
              title: const Text('変更', style: TextStyle(fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                final icon = _learningNowCards[idx]['iconData'] as IconData;
                final isQuestionSet = icon == Icons.quiz_outlined;
                final selected = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => isQuestionSet
                          ? const QuestionSetPickerPage()
                          : const StudySetPickerPage()),
                );
                if (selected != null) {
                  setState(() => _learningNowCards[idx] = _normalizeCard(selected));
                }
              },
            ),
            const SizedBox(height: 8),
            // ─── 削除 ───
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(Icons.delete_outline, size: 22, color: AppColors.gray600),
              ),
              title: const Text('削除', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _learningNowCards.removeAt(idx));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 追加メニュー
  // ──────────────────────────────────────────
  void _openAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('今すぐ学習にセット',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.black87)),
            const SizedBox(height: 20),
            Row(
              children: [
                // ───── 問題集 ─────
                _OptionCard(
                  emoji: '📚',
                  title: '問題集',
                  subTitle: '問題集をセット',
                  onTap: () async {
                    Navigator.pop(context);
                    final selected = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(builder: (_) => const QuestionSetPickerPage()),
                    );
                    if (selected != null &&
                        !_learningNowCards.any((e) => e['id'] == selected['id'])) {
                      setState(() => _learningNowCards.add(_normalizeCard(selected)));
                    }
                  },
                ),
                const SizedBox(width: 12),
                // ───── 暗記セット ─────
                _OptionCard(
                  emoji: '📝',
                  title: '暗記セット',
                  subTitle: '暗記セットをセット',
                  onTap: () async {
                    Navigator.pop(context);
                    final selected = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(builder: (_) => const StudySetPickerPage()),
                    );
                    if (selected != null &&
                        !_learningNowCards.any((e) => e['id'] == selected['id'])) {
                      setState(() => _learningNowCards.add(_normalizeCard(selected)));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────── 受け取った Map をカード用に整形 ──────────
  Map<String, dynamic> _normalizeCard(Map<String, dynamic> raw) {
    final bool isQuestion = raw['type'] == 'question';
    return {
      'id': raw['id'],
      'folderId': raw['folderId'],       // questionSet のみ
      'title': raw['title'] ?? '',
      'iconData': raw['iconData'] ??
          (isQuestion ? Icons.quiz_outlined : Icons.school_outlined),
      'iconColor': raw['iconColor'] ?? Colors.white,
      'iconBg': raw['iconBg'] ??
          (isQuestion ? Colors.indigo : Colors.deepPurple),
      'verified': raw['verified'] ?? false,
      'memoryLevels': raw['memoryLevels'] ??
          const {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      'correct': raw['correct'] ?? 0,
      'totalAns': raw['totalAns'] ?? 0,
      'count': raw['count'] ?? 0,
      'suffix': raw['suffix'] ?? (isQuestion ? '問' : '枚'),
    };
  }

  // ───────── ステータスカード列 ─────────
  Widget _buildStatsRow() => Row(
    children: [
      const _StatCard(icon: Icons.cached_rounded, label: '回答数', value: '345分'),
      const SizedBox(width: 12),
      const _StatCard(icon: Icons.star_rate, label: '正答率', value: '73%'),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: _showExamDateInputModal,
          child: Container(
            height: 92,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.black54, size: 16),
                    const SizedBox(width: 4),
                    Text('試験日まで',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.black54)),
                  ],
                ),
                Text(
                  _examDate != null ? '${_remainingDays()}日' : '-',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  _examDate != null ? _formattedTimeLeft() : '--:--:--',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  /// ──────────── ヘッダー ────────────
  Widget _buildHeader(BuildContext context, String today) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('おかえりなさい！',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.black87)),
            const SizedBox(height: 4),
            Text(today,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
      const _StreakBadge(count: 12),
      const SizedBox(width: 12),
      // ───── profileImageUrl をロードして表示 ─────
      FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get(),
        builder: (ctx, snap) {
          if (snap.hasData && snap.data!.exists) {
            final url = snap.data!.get('profileImageUrl') as String;
            return CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(url),
            );
          }
          return const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.deepPurpleAccent,
            child: Text('U', style: TextStyle(color: Colors.white)),
          );
        },
      ),
    ],
  );

  /// 試験日までの日数を計算（過ぎたら0日）
  int _remainingDays() {
    if (_examDate == null) return 0;
    final diff = _examDate!.difference(DateTime.now()).inDays;
    return diff >= 0 ? diff : 0;
  }

  /// 「年／月／日」別入力のモーダル
  Future<void> _showExamDateInputModal() async {
    final formKey = GlobalKey<FormState>();
    String year =
    _examDate != null ? DateFormat('yyyy').format(_examDate!) : '';
    String month =
    _examDate != null ? DateFormat('M').format(_examDate!) : '';
    String day =
    _examDate != null ? DateFormat('d').format(_examDate!) : '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // フォーカス用ノードを作成
        final yearFocusNode = FocusNode();
        // モーダル表示後に年フィールドへフォーカス
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(ctx).requestFocus(yearFocusNode);
        });

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ハンドル
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('試験日を入力',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.black87)),
              const SizedBox(height: 20),
              Form(
                key: formKey,
                child: Row(
                  children: [
                    // 年
                    Expanded(
                      child: TextFormField(
                        focusNode: yearFocusNode,
                        autofocus: true,
                        initialValue: year,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '年',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 4,
                        onChanged: (v) {
                          year = v;
                          if (v.characters.length == 4) {
                            FocusScope.of(ctx).nextFocus();
                          }
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return '年を入力';
                          if (int.tryParse(v) == null) return '数字のみ';
                          return null;
                        },
                        onSaved: (v) => year = v!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 月
                    Expanded(
                      child: TextFormField(
                        initialValue: month,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '月',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 2,
                        onChanged: (v) {
                          month = v;
                          if (v.characters.length == 2) {
                            FocusScope.of(ctx).nextFocus();
                          }
                        },
                        validator: (v) {
                          final m = int.tryParse(v ?? '');
                          if (m == null) return '数字のみ';
                          if (m < 1 || m > 12) return '1〜12の範囲';
                          return null;
                        },
                        onSaved: (v) => month = v!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 日
                    Expanded(
                      child: TextFormField(
                        initialValue: day,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '日',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 2,
                        onChanged: (v) => day = v,
                        validator: (v) {
                          final d = int.tryParse(v ?? '');
                          if (d == null) return '数字のみ';
                          if (d < 1 || d > 31) return '1〜31の範囲';
                          return null;
                        },
                        onSaved: (v) => day = v!,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      setState(() {
                        _examDate = DateTime(
                          int.parse(year),
                          int.parse(month),
                          int.parse(day),
                        );
                      });
                      _startCountdownTimer();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('更新'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ───────── モーダル内カード ─────────
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.subTitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.black87)),
              const SizedBox(height: 4),
              Text(subTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ───────── ステータスカード / ストリークバッジ ─────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.black54, size: 16),
                const SizedBox(width: 4),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.black54)),
              ],
            ),
            Expanded(
              child: Center(
                child: Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepOrange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text('$count日',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}