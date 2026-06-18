# Gem Architecture Guide: An Introduction to OOP and Desktop Wrappers

Welcome! If you are new to programming, looking at a project with multiple directories, Dart code, and C++ source files might feel a bit overwhelming. Don't worry! This guide is written to break down exactly how this application works, show you the entire codebase, and explain the core concepts of **Object-Oriented Programming (OOP)** that tie everything together.

---

## 🛠️ The Architecture: How Gem Works

Most desktop wrappers are just a web browser stripped of its address bar and buttons, rendering a webpage inside a window. In Gem, we have two layers:

1. **The Native Layer (C++)**: This layer starts up when you launch the app. It talks to the operating system (Linux or Windows) to create the window frame. To make our app look professional, we modified the C++ code to keep the launcher window invisible.
2. **The Flutter/Dart Layer**: This runs inside the native window. It manages the app startup, initializes the plugin, and loads the Gemini website in a system-provided browser instance (a "WebView").

---

## 🧠 Core OOP Concepts Explained

Object-Oriented Programming (OOP) is a programming style based on **Objects** (data structures containing properties and methods) and **Classes** (blueprints used to create those objects). Here are the primary concepts used in this project:

### 1. Classes and Objects
A **Class** is like a blueprint for a house. An **Object** (or instance) is the actual house built from that blueprint.
* **Example in our code:** `MyApp` and `LauncherScreen` are classes. When Flutter starts the app, it creates instances (objects) of these classes to render them on your screen.

### 2. Inheritance
Inheritance allows a class to inherit properties and methods from another class. This prevents us from writing the same code over and over again.
* **Example in our code:** `class MyApp extends StatelessWidget`. The `extends` keyword tells Dart that `MyApp` inherits all the layout and window properties of Flutter's built-in `StatelessWidget` class.

### 3. State Management (Stateful vs. Stateless)
In Flutter, widgets are the building blocks of the UI.
* **StatelessWidget:** A static widget that never changes once built (e.g. `MyApp`).
* **StatefulWidget:** A dynamic widget that can change its UI in response to user actions or data changes (e.g. `LauncherScreen`). It has a companion class (`_LauncherScreenState`) that holds the "State" (the data).

### 4. Callbacks and Event Listeners
A callback is a function passed as an argument to another function, which is executed when a specific event occurs.
* **Example in our code:** The window closing handler. When the user clicks the "X" button on the window, the C++ code receives a window-close signal and triggers a C++ callback function (`exit(0)`) to shut down the process instantly.

---

## 💻 Code Walkthrough: Dart (The UI & WebView)

Here is the entire code for [lib/main.dart](file:///home/toms/projects/Gem/lib/main.dart).

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

void main(List<String> args) {
  // 1. Required setup for desktop_webview_window.
  // The plugin spawns helper threads and subprocesses. 
  // If the arguments match the helper process, it intercepts and runs them.
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// MyApp inherits from StatelessWidget because the configuration of the root app
// (theme, title, routes) never changes during runtime.
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
        scaffoldBackgroundColor: const Color(0xFF131314), // Matches Gemini theme
        useMaterial3: true,
      ),
      home: const LauncherScreen(),
    );
  }
}

// LauncherScreen is a StatefulWidget because the UI needs to change based on
// whether the webview is currently launching, open, or closed.
class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

// The State class containing variables that change during the app's lifetime.
class _LauncherScreenState extends State<LauncherScreen> {
  bool _isLaunching = false;   // True when the browser window is opening
  Webview? _webviewWindow;      // Reference to the active browser window object

  @override
  void initState() {
    super.initState();
    // This callback runs immediately after the widget is drawn on the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchGemini();
    });
  }

  // Opens the browser window
  Future<void> _launchGemini() async {
    if (_isLaunching) return;
    setState(() {
      _isLaunching = true; // Updates the UI to show a loading indicator
    });

    try {
      // Create Configuration is a class object that defines window parameters
      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          title: "Gemini",
          titleBarTopPadding: 0,
        ),
      );

      // Append Chrome strings to the user agent to prevent Google login blocks
      await webview.setApplicationNameForUserAgent(" Chrome/122.0.0.0 Safari/537.36");

      webview.setBrightness(Brightness.dark);
      webview.launch("https://gemini.google.com/app");
      
      setState(() {
        _webviewWindow = webview; // Assign the object to our state variable
        _isLaunching = false;     // Hide the loading spinner
      });

      // Register an Event Listener to close the app if the webview is closed
      webview.onClose.then((_) {
        SystemNavigator.pop(); // Clean native exit call
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
                // App Logo Widget
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
```

---

## 💻 Code Walkthrough: Linux C++ (Window Creation)

Here is the complete C++ window manager setup file: [linux/runner/my_application.cc](file:///home/toms/projects/Gem/linux/runner/my_application.cc).

```cpp
#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

// Struct representing our application. This stores data properties (encapsulation).
struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Callback triggered when the first frame is rendered by Flutter.
static void first_frame_cb(MyApplication* self, FlView* view) {
  // 💡 HACK: We commented out the line below!
  // gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  // By doing this, the launcher window initializes but remains invisible to the user.
}

// Implements window activation (analogous to main() for the GUI layer)
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Style window decorations based on Desktop Environment
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif

  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Gem");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Gem");
  }

  // Window default dimensions (small, since it is a background controller)
  gtk_window_set_default_size(window, 400, 550);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Connects the first-frame signal to our callback.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}
...
```

---

## 💻 Code Walkthrough: Windows C++ (Startup Control)

Here is the setup for the Windows Win32 runner entry point: [windows/runner/main.cpp](file:///home/toms/projects/Gem/windows/runner/main.cpp).

```cpp
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR lpCmdLine, _In_ int nCmdShow) {
  // Use a console for logging if in debug mode
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM libraries (required for using WebView2 web rendering)
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Create the main window object
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  
  // Set size to a compact shape (400x550) and name to "Gem"
  Win32Window::Size size(400, 550);
  if (!window.Create(L"Gem", origin, size)) {
    return EXIT_FAILURE;
  }
  
  // Tells Windows to kill the application process when this window structure is destroyed
  window.SetQuitOnClose(true);

  // Message loop: processes inputs and window redraws
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
```

---

## 💡 Key Takeaways

1. **Clean Code separates concerns:** The UI logic is kept in Dart, while the lower-level operating system bindings (hiding window headers, creating window classes) are handled in C++.
2. **Encapsulation:** C++ structs like `_MyApplication` hide their properties from other code files, exposing only secure functions to build and start the app.
3. **Subprocesses & Callbacks:** WebViews launch subprocesses. Using signals (like `delete-event` or `onClose`) ensures that when you click "Close", the operating system terminates everything clean and fast.
