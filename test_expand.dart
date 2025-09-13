import 'lib/solver.dart';

void main() {
  final solver = SolverService();

  // Test the problematic case
  final input = '(x+8)(x+1)=-12';
  print('Input: $input');

  try {
    final result = solver.solve(input);
    print('Result: ${result.finalAnswer}');
    print('Steps:');
    for (final step in result.steps) {
      print('Step ${step.stepNumber}: ${step.title}');
      print('  Formula: ${step.formula}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
