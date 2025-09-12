import 'package:flutter/material.dart';
import 'package:latext/latext.dart';
import 'package:simple_math_calc/models/calculation_step.dart';
import 'package:simple_math_calc/solver.dart';
import 'dart:math';

class CalculatorHomePage extends StatefulWidget {
  const CalculatorHomePage({super.key});

  @override
  State<CalculatorHomePage> createState() => _CalculatorHomePageState();
}

class _CalculatorHomePageState extends State<CalculatorHomePage> {
  final TextEditingController _controller = TextEditingController();
  final SolverService _solverService = SolverService();

  CalculationResult? _result;
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('方程与表达式计算器'),
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
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '输入方程或表达式',
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      hintText: '例如: 2x^2 - 8x + 6 = 0',
                    ),
                    onSubmitted: (_) => _solveEquation(),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
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
                      bottom: 4,
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
                        SelectableText(step.explanation),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 16),
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
