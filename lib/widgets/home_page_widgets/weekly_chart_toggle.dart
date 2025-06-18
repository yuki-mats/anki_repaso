import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// 週間棒グラフ（縦軸トグル + 単タップで値表示、回答数=最大可変・正答率=目標可変）
enum _Metric { count, accuracy }

class WeeklyChartToggle extends StatefulWidget {
  const WeeklyChartToggle({
    super.key,
    required this.counts,
    required this.accuracy,
    required this.barHeight,
  });

  final List<int> counts;      // 回答数（0～_countMax）
  final List<int> accuracy;    // 正答率（0～100）
  final double barHeight;

  @override
  State<WeeklyChartToggle> createState() => _WeeklyChartToggleState();
}

class _WeeklyChartToggleState extends State<WeeklyChartToggle> {
  _Metric _metric = _Metric.count;

  // ── ユーザーが変更できる 2 つの目標値 ──
  double _countMax       = 30.0;  // 回答数目標
  double _accuracyTarget = 100.0; // 正答率目標

  static const _chipOffset = 16.0;   // チップとバーの間隔（px）
  late TooltipBehavior _tooltip;

  @override
  void initState() {
    super.initState();
    _tooltip = TooltipBehavior(
      enable: true,
      header: '',
      format: 'point.y',
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      color: Colors.black87,
      borderColor: Colors.white,
      borderWidth: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ───────── 曜日ラベルと値を「今日」を右端に回転 ─────────
    const baseLabels = ['月', '火', '水', '木', '金', '土', '日'];
    final int offset = DateTime.now().weekday % 7; // 月:1→1, …, 日:7→0
    final List<String> labels = List.generate(7, (i) => baseLabels[(i + offset) % 7]);
    final List<int> rawValues =
    _metric == _Metric.count ? widget.counts : widget.accuracy;
    final List<int> values =
    List.generate(7, (i) => rawValues[(i + offset) % 7]);

    final String todayLabel = labels[6]; // 右端（今日）のラベル
    const TextStyle normalStyle = TextStyle(color: Colors.black54, fontSize: 12);
    const TextStyle highlightStyle = TextStyle(
      color: Color(0xFF2196F3), // グラフと合わせたアクセントカラー
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
    // ────────────────────────────────────────────

    // ── ラベル & Y 軸設定 ──
    final double maxVal    = _metric == _Metric.count ? _countMax : _accuracyTarget;
    final String unitLabel = _metric == _Metric.count ? '回答数' : '正答率';
    final String topLabel  = _metric == _Metric.count
        ? '${_countMax.toInt()}問'
        : '${_accuracyTarget.toInt()}%';

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topRight,
      children: [
        // ───── 棒グラフ本体 ─────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16 + _chipOffset + 16, 16, 16),
          height: widget.barHeight + 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SfCartesianChart(
            tooltipBehavior: _tooltip,
            margin: EdgeInsets.zero,
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              labelStyle: normalStyle,
              axisLine: const AxisLine(width: 0),
              majorGridLines: const MajorGridLines(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              // ── 今日のラベルだけスタイル上書き ──
              axisLabelFormatter: (AxisLabelRenderDetails args) {
                return ChartAxisLabel(
                  args.text,
                  args.text == todayLabel ? highlightStyle : normalStyle,
                );
              },
            ),
            primaryYAxis: NumericAxis(
              isVisible: false,
              minimum: 0,
              maximum: maxVal,
              majorGridLines: MajorGridLines(color: Colors.grey.shade200, width: 1),
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
            ),
            series: <CartesianSeries<_ChartData, String>>[
              ColumnSeries<_ChartData, String>(
                enableTooltip: true,
                dataSource: List<_ChartData>.generate(
                  7, (i) => _ChartData(labels[i], values[i]),
                ),
                xValueMapper: (d, _) => d.day,
                yValueMapper: (d, _) => d.value,
                width: 0.6,
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
        ),

        // ───── 最大値 / 目標値チップ ─────
        Positioned(
          top: _chipOffset,
          left: 16,
          child: GestureDetector(
            onTap: () => _showGoalEditModal(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(topLabel, style: const TextStyle(fontSize: 10, color: Colors.black87)),
            ),
          ),
        ),

        // ───── 縦軸切替チップ ─────
        Positioned(
          top: _chipOffset,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() {
              _metric = _metric == _Metric.count ? _Metric.accuracy : _Metric.count;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(unitLabel, style: const TextStyle(fontSize: 10, color: Colors.black87)),
            ),
          ),
        ),
      ],
    );
  }

  /* ────────────────────────────────
   * 目標値編集モーダル（回答数 or 正答率）
   * ──────────────────────────────── */
  void _showGoalEditModal(BuildContext ctx) {
    final bool isCountMode = _metric == _Metric.count;
    double temp = isCountMode ? _countMax : _accuracyTarget;

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
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCountMode ? '目標回答数を設定' : '目標正答率を設定',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              cursorColor: Colors.blueAccent,
              decoration: InputDecoration(
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                isDense: true,
                hintText: isCountMode ? '例: 30' : '例: 85',
              ),
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null) {
                  if (isCountMode && n >= 1) temp = n;
                  if (!isCountMode && n >= 1 && n <= 100) temp = n;
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (isCountMode) {
                      _countMax = temp;
                    } else {
                      _accuracyTarget = temp;
                    }
                  });
                  Navigator.of(context).pop();
                },
                child: const Text(
                  '決定',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String day;
  final int value;
  _ChartData(this.day, this.value);
}
