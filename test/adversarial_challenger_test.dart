import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/main.dart';
import 'package:gem/presentation/widgets/dashboard_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('window_manager');
  final List<String> log = [];

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Adversarial Challenges for Milestone 1 Corrections', () {
    
    testWidgets('1. Double-tapping window buttons does not trigger window resizing/maximization', (WidgetTester tester) async {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall.method);
        switch (methodCall.method) {
          case 'isMaximized':
            return false;
          default:
            return null;
        }
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: GemApp(),
        ),
      );
      await tester.pump();

      // Double-tapping minimize button
      final Finder minimizeFinder = find.byIcon(Icons.minimize);
      expect(minimizeFinder, findsOneWidget);

      await tester.tap(minimizeFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(minimizeFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // Double-tapping close button
      final Finder closeFinder = find.byIcon(Icons.close);
      expect(closeFinder, findsOneWidget);

      await tester.tap(closeFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(closeFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // We expect minimize and close calls, but NO maximize/unmaximize/isMaximized from double tap.
      // (The only isMaximized should be from the initState init call).
      expect(log.where((m) => m == 'minimize').length, equals(2));
      expect(log.where((m) => m == 'close').length, equals(2));
      expect(log.where((m) => m == 'maximize').length, equals(0));
      expect(log.where((m) => m == 'unmaximize').length, equals(0));
    });

    testWidgets('2. The test suite and application handle missing/null mock getters gracefully', (WidgetTester tester) async {
      log.clear();
      // Set up a mock handler that returns null for ALL getter methods (simulating unhandled getters)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall.method);
        return null; // Return null for everything, including isMaximized
      });

      // Pump the widget; it should not throw a TypeError and crash the test.
      // The try-catch block in CustomTitleBar should handle it gracefully.
      await tester.pumpWidget(
        const ProviderScope(
          child: GemApp(),
        ),
      );
      await tester.pump();

      // Verify the widget tree still rendered successfully
      expect(find.byType(CustomWindowShell), findsOneWidget);
      expect(find.byType(DashboardView), findsOneWidget);
    });

    testWidgets('3. The initial maximized window state is synchronized correctly (Maximized -> Restore icon)', (WidgetTester tester) async {
      // Mock isMaximized to return true on initialization
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isMaximized') {
          return true;
        }
        return null;
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: GemApp(),
        ),
      );
      await tester.pump();

      // Since the window is initially maximized, the button icon should be filter_none (Restore icon)
      expect(find.byIcon(Icons.filter_none), findsOneWidget);
      expect(find.byIcon(Icons.crop_square), findsNothing);
    });

    testWidgets('3b. The initial maximized window state is synchronized correctly (Unmaximized -> Maximize icon)', (WidgetTester tester) async {
      // Mock isMaximized to return false on initialization
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isMaximized') {
          return false;
        }
        return null;
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: GemApp(),
        ),
      );
      await tester.pump();

      // Since the window is initially not maximized, the button icon should be crop_square (Maximize icon)
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
      expect(find.byIcon(Icons.filter_none), findsNothing);
    });

    testWidgets('4. The gradient has transparency to let the glassmorphic background show', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: GemApp(),
        ),
      );
      await tester.pump();

      // Find the Container that holds the background gradient in DashboardView.
      // DashboardView builds a Stack where the first child is the background Container.
      final Finder backgroundContainerFinder = find.descendant(
        of: find.byType(DashboardView),
        matching: find.byType(Container),
      ).first;

      final Container containerWidget = tester.widget<Container>(backgroundContainerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;
      final LinearGradient gradient = decoration.gradient as LinearGradient;

      expect(gradient, isNotNull);
      expect(gradient.colors.length, greaterThanOrEqualTo(2));
      
      // Verify transparency in all gradient colors
      for (final Color color in gradient.colors) {
        expect(color.a, lessThan(1.0), reason: 'Color $color must have opacity < 1.0 to let glassmorphism show');
      }
    });
  });
}
