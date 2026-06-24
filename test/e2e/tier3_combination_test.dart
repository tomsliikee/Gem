import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/main.dart';
import 'package:gem/presentation/providers/providers.dart';
import '../mocks/mock_oauth_service.dart';
import '../mocks/mock_health_repository.dart';
import '../mocks/mock_agy_process.dart';

void main() {
  group('Tier 3 E2E - Pairwise Cross-Feature Combinations', () {
    final configFile = File('/home/toms/projects/Gem/config_$pid.json');

    setUp(() {
      configFile.writeAsStringSync(
        '{"client_id": "test_client", "client_secret": "test_secret"}',
      );
    });

    tearDown(() {
      if (configFile.existsSync()) {
        configFile.deleteSync();
      }
    });
    testWidgets('T3.1: Concurrent CLI Execution & Health Data Sync', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            oauthServiceProvider.overrideWithValue(fakeOAuth),
            healthRepositoryProvider.overrideWithValue(fakeHealthRepo),
            agyProcessRunnerProvider.overrideWithValue(fakeAgyRunner),
          ],
          child: const GemApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Start long-running prompt on Chat tab
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'hello');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();

      // Trigger Google Fit Sync concurrently
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('T3.2: Cache Refresh vs Live Chat Stream', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            oauthServiceProvider.overrideWithValue(fakeOAuth),
            healthRepositoryProvider.overrideWithValue(fakeHealthRepo),
            agyProcessRunnerProvider.overrideWithValue(fakeAgyRunner),
          ],
          child: const GemApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Establish chat session
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'hello');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();

      // Switch to health tab to find sync button
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();

      // Force database sync update
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('T3.3: User Logout During Active CLI Command', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            oauthServiceProvider.overrideWithValue(fakeOAuth),
            healthRepositoryProvider.overrideWithValue(fakeHealthRepo),
            agyProcessRunnerProvider.overrideWithValue(fakeAgyRunner),
          ],
          child: const GemApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Start CLI command
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'hello');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();

      // Click logout
      final logoutBtn = find.byKey(const Key('logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_button')), findsOneWidget);
    });

    testWidgets('T3.4: Invalid CLI Path & Fit Sync Resilience', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            oauthServiceProvider.overrideWithValue(fakeOAuth),
            healthRepositoryProvider.overrideWithValue(fakeHealthRepo),
            agyProcessRunnerProvider.overrideWithValue(fakeAgyRunner),
          ],
          child: const GemApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Set invalid CLI path in settings
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('agy_path_override')), '/invalid/path');
      await tester.pumpAndSettle();

      // Close settings drawer
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();

      // Health sync still works
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('T3.5: Rapid Tab Cycling Stress Test', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            oauthServiceProvider.overrideWithValue(fakeOAuth),
            healthRepositoryProvider.overrideWithValue(fakeHealthRepo),
            agyProcessRunnerProvider.overrideWithValue(fakeAgyRunner),
          ],
          child: const GemApp(),
        ),
      );
      await tester.pumpAndSettle();

      final tabOverview = find.byKey(const Key('tab_overview'));
      final tabHealth = find.byKey(const Key('tab_health'));
      final tabChat = find.byKey(const Key('tab_chat'));

      for (int i = 0; i < 5; i++) {
        await tester.tap(tabOverview);
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(tabHealth);
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(tabChat);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
    });
  });
}
