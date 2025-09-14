import 'package:flutter/material.dart';
import 'package:latext/latext.dart';
import 'package:simple_math_calc/models/calculation_step.dart';
import 'package:simple_math_calc/solver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:simple_math_calc/calculator.dart';
import 'package:simple_math_calc/parser.dart';
import 'dart:math';

class CalculatorHomePage extends StatefulWidget {
  const CalculatorHomePage({super.key});

  @override
  State<CalculatorHomePage> createState() => _CalculatorHomePageState();
}

class _CalculatorHomePageState extends State<CalculatorHomePage> {
  final TextEditingController _controller = TextEditingController();
  final SolverService _solverService = SolverService();
  late final FocusNode _focusNode;

  CalculationResult? _result;
  bool _isLoading = false;
  double _zoomFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  /// 生成函数图表的点
  List<FlSpot> _generatePlotPoints(String expression, double zoomFactor) {
    try {
      // 如果是方程，取左边作为函数
      String functionExpr = expression;
      if (expression.contains('=')) {
        functionExpr = expression.split('=')[0].trim();
      }

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

  void _solveEquation() {
    if (_controller.text.isEmpty) {
      return;
    }
    setState(() {
      _isLoading = true;
      _result = null; // 清除上次结果
    });

    try {
      // 调用核心服务来解决问题
      final result = _solverService.solve(_controller.text);
      setState(() {
        _result = result;
      });
    } catch (e) {
      // 错误处理
      setState(() {
        _result = CalculationResult(
          steps: [],
          finalAnswer: "错误: ${e.toString()}",
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomFactor = (_zoomFactor * 0.8).clamp(0.1, 10.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomFactor = (_zoomFactor * 1.25).clamp(0.1, 10.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('计算器'),
        centerTitle: false,
        leading: const Icon(Icons.calculate_outlined),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '输入方程或表达式',
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      hintText: '例如: 2x^2 - 8x + 6 = 0',
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    onSubmitted: (_) => _solveEquation(),
                  ),
                ),
                IconButton(
                  onPressed: _solveEquation,
                  icon: Icon(Icons.play_arrow),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _result == null
                ? const Center(child: Text('请输入方程开始计算'))
                : buildResultView(_result!),
          ),
        ],
      ),
    );
  }

  // 构建结果展示视图
  Widget buildResultView(CalculationResult result) {
    return ListView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
      ),
      children: [
        ...result.steps.map(
          (step) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 16,
                      top: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        if (!step.explanation.contains(r'$'))
                          SelectableText(
                            step.explanation,
                            textAlign: TextAlign.center,
                          )
                        else
                          LaTexT(
                            laTeXCode: Text(
                              step.explanation,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Center(
                          child: LaTexT(
                            laTeXCode: Text(
                              step.formula,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: -8,
                    top: -8,
                    child: Transform.rotate(
                      angle: pi / -5,
                      child: Opacity(
                        opacity: 0.8,
                        child: Badge(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          textColor: Theme.of(context).colorScheme.onPrimary,
                          label: Text(
                            step.stepNumber.toString(),
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                Text(
                  "最终答案",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                LaTexT(
                  laTeXCode: Text(
                    result.finalAnswer,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                          onPressed: _zoomIn,
                          icon: Icon(Icons.zoom_in),
                          tooltip: '放大',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: _zoomOut,
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
                        _controller.text,
                        _zoomFactor,
                      );
                      final bounds = _calculateChartBounds(points, _zoomFactor);

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
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
