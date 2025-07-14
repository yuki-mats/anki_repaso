// lib/widgets/home_page_widgets/weekly_chart_toggle.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

enum _Metric { count, accuracy }

class WeeklyChartToggle extends StatefulWidget {
  const WeeklyChartToggle({
    super.key,
    required this.counts,
    required this.accuracy,
    required this.barHeight,
  });

  final List<int> counts;      // ダミー
  final List<int> accuracy;    // ダミー
  final double barHeight;

  @override
  State<WeeklyChartToggle> createState() => _WeeklyChartToggleState();
}

class _WeeklyChartToggleState extends State<WeeklyChartToggle> {
  /* ───────── 表示モード ───────── */
  _Metric _metric = _Metric.count;

  /* ───────── 目標値 ───────── */
  double _countMax       = 30.0;
  double _accuracyTarget = 100.0;

  /* ───────── 日次統計 ───────── */
  final List<int> _counts   = List.filled(7, 0);
  final List<int> _accuracy = List.filled(7, 0);

  /* ───────── DB 監視用 ───────── */
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statsSub;
  String? _uid;

  /* ───────── UI 定数 ───────── */
  static const _chipOffset = 16.0;
  static const _circleSize = 28.0;

  late final TooltipBehavior _tooltip;
  bool _ignoreNextTap = false;

  @override
  void initState() {
    super.initState();

    // ユーザー取得／Firestore 監視
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _userSub = FirebaseFirestore.instance
          .doc('users/$_uid')
          .snapshots()
          .listen(_onUserDoc);

      final today = DateTime.now();
      final sevenDaysAgo = today.subtract(const Duration(days: 6));
      final start = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);

      _statsSub = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('dailyStudyStats')
          .where('dateTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('dateTimestamp')
          .snapshots()
          .listen(_onStats);
    }

