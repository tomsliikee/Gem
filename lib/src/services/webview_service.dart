import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

class WebviewService {
  Webview? _webviewWindow;

  bool get hasActiveWindow => _webviewWindow != null;

  Future<void> launchGemini({
    required VoidCallback onWindowCreated,
    required VoidCallback onWindowClosed,
    required void Function(Object error, StackTrace st) onError,
  }) async {
    try {
      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          title: "Gemini",
          titleBarTopPadding: 0,
        ),
      );

      // Set user agent suffix to bypass Google blocks (appends Chrome/Safari to the WebKit UA)
      // This is crucial for login functionality to remain working.
      await webview.setApplicationNameForUserAgent(" Chrome/122.0.0.0 Safari/537.36");

      webview.setBrightness(Brightness.dark);
      webview.launch("https://gemini.google.com/app");
      
      _webviewWindow = webview;
      onWindowCreated();

      webview.onClose.then((_) {
        _webviewWindow = null;
        onWindowClosed();
        // Terminate the entire application cleanly when the webview is closed
        exit(0);
      });
    } catch (e, st) {
      onError(e, st);
    }
  }

  void closeWindow() {
    _webviewWindow?.close();
  }
}
