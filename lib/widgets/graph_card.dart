import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:simple_math_calc/parser.dart';
import 'package:simple_math_calc/calculator.dart';
import 'package:simple_math_calc/solver.dart';
import 'dart:math';

class GraphCard extends StatefulWidget {
  final String expression;
  final double zoomFactor;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const GraphCard({
    super.key,
    required this.expression,
    required this.zoomFactor,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<GraphCard> createState() => _GraphCardState();
}

class _GraphCardState extends State<GraphCard> {
  final SolverService _solverService = SolverService();

  /// 生成函数图表的点
  List<FlSpot> _generatePlotPoints(String expression, double zoomFactor) {
    try {
      // 使用solver准备函数表达式（展开因式形式）
      String functionExpr = _solverService.prepareFunctionForGraphing(
        expression,
      );

      // 如果表达式不包含 x，返回空列表
      if (!functionExpr.contains('x') && !functionExpr.contains('X')) {
        return [];
      }

      // 预处理表达式，确保格式正确
      functionExpr = functionExpr.replaceAll(' ', '');

      // 在数字和变量之间插入乘号
      functionExpr = functionExpr.replaceAllMapped(
        RegExp(r'(\d)([a-zA-Z])'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );

      // 在变量和数字之间插入乘号 (如 x2 -> x*2)
      functionExpr = functionExpr.replaceAllMapped(
        RegExp(r'([a-zA-Z])(\d)'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );

      // 解析表达式
      final parser = Parser(functionExpr);
      final expr = parser.parse();

      // 根据缩放因子动态调整范围和步长
      final range = 10.0 * zoomFactor;
      final step = max(0.05, 0.2 / zoomFactor); // 缩放时步长更小，放大时步长更大

      // 生成点
      List<FlSpot> points = [];
      for (double i = -range; i <= range; i += step) {
        try {
          // 替换变量 x 为当前值
          final substituted = expr.substitute('x', DoubleExpr(i));
          final evaluated = substituted.evaluate();

          if (evaluated is DoubleExpr) {
            final y = evaluated.value;
            if (y.isFinite && !y.isNaN) {
              points.add(FlSpot(i, y));
            }
          }
        } catch (e) {
          // 跳过无法计算的点
          continue;
        }
      }

      // 如果没有足够的点，返回空列表
      if (points.length < 2) {
        debugPrint('Generated ${points.length} dots');
        return [];
      }

      // 排序点按 x 值
      points.sort((a, b) => a.x.compareTo(b.x));

      debugPrint(
        'Generated ${points.length} dots with zoom factor $zoomFactor',
      );
      return points;
    } catch (e) {
      debugPrint('Error generating plot points: $e');
      return [];
    }
  }

  /// 计算图表的数据范围
  ({double minX, double maxX, double minY, double maxY}) _calculateChartBounds(
    List<FlSpot> points,
    double zoomFactor,
  ) {
    if (points.isEmpty) {
      return (
        minX: -10 * zoomFactor,
        maxX: 10 * zoomFactor,
        minY: -50 * zoomFactor,
        maxY: 50 * zoomFactor,
      );
    }

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final point in points) {
      minX = min(minX, point.x);
      maxX = max(maxX, point.x);
      minY = min(minY, point.y);
      maxY = max(maxY, point.y);
    }

    // 添加边距
    final xPadding = (maxX - minX) * 0.1;
    final yPadding = (maxY - minY) * 0.1;

    return (
      minX: minX - xPadding,
      maxX: maxX + xPadding,
      minY: minY - yPadding,
      maxY: maxY + yPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '函数图像',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: widget.onZoomIn,
                          icon: Icon(Icons.zoom_in),
                          tooltip: '放大',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: widget.onZoomOut,
                          icon: Icon(Icons.zoom_out),
                          tooltip: '缩小',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 340,
                  child: Builder(
                    builder: (context) {
                      final points = _generatePlotPoints(
                        widget.expression,
                        widget.zoomFactor,
                      );
                      final bounds = _calculateChartBounds(
                        points,
                        widget.zoomFactor,
                      );

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 80,
                                getTitlesWidget: (value, meta) =>
                                    SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(value.toStringAsFixed(2)),
                                    ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (value, meta) =>
                                    SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(value.toStringAsFixed(2)),
                                    ),
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    'x = ${spot.x.toStringAsFixed(2)}\ny = ${spot.y.toStringAsFixed(2)}',
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: points,
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 3,
                              belowBarData: BarAreaData(show: false),
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          minX: bounds.minX,
                          maxX: bounds.maxX,
                          minY: bounds.minY,
                          maxY: bounds.maxY,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