    // ツールチップ設定
    _tooltip = TooltipBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      shouldAlwaysShow: true,
      duration: 0,
      header: '',
      format: 'point.y',
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      color: Colors.black87,
      borderColor: Colors.white,
      borderWidth: 1,
    );
  }

  void _onUserDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final chart = ((snap.data()?['settings'] ?? {}) as Map<String, dynamic>)['chartTargets'] ?? {};
    setState(() {
      _countMax       = (chart['countMax']       as num?)?.toDouble() ?? _countMax;
      _accuracyTarget = (chart['accuracyTarget'] as num?)?.toDouble() ?? _accuracyTarget;
    });
  }

  void _onStats(QuerySnapshot<Map<String, dynamic>> snap) {
    final today = DateTime.now();
    final counts   = List<int>.filled(7, 0);
    final accuracy = List<int>.filled(7, 0);

    final Map<String, Map<String, dynamic>> m = {
      for (var doc in snap.docs)
        (doc.data()['dateTimestamp'] as Timestamp)
            .toDate()
            .toLocal()
            .toIso8601String()
            .substring(0, 10): doc.data(),
    };

    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: 6 - i));
      final key = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final data = m[key];
      if (data != null) {
        final ans = (data['answerCount']  ?? 0) as int;
        final cor = (data['correctCount'] ?? 0) as int;
        counts[i]   = ans;
        accuracy[i] = ans == 0 ? 0 : ((cor / ans) * 100).round();
      }
    }

    setState(() {
      for (int i = 0; i < 7; i++) {
        _counts[i]   = counts[i];
        _accuracy[i] = accuracy[i];
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 日付ラベル準備
    final today    = DateTime.now();
    final dateList = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    const weekDay  = ['月', '火', '水', '木', '金', '土', '日'];
    final labels   = dateList.map((d) => weekDay[d.weekday - 1]).toList();

    // 値・ターゲット・軸最大値計算
    final values    = _metric == _Metric.count ? _counts : _accuracy;
    final target    = _metric == _Metric.count ? _countMax : _accuracyTarget;
    final axisMax   = target * 1.1;
    final unitLabel = _metric == _Metric.count ? '回答数' : '正答率';
    final topLabel  = _metric == _Metric.count
        ? '${_countMax.toInt()}問'
        : '${_accuracyTarget.toInt()}%';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        if (_ignoreNextTap) {
          _ignoreNextTap = false;
        } else {
          _tooltip.hide();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topRight,
        children: [
          // 棒グラフ
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16 + _chipOffset + 16, 16, 52),
            height: widget.barHeight + 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SfCartesianChart(
              tooltipBehavior: _tooltip,
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(isVisible: false),
              primaryYAxis: NumericAxis(
                isVisible: true,
                labelStyle: const TextStyle(color: Colors.transparent),
                minimum: 0,
                maximum: axisMax,
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                axisLabelFormatter: (AxisLabelRenderDetails details) {
                  return ChartAxisLabel('', null); // ← ここで空文字を返す
                },
                plotBands: <PlotBand>[
                  PlotBand(
                    isVisible: true,
                    start: target,
                    end: target,
                    borderColor: Colors.grey.shade300,
                    borderWidth: 1,
                    dashArray: <double>[6, 8],
                    color: Colors.transparent,
                  ),
                ],
              ),
              series: <CartesianSeries<_ChartData, String>>[
                ColumnSeries<_ChartData, String>(
                  enableTooltip: true,
                  onPointTap: (ChartPointDetails d) {
                    if (d.seriesIndex != null && d.pointIndex != null) {
                      _tooltip.showByIndex(d.seriesIndex!, d.pointIndex!);
                      _ignoreNextTap = true;
                    }
                  },
                  dataSource: List<_ChartData>.generate(
                    7, (i) => _ChartData(labels[i], values[i]),
                  ),
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.value,
                  width: 0.6,
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
              onTooltipRender: (TooltipArgs args) {
                // args.text には 'point.y' の値（数値）が入っている
                args.text = _metric == _Metric.count       // 回答数モード
                    ? '${args.text} 回'
                    : '${args.text}%';                     // 正答率モード
              },
            ),
          ),

          // カスタム軸（日付サークル）
          Positioned(
            bottom: 8,
            left: 20,
            right: 17,
            child: Row(
              children: List.generate(7, (i) {
                final d = dateList[i];
                final achieved = values[i] >= target;
                final circleColor = values[i] == 0
                    ? Colors.grey.shade400
                    : (achieved ? const Color(0xFF4CAF50) : const Color(0xFFF44336));
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: i == 6 ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      Container(
                        width: _circleSize,
                        height: _circleSize,
                        decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          d.day.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // 目標値チップ
          Positioned(
            top: _chipOffset,
            left: 16,
            child: GestureDetector(
              onTap: () => _showGoalEditModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(.05), borderRadius: BorderRadius.circular(8)),
                child: Text(topLabel, style: const TextStyle(fontSize: 10, color: Colors.black87)),
              ),
            ),
          ),

          // 縦軸切替チップ
          Positioned(
            top: _chipOffset,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() {
                _metric = _metric == _Metric.count ? _Metric.accuracy : _Metric.count;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(.05), borderRadius: BorderRadius.circular(12)),
                child: Text(unitLabel, style: const TextStyle(fontSize: 10, color: Colors.black87)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 目標値編集モーダル
  // 目標値編集モーダル
  void _showGoalEditModal(BuildContext ctx) {
    final isCount = _metric == _Metric.count;
    double temp   = isCount ? _countMax : _accuracyTarget;

    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCount ? '回答数（目標）' : '正答率（目標）',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            /* ───────── 入力フィールド + 単位 ───────── */
            Row(
              children: [
                /* TextField（幅は出来るだけ広く取る） */
                Expanded(
                  child: TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    cursorColor: Colors.blue[800],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.blue[800]!)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.blue[800]!)),
                      isDense: true,
                      hintText: isCount ? '30' : '85',             // 統一
                      hintStyle: TextStyle(color: Colors.grey[400]),
                    ),
                    onChanged: (v) => temp = double.tryParse(v) ?? temp,
                  ),
                ),
                const SizedBox(width: 4),
                /* 単位ラベル */
                Text(
                  isCount ? '回' : '%',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 12),
            /* ───────── 保存ボタン ───────── */
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                onPressed: () async {
                  setState(() {
                    if (isCount) {
                      _countMax = temp;
                    } else {
                      _accuracyTarget = temp;
                    }
                  });
                  if (_uid != null) {
                    await FirebaseFirestore.instance
                        .doc('users/$_uid')
                        .set({
                      'settings': {
                        'chartTargets': {
                          'countMax': _countMax,
                          'accuracyTarget': _accuracyTarget,
                        },
                      },
                    }, SetOptions(merge: true));
                  }
                  Navigator.of(context).pop();
                },
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// データモデル
class _ChartData {
  final String label;
  final int    value;
  _ChartData(this.label, this.value);
}
