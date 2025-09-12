import 'package:flutter/material.dart';
import 'package:latext/latext.dart';
import 'package:simple_math_calc/models/calculation_step.dart';
import 'package:simple_math_calc/solver_service.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '方程计算器',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CalculatorHomePage(),
    );
  }
}

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
      appBar: AppBar(title: const Text('方程与表达式计算器')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '输入方程或表达式',
                hintText: '例如: 2x^2 - 8x + 6 = 0',
              ),
              onSubmitted: (_) => _solveEquation(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _solveEquation, child: const Text('计算')),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _result == null
                  ? const Center(child: Text('请输入方程开始计算'))
                  : buildResultView(_result!),
            ),
          ],
        ),
      ),
    );
  }

  // 构建结果展示视图
  Widget buildResultView(CalculationResult result) {
    return ListView(
      children: [
        ...result.steps.map(
          (step) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(step.explanation),
                  const SizedBox(height: 8),
                  Center(child: LaTexT(laTeXCode: Text(step.formula))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "最终答案:",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                LaTexT(laTeXCode: Text(result.finalAnswer)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
