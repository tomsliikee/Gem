import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/main.dart';
import 'package:gem/presentation/widgets/dashboard_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('window_manager');
  final List<String> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    // Mock the window_manager plugin methods to prevent test errors due to missing native channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      methodCalls.add(methodCall.method);
      switch (methodCall.method) {
        case 'ensureInitialized':
          return null;
        case 'waitUntilReadyToShow':
          return null;
        case 'show':
          return null;
        case 'focus':
          return null;
        case 'isMaximized':
        case 'isMinimized':
        case 'isFocused':
        case 'isFullScreen':
          return false;
        case 'addListener':
          return null;
        case 'removeListener':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Dashboard view renders successfully in GemApp', (WidgetTester tester) async {
    // Build the app under test inside a ProviderScope (required by Riverpod)
    await tester.pumpWidget(
      const ProviderScope(
        child: GemApp(),
      ),
    );

    // Re-render to ensure layout and stream callbacks propagate
    await tester.pump();

    // Verify CustomWindowShell is present
    expect(find.byType(CustomWindowShell), findsOneWidget);

    // Verify DashboardView is present
    expect(find.byType(DashboardView), findsOneWidget);

    // Verify custom header text exists
    expect(find.text('Gem Life OS'), findsOneWidget);

    // Verify the dashboard skeleton card text is shown
    expect(find.text('Gem Life OS - Dashboard Skeleton'), findsOneWidget);
  });

  testWidgets('Verifies GemApp builds custom header window chrome and handles events', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GemApp(),
      ),
    );
    await tester.pump();

    // Verify Custom title bar exists
    expect(find.byType(CustomTitleBar), findsOneWidget);
    
    // Locate the close button by matching TitleBarButton with close icon
    final closeFinder = find.byIcon(Icons.close);
    expect(closeFinder, findsOneWidget);

    // Tap and check if windowManager close was dispatched
    await tester.tap(closeFinder);
    await tester.pump();

    expect(methodCalls.contains('close'), isTrue);
  });
}
