// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../main.dart' show routeObserver;
import '../widgets/home_page_widgets/weekly_chart_toggle.dart';
import '../widgets/home_page_widgets/learning_now_section.dart';
import '../widgets/home_page_widgets/exam_countdown_card.dart';
import '../widgets/home_page_widgets/streak_badge.dart';
import '../utils/paywall_manager.dart'; // ★ 追加 ── Paywall 表示ロジック集約

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statsSub; // nullable

  /* ──────────── 直近 7 日分のデータ ──────────── */
  List<int> _counts = List.filled(7, 0); // answerCount
  List<int> _accuracy = List.filled(7, 0); // 正答率 (%)
  int _weekTotalAnswers = 0; // 7 日合計回答数
  int _weekAccuracyPct = 0; // 7 日総合正答率
  int _streakCount = 0; // 🔥 連続学習日数

  /* ──────────── 集計期間（週） ──────────── */
  int _weekOffset = 0; // ★ 追加: 0=今週, 1=先週, 2=先々週...

  /* ───────── LearningNow リビルド用 ───────── */
  late Key _learningNowKey;

  /* ──────────── アニメーション ──────────── */
  late final AnimationController _streakAnimCtrl;
  late final Animation<double> _streakScale;

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

    /* ───── 直近 7 日間の日次統計を監視（集計期間対応） ───── */
    _subscribeDailyStats(); // 固定7日→週オフセットで購読
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
    _statsSub?.cancel();
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

  /* ──────────── Firestore 購読（週オフセット対応） ──────────── */
  void _subscribeDailyStats() {
    _statsSub?.cancel();
    final now = DateTime.now();
    final lastDay = now.subtract(Duration(days: 7 * _weekOffset)); // 期間の最終日
    final start = DateTime(lastDay.year, lastDay.month, lastDay.day)
        .subtract(const Duration(days: 6)); // 7日間の開始日
    final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);

    _statsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('dailyStudyStats')
        .where('dateTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTimestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('dateTimestamp')
        .snapshots()
        .listen(_onDailyStats);
  }

  /* ──────────── 直近 7 日分の統計が更新された ──────────── */
  void _onDailyStats(QuerySnapshot<Map<String, dynamic>> qs) {
    final now = DateTime.now();
    final lastDay = now.subtract(Duration(days: 7 * _weekOffset));
    final List<int> counts = List.filled(7, 0);
    final List<int> corrects = List.filled(7, 0);

    for (final doc in qs.docs) {
      final data = doc.data();
      final ts = (data['dateTimestamp'] as Timestamp).toDate();
      final date = DateTime(ts.year, ts.month, ts.day);
      final diff = lastDay.difference(date).inDays; // 0:最終日, 6:開始日
      if (diff >= 0 && diff <= 6) {
        final idx = 6 - diff; // 左から開始日→最終日の順に
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

    /* ───── Duolingo 方式の連続学習日数（今週のときだけアニメ） ───── */
    int streak = 0;
    if (_weekOffset == 0) {
      final bool todayDone = counts[6] > 0;
      for (int i = todayDone ? 6 : 5; i >= 0; i--) {
        if (counts[i] > 0) {
          streak++;
        } else {
          break;
        }
      }
      if (streak > _streakCount) {
        _streakAnimCtrl.forward(from: 0.0);
      }
    } else {
      streak = _streakCount; // 過去週では変えない
    }

    setState(() {
      _counts = counts;
      _accuracy = accuracy;
      _weekTotalAnswers = totalAnswers;
      _weekAccuracyPct = accPct;
      _streakCount = streak;
    });
  }

  /* ──────────── 期間ラベル（M/d〜M/d） ──────────── */
  String _currentPeriodLabel() {
    final now = DateTime.now();
    final lastDay = now.subtract(Duration(days: 7 * _weekOffset));
    final start = DateTime(lastDay.year, lastDay.month, lastDay.day)
        .subtract(const Duration(days: 6));
    final fmt = DateFormat('M/d');
    return '${fmt.format(start)}〜${fmt.format(lastDay)}';
  }

  /* ──────────── ヘッダー用：期間移動 ──────────── */
  void _prevPeriod() {
    setState(() => _weekOffset += 1);
    _subscribeDailyStats();
  }

  void _nextPeriod() {
    if (_weekOffset == 0) return;
    setState(() => _weekOffset -= 1);
    _subscribeDailyStats();
  }

  /* ───────────────── build ───────────────── */
  @override
  Widget build(BuildContext context) {
    final periodStr = _currentPeriodLabel();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            /* ───── ヘッダー ───── */
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildHeader(context, periodStr, _streakCount),
              ),
            ),
            /* ───── ステータス行 ───── */
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 16),
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
                  weekOffset: _weekOffset, // ★ 追加：ホームの集計期間を同期
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
    // 集計期間（例: "6/23〜6/29"）
    final period = _currentPeriodLabel();

    return Row(
      children: [
        _StatCard(
          icon: Icons.cached_rounded,
          iconColor: Colors.blue[800]!, // 既存配色を踏襲
          label: '回答数',
          labelColor: Colors.black87,
          value: _weekTotalAnswers == 0 ? '-' : _weekTotalAnswers.toString(),
          period: period,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.star,
          iconColor: Colors.amber[700]!,
          labelColor: Colors.black87,
          label: '正答率',
          value: _weekTotalAnswers == 0 ? '-' : '$_weekAccuracyPct%',
          period: period,
        ),
        const SizedBox(width: 12),
        const ExamCountdownCard(),
      ],
    );
  }

  /* ──────────── ヘッダー ──────────── */
  Widget _buildHeader(BuildContext context, String period, int streak) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ホーム',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.black87)),
            const SizedBox(height: 4),
            // 期間表示（左右に chevron を配置）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_left,
                  onPressed: _prevPeriod,
                  enabled: true,
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    period,
                    textAlign: TextAlign.center, // ★ 中央寄せ
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.black87),
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.arrow_right,
                  onPressed: _nextPeriod,
                  enabled: _weekOffset > 0, // 今週のときは無効
                ),
              ],
            ),
          ],
        ),
      ),
      /* ───── streak バッジ ───── */
      streak > 0
          ? ScaleTransition(
          scale: _streakScale, child: StreakBadge(count: streak))
          : StreakBadge(count: 0), // ← 0 日でもグレー表示
      const SizedBox(width: 12),
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .get(),
        builder: (ctx, snap) {
          // フォールバック用 Avatar
          const fallback = CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage(
                'assets/default_profile_icon/default_profile_icon_v1.0.png'),
          );

          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() ?? {};
            final url = (data['profileImageUrl'] ?? '') as String;
            if (url.isNotEmpty) {
              return CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(url),
              );
            }
          }
          return fallback;
        },
      ),
    ],
  );
}

// ───────── ステータスカード ─────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor; // アイコン色
  final Color labelColor; // ラベル＆期間の文字色
  final Color valueColor; // 値の文字色
  final String label;
  final String value;
  final String period;

  const _StatCard({
    required this.icon,
    this.iconColor = Colors.grey, // デフォルトはグレー
    this.labelColor = Colors.black54, // デフォルトは既存の薄い黒
    this.valueColor = Colors.black87, // デフォルトは既存の濃い黒
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
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: labelColor),
                ),
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
                        color: valueColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      period,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: labelColor),
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.enabled = true, // デフォルト有効
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.25, // 無効時は半透明
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(
          icon,
          size: 32,
          color: Colors.black54,
        ),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
