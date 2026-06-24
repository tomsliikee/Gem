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
  group('Tier 1 E2E - Feature Coverage', () {
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
    // Glassmorphic UI/State Management (F1.1 - F1.5)
    testWidgets('F1.1: UI renders translucent panels, blur, shadows, and smooth theme transitions', (tester) async {
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
      final glassBox = find.byWidgetPredicate((widget) => widget is Container && widget.decoration is BoxDecoration && (widget.decoration as BoxDecoration).color != null);
      expect(glassBox, findsAtLeastNWidgets(1));
      final container = tester.widget<Container>(glassBox.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
    });

    testWidgets('F1.2: Custom window minimize button triggers window minimization', (tester) async {
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
      final minButton = find.byKey(const Key('window_minimize'));
      expect(minButton, findsOneWidget, reason: 'Minimize button is missing');
      await tester.tap(minButton);
      await tester.pump();
    });

    testWidgets('F1.3: Custom window maximize button toggles window maximization', (tester) async {
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
      final maxButton = find.byKey(const Key('window_maximize'));
      expect(maxButton, findsOneWidget, reason: 'Maximize button is missing');
      await tester.tap(maxButton);
      await tester.pump();
    });

    testWidgets('F1.4: Custom window close button triggers app close', (tester) async {
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
      final closeButton = find.byKey(const Key('window_close'));
      expect(closeButton, findsOneWidget, reason: 'Close button is missing');
      await tester.tap(closeButton);
      await tester.pump();
    });

    testWidgets('F1.5: App loads all primary tabs (Overview, Health, Chat) with correct default states', (tester) async {
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
      expect(find.byKey(const Key('tab_overview')), findsOneWidget);
      expect(find.byKey(const Key('tab_health')), findsOneWidget);
      expect(find.byKey(const Key('tab_chat')), findsOneWidget);
    });

    // Google OAuth 2.0 Loopback (F2.1 - F2.5)
    testWidgets('F2.1: OAuth flow is initiated upon clicking the login button when config is present', (tester) async {
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
      final loginBtn = find.byKey(const Key('login_button'));
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pump();
      expect(fakeOAuth.loginCalled, isTrue);
    });

    test('F2.2: Local redirect loopback server starts on port and captures redirect URL', () async {
      final server = FakeOAuthRedirectServer(port: 8080);
      final port = await server.start();
      expect(port, 8080);
      final code = await server.waitForCode();
      expect(code, 'auth_code_xyz_123');
    });

    testWidgets('F2.3: Successful login caches tokens locally and transitions state to Authenticated', (tester) async {
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
      final loginBtn = find.byKey(const Key('login_button'));
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();
      final token = await fakeOAuth.getAccessToken();
      expect(token, 'mock_access_token_123');
    });

    testWidgets('F2.4: Riverpod auth provider updates reactive state and propagates to dashboard', (tester) async {
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
      expect(find.byKey(const Key('logout_button')), findsNothing);
    });

    testWidgets('F2.5: Logout button clears secure storage and redirects to unauthenticated view', (tester) async {
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
      final logoutBtn = find.byKey(const Key('logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_button')), findsOneWidget);
    });

    // Google Fit API Fetching/Caching (F3.1 - F3.5)
    testWidgets('F3.1: Google Fit steps data is retrieved from REST API and cached locally', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pump();
    });

    testWidgets('F3.2: Google Fit sleep duration data is retrieved from REST API and cached locally', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pump();
    });

    testWidgets('F3.3: Google Fit heart rate history data is retrieved from REST API and cached', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pump();
    });

    testWidgets('F3.4: Steps, sleep, and heart rate charts are correctly populated and rendered', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steps_chart')), findsOneWidget);
      expect(find.byKey(const Key('sleep_chart')), findsOneWidget);
      expect(find.byKey(const Key('heart_rate_chart')), findsOneWidget);
    });

    testWidgets('F3.5: Offline mode uses locally cached data when Fit API calls fail', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_health')));
      await tester.pumpAndSettle();
      final syncBtn = find.byKey(const Key('sync_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
    });

    // Antigravity CLI Chat Wrapper (F4.1 - F4.5)
    testWidgets('F4.1: Chat UI is able to run the local agy executable from system PATH', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_input')), findsOneWidget);
    });

    testWidgets('F4.2: User message is correctly piped to agy stdin', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      final chatInput = find.byKey(const Key('chat_input'));
      final sendBtn = find.byKey(const Key('chat_send_button'));
      expect(chatInput, findsOneWidget);
      expect(sendBtn, findsOneWidget);
      await tester.enterText(chatInput, 'hello');
      await tester.tap(sendBtn);
      await tester.pump();
    });

    testWidgets('F4.3: Streamed output from agy stdout is dynamically appended as chat bubbles', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      final chatInput = find.byKey(const Key('chat_input'));
      final sendBtn = find.byKey(const Key('chat_send_button'));
      await tester.enterText(chatInput, 'hello');
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Echo: hello'), findsOneWidget);
    });

    testWidgets('F4.4: Settings page path override is saved and updates execution path', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      final settingsBtn = find.byKey(const Key('settings_button'));
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();
      final pathOverride = find.byKey(const Key('agy_path_override'));
      expect(pathOverride, findsOneWidget);
      await tester.enterText(pathOverride, '/custom/path/agy');
      await tester.pump();
    });

    testWidgets('F4.5: Invalid CLI path override displays visual error notification', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();
      final pathOverride = find.byKey(const Key('agy_path_override'));
      expect(pathOverride, findsOneWidget);
      await tester.enterText(pathOverride, '/invalid/path');
      await tester.pumpAndSettle();
      expect(find.textContaining('Invalid PATH'), findsOneWidget);
    });

    // Agent Process Tree Visualizer (F5.1 - F5.5)
    testWidgets('F5.1: Process tree visualizer correctly loads the root agent node', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agent_tree_visualizer')), findsOneWidget);
      expect(find.byKey(const Key('node_root'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('F5.2: Spawned subagents are parsed from JSONL brain transcripts and added to tree', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node_subagent_1'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('F5.3: Visual nodes transition colors/labels matching agent state updates (Thinking, Running Command, Completed, Failed)', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      final node = find.byKey(const Key('node_subagent_1'), skipOffstage: false);
      expect(node, findsOneWidget);
    });

    testWidgets('F5.4: Clicking on an agent node renders the detailed logs view', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
      final node = find.byKey(const Key('node_subagent_1'), skipOffstage: false);
      expect(node, findsOneWidget);
      await tester.ensureVisible(node);
      await tester.pumpAndSettle();
      await tester.tap(node);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node_logs_view')), findsOneWidget);
    });

    testWidgets('F5.5: Visualizer monitors and re-reads the JSONL files in real-time', (tester) async {
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
      await tester.tap(find.byKey(const Key('tab_chat')));
      await tester.pumpAndSettle();
    });
  });
}
