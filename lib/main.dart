import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';

final GoRouter _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())],
);

void main() async {
  runApp(const CalcApp());
}

class CalcApp extends StatelessWidget {
  const CalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '方程计算器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: GoogleFonts.notoSerifScTextTheme(
          Theme.of(context).textTheme, // Inherit existing text theme
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        textTheme: GoogleFonts.notoSerifScTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
