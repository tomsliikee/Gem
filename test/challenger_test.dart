import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('window_manager');
  final List<String> log = [];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      debugPrint('Mock handler: ${methodCall.method}');
      log.add(methodCall.method);
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

  testWidgets('Double tapping minimize button triggers parent DragToMoveArea double tap behavior', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GemApp(),
      ),
    );
    await tester.pump();

    final Finder minimizeIconFinder = find.byIcon(Icons.minimize);
    expect(minimizeIconFinder, findsOneWidget);

    debugPrint('Double tapping minimize button...');
    await tester.tap(minimizeIconFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(minimizeIconFinder);
    
    // Pump some duration to allow the gestures to resolve
    await tester.pump(const Duration(milliseconds: 500));

    debugPrint('Intercepted methods after double tap: $log');
    expect(log.contains('minimize'), isTrue);
  });
}
