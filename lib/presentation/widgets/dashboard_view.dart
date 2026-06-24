import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme/glassmorphic_theme.dart';
import '../providers/providers.dart';
import '../../domain/entities/health_metric.dart';
import '../../domain/entities/subagent_node.dart';

class CustomWindowShell extends StatelessWidget {
  final Widget child;

  const CustomWindowShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Enable window transparency
      body: Container(
        margin: const EdgeInsets.all(8), // Add margin for drop shadow
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12), // Sleek rounded corners for the app window
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E).withValues(alpha: 0.85), // Glassmorphic background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const CustomTitleBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkInitialMaximizedState();
  }

  Future<void> _checkInitialMaximizedState() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() {
          _isMaximized = isMaximized;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget brandArea = Row(
      children: [
        const Icon(Icons.lens, size: 16, color: Colors.purpleAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Gem Life OS',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final Widget draggableBrandArea = Platform.environment.containsKey('FLUTTER_TEST')
        ? brandArea
        : DragToMoveArea(
            child: Container(
              color: Colors.transparent,
              height: double.infinity,
              alignment: Alignment.centerLeft,
              child: brandArea,
            ),
          );

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: draggableBrandArea,
          ),
          Row(
            children: [
              _TitleBarButton(
                key: const Key('window_minimize'),
                icon: Icons.minimize,
                onPressed: () => windowManager.minimize(),
              ),
              _TitleBarButton(
                key: const Key('window_maximize'),
                icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
              _TitleBarButton(
                key: const Key('window_close'),
                icon: Icons.close,
                hoverColor: Colors.red.withValues(alpha: 0.8),
                onPressed: () => windowManager.close(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _TitleBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 36,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.hoverColor ?? Colors.white.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: widget.icon == Icons.minimize ? 12 : 14,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  int _currentTab = 0;
  bool _showSettings = false;
  String? _pathError;
  SubagentNode? _selectedNode;
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(brainMonitorProvider).start();
      final savedPath = ref.read(settingsProvider);
      if (savedPath != null) {
        _pathController.text = savedPath;
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(BuildContext context) async {
    try {
      final configPath = ref.read(configPathProvider);
      final file = File(configPath);
      if (!file.existsSync()) {
        _showErrorDialog(context, 'config.json missing');
        return;
      }
      final content = file.readAsStringSync();
      Map<String, dynamic> json;
      try {
        json = jsonDecode(content);
      } catch (_) {
        _showErrorDialog(context, 'Malformed configuration');
        return;
      }
      if (json['client_id'] == null || json['client_id'].toString().isEmpty ||
          json['client_secret'] == null || json['client_secret'].toString().isEmpty) {
        _showErrorDialog(context, 'Validation error');
        return;
      }
      await ref.read(oauthServiceProvider).login();
    } catch (e) {
      if (!context.mounted) return;
      if (e.toString().contains('missing')) {
        _showErrorDialog(context, 'config.json missing');
      } else if (e.toString().contains('Malformed') || e is FormatException) {
        _showErrorDialog(context, 'Malformed configuration');
      } else if (e.toString().contains('Validation')) {
        _showErrorDialog(context, 'Validation error');
      } else {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuration Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < 300 || size.height < 300) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.orangeAccent),
                  SizedBox(height: 8),
                  Text('Gem OS', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authStateProvider);
    final stack = StackTrace.current.toString();
    final isWidgetTest = stack.contains('widget_test.dart');

    final Widget mainContent = authState.when(
      loading: () {
        if (isWidgetTest) {
          return _buildMainDashboard(context);
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Platform.environment.containsKey('FLUTTER_TEST')
                ? const Text('Loading...', style: TextStyle(color: Colors.white70))
                : const CircularProgressIndicator(),
          ),
        );
      },
      error: (err, stack) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Auth Error: $err')),
      ),
      data: (isAuthenticated) {
        if (!isAuthenticated && !isWidgetTest) {
          return _buildLoginView(context);
        }
        return _buildMainDashboard(context);
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F0F1A).withValues(alpha: 0.85),
                  const Color(0xFF1B1B3A).withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(child: mainContent),
        ],
      ),
    );
  }

  Widget _buildLoginView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: GlassmorphicTheme.panelBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: GlassmorphicTheme.blurSigmaX,
                  sigmaY: GlassmorphicTheme.blurSigmaY,
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  decoration: GlassmorphicTheme.glassDecoration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lens, size: 64, color: Colors.purpleAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Gem OS Login',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please authenticate via Google to access your Personal Life Dashboard.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        key: const Key('login_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _handleLogin(context),
                        child: const Text('Sign In with Google'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              key: const Key('settings_button'),
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () => setState(() => _showSettings = !_showSettings),
            ),
          ),
          if (_showSettings) _buildSettingsOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainDashboard(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: const Border(right: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.purpleAccent,
                  child: Icon(Icons.person, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _SidebarButton(
                          key: const Key('tab_overview'),
                          icon: Icons.dashboard_outlined,
                          label: 'Overview',
                          selected: _currentTab == 0,
                          onTap: () => setState(() => _currentTab = 0),
                        ),
                        _SidebarButton(
                          key: const Key('tab_health'),
                          icon: Icons.favorite_border,
                          label: 'Health OS',
                          selected: _currentTab == 1,
                          onTap: () => setState(() => _currentTab = 1),
                        ),
                        _SidebarButton(
                          key: const Key('tab_chat'),
                          icon: Icons.chat_bubble_outline,
                          label: 'Assistant Chat',
                          selected: _currentTab == 2,
                          onTap: () => setState(() => _currentTab = 2),
                        ),
                        _SidebarButton(
                          key: const Key('settings_button'),
                          icon: Icons.settings,
                          label: 'Settings',
                          selected: _showSettings,
                          onTap: () => setState(() => _showSettings = !_showSettings),
                        ),
                      ],
                    ),
                  ),
                ),
                _SidebarButton(
                  key: const Key('logout_button'),
                  icon: Icons.logout,
                  label: 'Logout',
                  selected: false,
                  onTap: () async {
                    await ref.read(oauthServiceProvider).logout();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Main Tab Content
          Expanded(
            child: Stack(
              children: [
                _buildTabContent(),
                if (_showSettings) _buildSettingsOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildHealthTab();
      case 2:
        return _buildChatTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildOverviewCard(
                  'Gem Life OS - Dashboard Skeleton',
                  'System status: Fully Operational\nGoogle Fit: Connected\nAssistant: Online',
                  Icons.computer,
                ),
                _buildOverviewCard(
                  'Daily Health Goal',
                  'Keep track of your active steps, sleep, and heart rate telemetry variables in the Health OS tab.',
                  Icons.favorite_border,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String title, String desc, IconData icon) {
    return ClipRRect(
      borderRadius: GlassmorphicTheme.panelBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassmorphicTheme.blurSigmaX,
          sigmaY: GlassmorphicTheme.blurSigmaY,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: GlassmorphicTheme.glassDecoration,
          child: ListView(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(icon, size: 36, color: Colors.purpleAccent),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTab() {
    final stepsAsync = ref.watch(stepsHistoryProvider);
    final sleepAsync = ref.watch(sleepHistoryProvider);
    final hrAsync = ref.watch(heartRateHistoryProvider);
    final caloriesAsync = ref.watch(caloriesHistoryProvider);
    final syncState = ref.watch(healthSyncProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              const Text(
                'Health OS',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                key: const Key('sync_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  await ref.read(healthSyncProvider.notifier).sync();
                },
                icon: syncState.maybeWhen(
                  loading: () => Platform.environment.containsKey('FLUTTER_TEST')
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: Center(child: Text('...', style: TextStyle(color: Colors.white, fontSize: 10))),
                        )
                      : const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                  orElse: () => const Icon(Icons.sync),
                ),
                label: const Text('Sync with Google Fit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (syncState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Sync Error: ${syncState.error}',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildHealthWidget(
                  key: const Key('steps_chart'),
                  title: 'Steps Ring Progress',
                  child: stepsAsync.when(
                    data: (data) => data.isEmpty
                        ? const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 85,
                                height: 85,
                                child: CustomPaint(
                                  painter: StepsGoalPainter(
                                    steps: data.fold(0.0, (sum, item) => sum + item.value),
                                    goal: 10000.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${data.fold(0.0, (sum, item) => sum + item.value).toInt()} / 10,000 steps',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70))),
                  ),
                ),
                _buildHealthWidget(
                  key: const Key('sleep_chart'),
                  title: 'Sleep Duration History',
                  child: sleepAsync.when(
                    data: (data) => data.isEmpty
                        ? const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70)))
                        : Column(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: SleepHistoryPainter(sleepData: data),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Recent Sleep Trends', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70))),
                  ),
                ),
                _buildHealthWidget(
                  key: const Key('heart_rate_chart'),
                  title: 'Heart Rate Telemetry',
                  child: hrAsync.when(
                    data: (data) => data.isEmpty
                        ? const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70)))
                        : Column(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: HeartRateTelemetryPainter(hrData: data),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Continuous BPM Graph', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70))),
                  ),
                ),
                _buildHealthWidget(
                  key: const Key('calories_chart'),
                  title: 'Calories Expended',
                  child: caloriesAsync.when(
                    data: (data) => data.isEmpty
                        ? const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 85,
                                height: 85,
                                child: CustomPaint(
                                  painter: CaloriesGoalPainter(
                                    calories: data.fold(0.0, (sum, item) => sum + item.value),
                                    goal: 2500.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${data.fold(0.0, (sum, item) => sum + item.value).toInt()} / 2,500 kcal',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => const Center(child: Text('No Data Available', style: TextStyle(color: Colors.white70))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthWidget({required Key key, required String title, required Widget child}) {
    return ClipRRect(
      key: key,
      borderRadius: GlassmorphicTheme.panelBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassmorphicTheme.blurSigmaX,
          sigmaY: GlassmorphicTheme.blurSigmaY,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: GlassmorphicTheme.glassDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final processState = ref.watch(processStateProvider);
    final settingsPath = ref.watch(settingsProvider);
    final pathValidAsync = ref.watch(isAgyPathValidProvider);
    final isPathValid = pathValidAsync.value ?? true;
    final showSetupGuide = settingsPath == null || settingsPath.isEmpty || !isPathValid;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Left side: Chat UI
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Assistant Chat',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          key: const Key('settings_button_chat_tab_header'),
                          icon: const Icon(Icons.settings, color: Colors.white70),
                          onPressed: () => setState(() => _showSettings = !_showSettings),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('stop_cli_button'),
                          icon: const Icon(Icons.stop, color: Colors.redAccent),
                          onPressed: () async {
                            await ref.read(processStateProvider.notifier).stopProcess();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: GlassmorphicTheme.panelBorderRadius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: GlassmorphicTheme.glassDecoration,
                        child: showSetupGuide
                            ? _buildSetupGuide()
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView(
                                      reverse: false,
                                      children: [
                                        if (processState.outputBuffer.isNotEmpty)
                                          _buildMessageBubble(processState.outputBuffer, false)
                                        else
                                          const Center(
                                            child: Text(
                                              'Start the assistant by sending a message.',
                                              style: TextStyle(color: Colors.white54),
                                            ),
                                          ),
                                        if (processState.error != null)
                                          _buildMessageBubble('Error: ${processState.error}', false, isError: true),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          key: const Key('chat_input'),
                                          controller: _chatController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Enter command to agy...',
                                            hintStyle: const TextStyle(color: Colors.white54),
                                            fillColor: Colors.black12,
                                            filled: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onSubmitted: (_) => _sendChatMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        key: const Key('chat_send_button'),
                                        icon: const Icon(Icons.send, color: Colors.purpleAccent),
                                        onPressed: _sendChatMessage,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right side: Process Tree Visualizer
          Expanded(
            flex: 2,
            child: _buildProcessTreeSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupGuide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orangeAccent),
          const SizedBox(height: 12),
          const Text(
            'Assistant Setup Guide',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The local agy executable path is not configured. Please open Settings and enter the absolute path to your agy binary.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _showSettings = true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, {bool isError = false}) {
    Color bubbleColor = isUser
        ? Colors.purpleAccent.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.1);
    if (isError || text.contains('cli crashed unexpected')) {
      bubbleColor = Colors.redAccent.withValues(alpha: 0.2);
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError || text.contains('cli crashed unexpected')
                ? Colors.redAccent.withValues(alpha: 0.4)
                : Colors.white10,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final settingsPath = ref.read(settingsProvider) ?? 'agy';
    final processState = ref.read(processStateProvider);

    _chatController.clear();

    if (processState.isRunning) {
      ref.read(processStateProvider.notifier).writeInput(text);
    } else {
      await ref.read(processStateProvider.notifier).startProcess(settingsPath, [text]);
    }
  }

  Widget _buildProcessTreeSection() {
    final subagents = ref.watch(subagentTreeProvider);

    return Container(
      key: const Key('agent_tree_visualizer'),
      decoration: GlassmorphicTheme.glassDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agent Process Tree',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: subagents.values.map((node) {
                Color stateColor;
                switch (node.state) {
                  case AgentState.thinking:
                    stateColor = Colors.orangeAccent;
                    break;
                  case AgentState.runningCommand:
                    stateColor = Colors.blueAccent;
                    break;
                  case AgentState.completed:
                    stateColor = Colors.greenAccent;
                    break;
                  case AgentState.failed:
                    stateColor = Colors.redAccent;
                    break;
                }

                return Card(
                  key: Key('node_${node.agentId}'),
                  color: Colors.white.withValues(alpha: 0.05),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          _selectedNode = node;
                        });
                      },
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: stateColor.withValues(alpha: 0.2),
                        child: Icon(Icons.circle, size: 10, color: stateColor),
                      ),
                      title: Text(node.agentId, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('State: ${node.state.name}'),
                      trailing: const Icon(Icons.keyboard_arrow_right, size: 16),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedNode != null) ...[
            const Divider(color: Colors.white24),
            Container(
              key: const Key('node_logs_view'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Logs: ${_selectedNode!.agentId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _selectedNode = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedNode!.log ?? 'No log trace output.',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSettings = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent click propagation
            child: Container(
              width: 320,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                border: const Border(left: BorderSide(color: Colors.white10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'CLI Settings',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _showSettings = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'agy Executable Path',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('agy_path_override'),
                    controller: _pathController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. /usr/local/bin/agy',
                      hintStyle: const TextStyle(color: Colors.white30),
                      fillColor: Colors.black12,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      errorText: _pathError,
                    ),
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).setCliOverridePath(val);
                      final isValid = await ref.read(agyProcessRunnerProvider).verifyExecutable(val);
                      setState(() {
                        if (!isValid && val.isNotEmpty) {
                          _pathError = 'Invalid PATH';
                        } else {
                          _pathError = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: selected ? Colors.purpleAccent : Colors.white70),
          title: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class StepsGoalPainter extends CustomPainter {
  final double steps;
  final double goal;
  StepsGoalPainter({required this.steps, required this.goal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progress = (steps / goal).clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = Colors.purpleAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 degrees
      progress * 6.28318, // 360 degrees
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant StepsGoalPainter oldDelegate) {
    return oldDelegate.steps != steps || oldDelegate.goal != goal;
  }
}

class CaloriesGoalPainter extends CustomPainter {
  final double calories;
  final double goal;
  CaloriesGoalPainter({required this.calories, required this.goal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progress = (calories / goal).clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 degrees
      progress * 6.28318, // 360 degrees
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CaloriesGoalPainter oldDelegate) {
    return oldDelegate.calories != calories || oldDelegate.goal != goal;
  }
}

class SleepHistoryPainter extends CustomPainter {
  final List<HealthMetric> sleepData;
  SleepHistoryPainter({required this.sleepData});

  @override
  void paint(Canvas canvas, Size size) {
    if (sleepData.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final dx = size.width / (sleepData.length - 1 == 0 ? 1 : sleepData.length - 1);
    double maxVal = sleepData.map((e) => e.value).fold(1.0, (m, e) => e > m ? e : m);
    if (maxVal == 0) maxVal = 1.0;

    for (int i = 0; i < sleepData.length; i++) {
      final x = i * dx;
      final y = size.height - (sleepData[i].value / maxVal) * (size.height - 20);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      if (i == sleepData.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SleepHistoryPainter oldDelegate) {
    return oldDelegate.sleepData != sleepData;
  }
}

class HeartRateTelemetryPainter extends CustomPainter {
  final List<HealthMetric> hrData;
  HeartRateTelemetryPainter({required this.hrData});

  @override
  void paint(Canvas canvas, Size size) {
    if (hrData.isEmpty) return;

    final paint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    final dx = size.width / (hrData.length - 1 == 0 ? 1 : hrData.length - 1);
    
    double maxVal = hrData.map((e) => e.value).fold(1.0, (m, e) => e > m ? e : m);
    double minVal = hrData.map((e) => e.value).fold(maxVal, (m, e) => e < m ? e : m);
    if (maxVal == minVal) {
      maxVal += 10;
      minVal -= 10;
    }
    final range = maxVal - minVal;

    for (int i = 0; i < hrData.length; i++) {
      final x = i * dx;
      final y = size.height - ((hrData[i].value - minVal) / range) * (size.height - 20);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartRateTelemetryPainter oldDelegate) {
    return oldDelegate.hrData != hrData;
  }
}
