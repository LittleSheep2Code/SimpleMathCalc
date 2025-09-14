import 'package:flutter/material.dart';
import 'package:latext/latext.dart';
import 'package:simple_math_calc/models/calculation_step.dart';
import 'package:simple_math_calc/solver.dart';
import 'package:simple_math_calc/widgets/graph_card.dart';
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
  bool _isFunctionMode = false;
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

  void _solveEquation() {
    if (_controller.text.isEmpty) {
      return;
    }

    final input = _controller.text.trim();
    final normalizedInput = input.replaceAll(' ', '');
    if (normalizedInput.toLowerCase().startsWith('y=')) {
      setState(() {
        _isFunctionMode = true;
        _result = null;
      });
      return;
    }

    setState(() {
      _isFunctionMode = false;
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
                : _isFunctionMode
                ? GraphCard(
                    expression: _controller.text,
                    zoomFactor: _zoomFactor,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                  )
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
      ],
    );
  }
}
