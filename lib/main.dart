import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

void main(List<String> args) {
  // Required setup for desktop_webview_window.
  // This intercepts the webview processes spawned by the plugin.
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

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

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  bool _isLaunching = false;
  Webview? _webviewWindow;

  @override
  void initState() {
    super.initState();
    // Auto-launch the webview right after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchGemini();
    });
  }

  Future<void> _launchGemini() async {
    if (_isLaunching) return;
    setState(() {
      _isLaunching = true;
    });

    try {
      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          title: "Gemini",
          titleBarTopPadding: 0,
        ),
      );

      // Set user agent suffix to bypass Google blocks (appends Chrome/Safari to the WebKit UA)
      await webview.setApplicationNameForUserAgent(" Chrome/122.0.0.0 Safari/537.36");

      webview.setBrightness(Brightness.dark);
      webview.launch("https://gemini.google.com/app");
      
      setState(() {
        _webviewWindow = webview;
        _isLaunching = false;
      });

      // Terminate the entire application cleanly when the webview is closed
      webview.onClose.then((_) {
        SystemNavigator.pop();
      });
    } catch (e) {
      setState(() {
        _isLaunching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching Gemini: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveWindow = _webviewWindow != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E24), Color(0xFF131314)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x224285F4),
                        blurRadius: 25,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white10,
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              size: 60,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Gem',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasActiveWindow 
                      ? 'Gemini is running in a separate window.' 
                      : 'Google Gemini Desktop Launcher',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 48),
                if (_isLaunching) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Launching WebView...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ] else if (hasActiveWindow) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      _webviewWindow?.close();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close Gemini Window'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _launchGemini,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Open Gemini'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
