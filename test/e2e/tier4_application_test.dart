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
  group('Tier 4 E2E - Real-World Application Scenarios', () {
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
    testWidgets('T4.1: Day-in-the-Life Happy Path User Journey', (tester) async {
      final fakeOAuth = FakeOAuthService(isAuthenticated: false);
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

      // Login
      final loginBtn = find.byKey(const Key('login_button'));
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Verify health tab metrics
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steps_chart')), findsOneWidget);

      // Go to chat and prompt
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'Find and fix project errors');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // Click subagent node and view logs
      final node = find.byKey(const Key('node_agent-123'), skipOffstage: false);
      expect(node, findsOneWidget);
      await tester.ensureVisible(node);
      await tester.pumpAndSettle();
      await tester.tap(node);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node_logs_view')), findsOneWidget);
    });

    testWidgets('T4.2: Offline Loop Recovery', (tester) async {
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

      // Verify cached data is visible
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steps_chart')), findsOneWidget);

      // Run chat command offline
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'help');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // Switch to health tab to find sync button
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();

      // Trigger online transition and sync
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('T4.3: Fault Setup Recovery', (tester) async {
      if (configFile.existsSync()) {
        configFile.deleteSync();
      }
      final fakeOAuth = FakeOAuthService(isAuthenticated: false);
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

      // Initial startup fails to log in due to missing configuration
      final loginBtn = find.byKey(const Key('login_button'));
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('config.json missing'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Set valid CLI path override in Settings
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('agy_path_override')), '/custom/path/agy');
      await tester.pumpAndSettle();

      // Unlock operational state
      expect(find.byKey(const Key('login_button')), findsOneWidget);
    });

    testWidgets('T4.4: Subagent Node Failure & Diagnostic Deep-Dive', (tester) async {
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

      // Prompt and spawn a failing subagent
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'crash');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // Node fail color highlight
      final failedNode = find.byKey(const Key('node_deploy_node_01'), skipOffstage: false);
      expect(failedNode, findsOneWidget);
      
      // Tap failed node and verify logs
      await tester.ensureVisible(failedNode);
      await tester.pumpAndSettle();
      await tester.tap(failedNode);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node_logs_view')), findsOneWidget);
      expect(find.textContaining('Fatal: Auth failure'), findsOneWidget);
    });

    testWidgets('T4.5: Multi-Day Health Analysis Workflow', (tester) async {
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

      // Prompt assistant to analyze activity logs
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat_input')), 'Analyze my activity logs and correlation to sleep');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify db reader subagent node
      expect(find.byKey(const Key('node_db_reader_agent'), skipOffstage: false), findsOneWidget);
      // Verify chat response
      expect(find.textContaining('You walked an average of 11k steps'), findsOneWidget);
    });
  });
}
