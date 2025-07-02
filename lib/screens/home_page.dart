// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';                               // ← 変更なし
// import 'dart:math';                             // ✖️ 不要になったので削除

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // ✖️ 不要になったので削除

import '../main.dart' show routeObserver;
import '../widgets/home_page_widgets/weekly_chart_toggle.dart';
import '../widgets/home_page_widgets/learning_now_section.dart';
import '../widgets/home_page_widgets/exam_countdown_card.dart';
import '../widgets/home_page_widgets/streak_badge.dart';
// import 'paywall_page.dart';                    // ✖️ PaywallManager 経由で呼び出すため削除
import '../utils/paywall_manager.dart';            // ★ 追加 ── Paywall 表示ロジック集約

/// ─────────────────────────────────────────────
/// HomePage  ─ アプリ起動直後に表示するホーム画面
/// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, RouteAware {
  /* ─────────────── Firestore 関連 ─────────────── */
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _statsSub;

  /* ──────────── 直近 7 日分のデータ ──────────── */
  List<int> _counts = List.filled(7, 0); // answerCount
  List<int> _accuracy = List.filled(7, 0); // 正答率 (%)
  int _weekTotalAnswers = 0; // 7 日合計回答数
  int _weekAccuracyPct = 0; // 7 日総合正答率
  int _streakCount = 0; // 🔥 連続学習日数

  /* ───────── LearningNow リビルド用 ───────── */
  late Key _learningNowKey;

  /* ──────────── アニメーション ──────────── */
  late final AnimationController _streakAnimCtrl;
  late final Animation<double> _streakScale;

  /* ──────── Paywall 変数は PaywallManager に集約 ──────── */

  @override
  void initState() {
    super.initState();

    _learningNowKey = UniqueKey();

    /* ───── Paywall 表示判定 ───── */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaywallManager.maybeShow(context: context, uid: _uid);
    });

    /* ───── streak アニメーション設定 ───── */
    _streakAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _streakScale = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_streakAnimCtrl);

    /* ───── 直近 7 日間の日次統計を監視 ───── */
    final DateTime today = DateTime.now();
    final DateTime fromDate =
    DateTime(today.year, today.month, today.day).subtract(
      const Duration(days: 6),
    ); // 今日含め 7 日
    _statsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('dailyStudyStats')
        .where('dateTimestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
        .orderBy('dateTimestamp')
        .snapshots()
        .listen(_onDailyStats);
  }

  /* ───────── RouteObserver 登録 ───────── */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _statsSub.cancel();
    _streakAnimCtrl.dispose();
    super.dispose();
  }

  /// Answer 画面から戻って来たときに呼ばれる
  @override
  void didPopNext() {
    setState(() {
      _learningNowKey = UniqueKey(); // 強制的にリビルド
    });
  }

  /* ──────────── 直近 7 日分の統計が更新された ──────────── */
  void _onDailyStats(QuerySnapshot<Map<String, dynamic>> qs) {
    final DateTime today = DateTime.now();

    final List<int> counts = List.filled(7, 0);
    final List<int> corrects = List.filled(7, 0);

    for (final doc in qs.docs) {
      final data = doc.data();
      final ts = (data['dateTimestamp'] as Timestamp).toDate();
      final diff = today.difference(ts).inDays;
      if (diff >= 0 && diff < 7) {
        final idx = 6 - diff; // 並べ替え
        counts[idx] = (data['answerCount'] ?? 0) as int;
        corrects[idx] = (data['correctCount'] ?? 0) as int;
      }
    }

    // 日ごとの正答率 (%)
    final List<int> accuracy = List<int>.generate(7, (i) {
      return counts[i] == 0 ? 0 : (corrects[i] * 100 / counts[i]).round();
    });

    // 合計回答数・総合正答率
    final int totalAnswers = counts.fold(0, (a, b) => a + b);
    final int totalCorrect = corrects.fold(0, (a, b) => a + b);
    final int accPct =
    totalAnswers == 0 ? 0 : (totalCorrect * 100 / totalAnswers).round();

    /* ───── Duolingo 方式の連続学習日数 ───── */
    int streak = 0;
    final bool todayDone = counts[6] > 0;
    for (int i = todayDone ? 6 : 5; i >= 0; i--) {
      if (counts[i] > 0) {
        streak++;
      } else {
        break;
      }
    }

    /* ───── streak が +1 以上増えたらアニメ再生 ───── */
    if (streak > _streakCount) {
      _streakAnimCtrl.forward(from: 0.0);
    }

    setState(() {
      _counts = counts;
      _accuracy = accuracy;
      _weekTotalAnswers = totalAnswers;
      _weekAccuracyPct = accPct;
      _streakCount = streak;
    });
  }

  /* ───────────────── build ───────────────── */
  @override
  Widget build(BuildContext context) {
    final todayStr =
    DateFormat('yyyy年M月d日 EEEE', 'ja').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            /* ───── ヘッダー ───── */
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildHeader(context, todayStr, _streakCount),
              ),
            ),
            /* ───── ステータス行 ───── */
            SliverToBoxAdapter(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: _buildStatsRow(),
              ),
            ),
            /* ───── 週間学習グラフ ───── */
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: WeeklyChartToggle(
                  counts: _counts,
                  accuracy: _accuracy,
                  barHeight: 160,
                ),
              ),
            ),
            // 週間グラフの注意書き
            SliverToBoxAdapter(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(
                  '※ ver2.7.3以前のデータは反映されておりません。',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ),
            ),
            /* ───── 今すぐ学習 ───── */
            LearningNowSection(key: _learningNowKey),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  /* ───────── ステータスカード列 ───────── */
  Widget _buildStatsRow() {
    // 直近 7 日間の期間 (例: "6/23〜6/29")
    final now = DateTime.now();
    final from =
    DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final fmt = DateFormat('M/d');
    final range = '${fmt.format(from)}〜${fmt.format(now)}';

    return Row(
      children: [
        _StatCard(
          icon: Icons.cached_rounded,
          label: '回答数',
          value: _weekTotalAnswers == 0 ? '-' : _weekTotalAnswers.toString(),
          period: range,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.star_rate,
          label: '正答率',
          value: _weekTotalAnswers == 0 ? '-' : '$_weekAccuracyPct%',
          period: range,
        ),
        const SizedBox(width: 12),
        const ExamCountdownCard(),
      ],
    );
  }

  /* ──────────── ヘッダー ──────────── */
  Widget _buildHeader(BuildContext context, String today, int streak) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('お疲れさまです！',
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
      /* ───── streak バッジ ───── */
      streak > 0
          ? ScaleTransition(
          scale: _streakScale, child: StreakBadge(count: streak))
          : StreakBadge(count: 0), // ← 0 日でもグレー表示
      const SizedBox(width: 12),
      FutureBuilder<DocumentSnapshot>(
        future:
        FirebaseFirestore.instance.collection('users').doc(_uid).get(),
        builder: (ctx, snap) {
          if (snap.hasData && snap.data!.exists) {
            final url = snap.data!.get('profileImageUrl') as String;
            return CircleAvatar(radius: 20, backgroundImage: NetworkImage(url));
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
}

/* ───────── ステータスカード ───────── */
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String period;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.period,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      period,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
