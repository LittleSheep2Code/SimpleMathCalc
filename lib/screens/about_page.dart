import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Image.asset(
                      'assets/icon.jpg',
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Simple Math Calc',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '简单数学计算器',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: 0.8,
                  child: Text(
                    '这是一个用于求解方程和表达式的计算器应用。\n支持多种类型的数学计算，包括代数方程、表达式求值等。\n\n结果仅供参考，纯机器计算，无 AI 成分。\n\n在书写方程的时候，请勿使用中文符号，平方请使用 ^n 来表示 n 次方。\n\n理性使用，仅为辅助学习目的，过量使用有害考试成绩。',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '© 2025 LittleSheep',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Text(
                  '看看 LittleSheep 的其他作品',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.web),
                  trailing: const Icon(Icons.chevron_right),
                  title: const Text('Solar Network'),
                  subtitle: const Text('aka Solian'),
                  onTap: () => _launchUrl('https://web.solian.app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }
}
