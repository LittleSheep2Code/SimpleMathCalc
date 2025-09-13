import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late final FocusNode _focusNode;

  CalculationResult? _result;
  bool _isLoading = false;
  bool _isInputFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isInputFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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

  void _insertSymbol(String symbol) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, symbol);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + symbol.length,
    );
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
                    focusNode: _focusNode,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '输入方程或表达式',
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      hintText: '例如: 2x^2 - 8x + 6 = 0',
                    ),
                    keyboardType: TextInputType.number,
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
          if (_isInputFocused) _buildToolbar(),
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

  Widget _buildToolbar() {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              spacing: 16,
              children: [
                Expanded(
                  child: Tooltip(
                    message: '左括号',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('('),
                      child: Text('(', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '右括号',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol(')'),
                      child: Text(')', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '幂符号',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('^'),
                      child: Text('^', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '平方',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('^2'),
                      child: Text('^2', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '未知数',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('x'),
                      child: Text('x', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              spacing: 16,
              children: [
                Expanded(
                  child: Tooltip(
                    message: '加法',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('+'),
                      child: Text('+', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '减法',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('-'),
                      child: Text('-', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '乘法',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('*'),
                      child: Text('*', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '除法',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('/'),
                      child: Text('/', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '小数点',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('.'),
                      child: Text('.', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: '等于号',
                    child: FilledButton.tonal(
                      onPressed: () => _insertSymbol('='),
                      child: Text('=', style: GoogleFonts.robotoMono()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.keyboard_hide),
                    onPressed: () => _focusNode.unfocus(),
                    label: Text('收起键盘'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
