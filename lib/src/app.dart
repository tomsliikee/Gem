import 'package:flutter/material.dart';
import 'ui/launcher_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1A73E8),
        scaffoldBackgroundColor: const Color(0xFF131314),
        useMaterial3: true,
      ),
      home: const LauncherScreen(),
    );
  }
}
