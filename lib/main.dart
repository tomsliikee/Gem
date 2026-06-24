import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/glassmorphic_theme.dart';
import 'presentation/widgets/dashboard_view.dart';
import 'presentation/providers/providers.dart';
import 'data/repositories/agy_process_runner.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the window manager plugin
  await windowManager.ensureInitialized();

  // Configure custom window options
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent, // Required for custom rounded borders & glassmorphism
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hides native title bar/borders for a frameless look
  );

  // Prevent flash by waiting until the window is ready to show
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        agyProcessRunnerProvider.overrideWithValue(ProcessAgyProcessRunner()),
      ],
      child: const GemApp(),
    ),
  );
}

class GemApp extends StatelessWidget {
  const GemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gem Life OS',
      debugShowCheckedModeBanner: false,
      theme: GlassmorphicTheme.darkTheme,
      home: const CustomWindowShell(
        child: DashboardView(),
      ),
    );
  }
}
