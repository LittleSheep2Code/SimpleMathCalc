import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latext/latext.dart';
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
  FlSpot? _currentTouchedPoint;
  final TextEditingController _xController = TextEditingController();
  double? _manualY;

  /// 生成函数图表的点
  ({List<FlSpot> leftPoints, List<FlSpot> rightPoints}) _generatePlotPoints(
    String expression,
    double zoomFactor,
  ) {
    try {
      // 使用solver准备函数表达式（展开因式形式）
      String functionExpr = _solverService.prepareFunctionForGraphing(
        expression,
      );

      // 如果表达式不包含 x，返回空列表
      if (!functionExpr.contains('x') && !functionExpr.contains('X')) {
        return (leftPoints: [], rightPoints: []);
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

      // 在 % 和变量或数字之间插入乘号 (如 80%x -> 80%*x)
      functionExpr = functionExpr.replaceAllMapped(
        RegExp(r'%([a-zA-Z\d])'),
        (match) => '%*${match.group(1)}',
      );

      // 解析表达式
      final parser = Parser(functionExpr);
      final expr = parser.parse();

      // 根据缩放因子动态调整范围和步长
      final range = 10.0 * zoomFactor;
      final step = max(0.01, 0.05 / zoomFactor); // 更小的步长以获得更好的分辨率

      // 生成点
      List<FlSpot> leftPoints = [];
      List<FlSpot> rightPoints = [];
      for (double i = -range; i <= range; i += step) {
        // 跳过 x = 0 以避免在 y=1/x 等函数中的奇点
        if (i.abs() < 1e-10) continue;

        try {
          // 替换变量 x 为当前值
          final substituted = expr.substitute('x', DoubleExpr(i));
          final evaluated = substituted.evaluate();

          if (evaluated is DoubleExpr) {
            final y = evaluated.value;
            if (y.isFinite && y.abs() <= 100.0) {
              if (i < 0) {
                leftPoints.add(FlSpot(i, y));
              } else {
                rightPoints.add(FlSpot(i, y));
              }
            }
          }
        } catch (e) {
          // 跳过无法计算的点
          continue;
        }
      }

      // 排序点按 x 值
      leftPoints.sort((a, b) => a.x.compareTo(b.x));
      rightPoints.sort((a, b) => a.x.compareTo(b.x));

      debugPrint(
        'Generated ${leftPoints.length} left dots and ${rightPoints.length} right dots with zoom factor $zoomFactor',
      );
      return (leftPoints: leftPoints, rightPoints: rightPoints);
    } catch (e) {
      debugPrint('Error generating plot points: $e');
      return (leftPoints: [], rightPoints: []);
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

    // Limit y range to prevent extreme values from making the chart unreadable
    const double maxYRange = 100.0;
    if (maxY > maxYRange) maxY = maxYRange;
    if (minY < -maxYRange) minY = -maxYRange;

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

  String _formatAxisValue(double value) {
    if (value.abs() < 1e-10) return "0";
    if ((value - value.roundToDouble()).abs() < 1e-10) {
      return value.round().toString();
    }
    double absVal = value.abs();
    if (absVal >= 100) return value.toStringAsFixed(0);
    if (absVal >= 10) return value.toStringAsFixed(1);
    if (absVal >= 1) return value.toStringAsFixed(2);
    if (absVal >= 0.1) return value.toStringAsFixed(3);
    return value.toStringAsFixed(4);
  }

  double? _calculateYForX(double x) {
    try {
      String functionExpr = _solverService.prepareFunctionForGraphing(
        widget.expression,
      );
      if (!functionExpr.contains('x') && !functionExpr.contains('X')) {
        return null;
      }
      functionExpr = functionExpr.replaceAll(' ', '');
      functionExpr = functionExpr.replaceAllMapped(
        RegExp(r'(\d)([a-zA-Z])'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );
      functionExpr = functionExpr.replaceAllMapped(
        RegExp(r'([a-zA-Z])(\d)'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );
      functionExpr = functionExpr.replaceAllMapped(
        RegExp(r'%([a-zA-Z\d])'),
        (match) => '%*${match.group(1)}',
      );
      final parser = Parser(functionExpr);
      final expr = parser.parse();
      final substituted = expr.substitute('x', DoubleExpr(x));
      final evaluated = substituted.evaluate();
      if (evaluated is DoubleExpr &&
          evaluated.value.isFinite &&
          !evaluated.value.isNaN) {
        return evaluated.value;
      }
    } catch (e) {
      // Handle error
    }
    return 0 / 0;
  }

  void _performCalculation() {
    final x = double.tryParse(_xController.text);
    if (x != null) {
      setState(() {
        _manualY = _calculateYForX(x);
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请输入有效的数字')));
    }
  }

  @override
  void dispose() {
    _xController.dispose();
    super.dispose();
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
                      final (:leftPoints, :rightPoints) = _generatePlotPoints(
                        widget.expression,
                        widget.zoomFactor,
                      );
                      final allPoints = [...leftPoints, ...rightPoints];
                      final bounds = _calculateChartBounds(
                        allPoints,
                        widget.zoomFactor,
                      );

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                interval: (bounds.maxY - bounds.minY) / 8,
                                getTitlesWidget: (value, meta) =>
                                    SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        _formatAxisValue(value),
                                        style: GoogleFonts.robotoFlex(),
                                      ),
                                    ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 80,
                                interval: (bounds.maxX - bounds.minX) / 10,
                                getTitlesWidget: (value, meta) => SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _formatAxisValue(value)
                                        .split('')
                                        .map(
                                          (char) => ['-', '.'].contains(char)
                                              ? Transform.rotate(
                                                  angle: pi / 2,
                                                  child: Text(
                                                    char,
                                                    style:
                                                        GoogleFonts.robotoFlex(
                                                          height: char == '.'
                                                              ? 0.7
                                                              : 0.9,
                                                        ),
                                                  ),
                                                )
                                              : Text(
                                                  char,
                                                  style: GoogleFonts.robotoFlex(
                                                    height: 0.9,
                                                  ),
                                                ),
                                        )
                                        .toList(),
                                  ),
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
                            touchCallback: (event, response) {
                              if (response != null &&
                                  response.lineBarSpots != null &&
                                  response.lineBarSpots!.isNotEmpty) {
                                setState(() {
                                  _currentTouchedPoint =
                                      response.lineBarSpots!.first;
                                });
                              }
                              // Keep the last touched point visible
                            },
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
                            if (leftPoints.isNotEmpty)
                              LineChartBarData(
                                spots: leftPoints,
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3,
                                belowBarData: BarAreaData(show: false),
                                dotData: FlDotData(show: false),
                              ),
                            if (rightPoints.isNotEmpty)
                              LineChartBarData(
                                spots: rightPoints,
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
                if (_currentTouchedPoint != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LaTexT(
                          laTeXCode: Text(
                            '\$\$x = ${_currentTouchedPoint!.x.toStringAsFixed(4)},\\quad y = ${_currentTouchedPoint!.y.toStringAsFixed(4)}\$\$',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _xController,
                        decoration: InputDecoration(
                          labelText: '输入 x 值',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onSubmitted: (_) => _performCalculation(),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _performCalculation,
                      icon: Icon(Icons.calculate_outlined),
                      tooltip: '计算 y',
                    ),
                  ],
                ),
                if (_manualY != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LaTexT(
                      laTeXCode: Text(
                        '\$\$x = ${double.parse(_xController.text).toStringAsFixed(4)},\\quad y = ${_manualY!.toStringAsFixed(4)}\$\$',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
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
