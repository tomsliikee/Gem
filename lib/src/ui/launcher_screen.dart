import 'package:flutter/material.dart';
import '../services/webview_service.dart';
import 'components/app_logo.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  bool _isLaunching = true;
  final WebviewService _webviewService = WebviewService();

  @override
  void initState() {
    super.initState();
    // Auto-launch the webview immediately
    _launch();
  }

  Future<void> _launch() async {
    // Ensure we show loading state safely if re-launched
    if (!_isLaunching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _isLaunching = true; });
      });
    }

    await _webviewService.launchGemini(
      onWindowCreated: () {
        if (!mounted) return;
        setState(() {
          _isLaunching = false;
        });
      },
      onWindowClosed: () {
        if (!mounted) return;
        setState(() {}); // refresh UI
      },
      onError: (error, st) {
        debugPrint('Error launching webview: $error\n$st');
        if (!mounted) return;
        setState(() {
          _isLaunching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching Gemini: $error')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const AppLogo(),
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
                  _webviewService.hasActiveWindow 
                      ? 'Gemini is running in a separate window.' 
                      : 'Google Gemini Desktop Launcher',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 48),
                _buildActionArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (_isLaunching) {
      return const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
          ),
          SizedBox(height: 16),
          Text(
            'Launching WebView...',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      );
    } else if (_webviewService.hasActiveWindow) {
      return OutlinedButton.icon(
        onPressed: () {
          _webviewService.closeWindow();
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
      );
    } else {
      return ElevatedButton.icon(
        onPressed: _launch,
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
      );
    }
  }
}
