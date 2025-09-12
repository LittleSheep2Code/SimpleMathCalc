// 用来描述计算过程中的每一步
class CalculationStep {
  final int stepNumber; // 步骤编号，例如：1, 2, 3...
  final String title; // 这一步的标题，例如："整理方程"
  final String explanation; // 对这一步的具体文字描述
  final String formula; // 这一步得到的数学式子 (可以使用 LaTeX 格式)

  CalculationStep({
    required this.stepNumber,
    required this.title,
    required this.explanation,
    required this.formula,
  });
}

// 用来封装最终的计算结果
class CalculationResult {
  final List<CalculationStep> steps;
  final String finalAnswer;

  CalculationResult({required this.steps, required this.finalAnswer});
}
