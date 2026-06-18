import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'src/app.dart';

void main(List<String> args) {
  // Required setup for desktop_webview_window.
  // This intercepts the webview processes spawned by the plugin.
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
