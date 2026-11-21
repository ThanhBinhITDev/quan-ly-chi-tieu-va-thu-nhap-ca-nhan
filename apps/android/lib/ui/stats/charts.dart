import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/domain/models.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Kiểu hiển thị cho phần thống kê theo danh mục.
enum CategoryChartStyle { donut, bars }

/// Chọn kiểu biểu đồ. Giữ trong widget riêng để trạng thái không bị mất khi
/// danh sách cuộn.
class ChartStyleSwitcher extends StatelessWidget {
  const ChartStyleSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CategoryChartStyle value;
  final ValueChanged<CategoryChartStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CategoryChartStyle>(
      segments: const [
        ButtonSegment(
          value: CategoryChartStyle.donut,
          icon: Icon(LucideIcons.chartPie, size: 16),
          label: Text('Vòng'),
        ),
        ButtonSegment(
          value: CategoryChartStyle.bars,
          icon: Icon(LucideIcons.chartColumn, size: 16),
          label: Text('Cột'),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

/// Biểu đồ đường có vùng tô màu cho chi tiêu theo ngày.
///
/// Dùng `LineChart` thay cho các thanh tiến trình cũ vì đường liền cho thấy
/// xu hướng (tăng/giảm giữa các ngày) rõ hơn nhiều so với danh sách thanh rời.
class DailyTrendChart extends StatelessWidget {
  const DailyTrendChart({super.key, required this.daily});

  final List<DayTotal> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxAmount = daily.fold<int>(
      1,
      (previous, item) => item.amount > previous ? item.amount : previous,
    );
    // Trục Y "đẹp": làm tròn lên bội số để nhãn không ra số lẻ khó đọc.
    final yMax = _niceCeiling(maxAmount);
    final spots = [
      for (var i = 0; i < daily.length; i++)
        FlSpot(i.toDouble(), daily[i].amount.toDouble()),
    ];

    return Semantics(
      label: '${AppStrings.dailyTrend}: '
          '${daily.map((d) => '${d.label} ${formatMoney(d.amount)}').join(', ')}',
      child: SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (daily.length - 1).toDouble().clamp(1, double.infinity),
            minY: 0,
            maxY: yMax,
            // Đường lưới ngang mảnh, chỉ 4 mức để không rối.
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yMax / 4,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.divider,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: yMax / 4,
                  getTitlesWidget: (value, meta) {
                    if (value <= 0) return const SizedBox.shrink();
                    return Text(
                      formatMoneyShort(value.toInt()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: _labelInterval(daily.length),
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= daily.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        daily[index].label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItems: (touched) => [
                  for (final spot in touched)
                    LineTooltipItem(
                      '${daily[spot.x.round()].label}\n'
                      '${formatMoney(spot.y.toInt())}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.28,
                preventCurveOverShooting: true,
                barWidth: 2.6,
                color: AppColors.primary,
                dotData: FlDotData(
                  show: daily.length <= 12,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.surface,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  /// Nhãn trục X thưa dần khi có nhiều ngày, tránh chữ chồng nhau.
  double _labelInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    return (count / 6).ceilToDouble();
  }

  /// Làm tròn trục lên 1/2/5 × 10^n gần nhất.
  double _niceCeiling(int value) {
    if (value <= 0) return 1000;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
    final normalized = value / magnitude;
    final step = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 5
                ? 5
                : 10;
    return (step * magnitude).toDouble();
  }
}

/// Biểu đồ cột ngang theo danh mục — đọc được cả khi tên danh mục dài.
class CategoryBarChart extends StatelessWidget {
  const CategoryBarChart({super.key, required this.categories});

  final List<CategoryTotal> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(0, (sum, item) => sum + item.amount);
    final maxAmount = categories.fold<int>(
      1,
      (previous, item) => item.amount > previous ? item.amount : previous,
    );

    return Column(
      children: [
        for (var i = 0; i < categories.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _CategoryBar(
              name: categories[i].name,
              amount: categories[i].amount,
              share: total == 0 ? 0 : categories[i].amount / total,
              ratio: categories[i].amount / maxAmount,
              color:
                  AppColors.chartPalette[i % AppColors.chartPalette.length],
            ),
          ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.amount,
    required this.share,
    required this.ratio,
    required this.color,
  });

  final String name;
  final int amount;
  final double share;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name: ${formatMoney(amount)}, ${(share * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatMoney(amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              SizedBox(
                width: 40,
                child: Text(
                  '${(share * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Cột mọc dần từ trái để mắt theo được thứ tự lớn → nhỏ.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 9,
                backgroundColor: AppColors.neutralSoft,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
