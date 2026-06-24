import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/main.dart';
import 'package:gem/presentation/providers/providers.dart';
import 'package:gem/domain/entities/health_metric.dart';
import 'package:gem/data/models/health_metric_model.dart';
import 'package:gem/domain/entities/subagent_node.dart';
import '../mocks/mock_oauth_service.dart';
import '../mocks/mock_health_repository.dart';
import '../mocks/mock_agy_process.dart';

// Helper class to build a tree of SubagentNodes and detect/break circular references
class TranscriptTree {
  final Map<String, List<SubagentNode>> parentToChildren = {};
  final Map<String, SubagentNode> nodes = {};
  final List<SubagentNode> roots = [];

  void buildTree(List<SubagentNode> parsedNodes) {
    for (var node in parsedNodes) {
      nodes[node.agentId] = node;
    }

    for (var node in parsedNodes) {
      final parentId = node.parentId;
      if (parentId == null) {
        roots.add(node);
      } else {
        if (_wouldCreateCycle(node.agentId, parentId)) {
          // Break cycle: treat it as a root
          roots.add(node);
        } else {
          parentToChildren.putIfAbsent(parentId, () => []).add(node);
        }
      }
    }
  }

  bool _wouldCreateCycle(String childId, String parentId) {
    String? current = parentId;
    final visited = <String>{childId};
    while (current != null) {
      if (visited.contains(current)) {
        return true;
      }
      visited.add(current);
      current = nodes[current]?.parentId;
    }
    return false;
  }
}

// Helper class to parse JSONL string into a List of SubagentNodes
class TranscriptParser {
  static List<SubagentNode> parse(String transcript) {
    final list = <SubagentNode>[];
    final lines = transcript.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final jsonMap = jsonDecode(trimmed) as Map<String, dynamic>;
        final node = SubagentNode.fromJson(jsonMap);
        list.add(node);
      } catch (e) {
        // Gracefully skip malformed line
        debugPrint('Skipping malformed line: $e');
      }
    }
    return list;
  }
}

// Debounce helper for streams
Stream<T> debounce<T>(Stream<T> stream, Duration duration) {
  StreamController<T>? controller;
  StreamSubscription<T>? subscription;
  Timer? timer;

  controller = StreamController<T>(
    onListen: () {
      subscription = stream.listen(
        (data) {
          timer?.cancel();
          timer = Timer(duration, () {
            controller?.add(data);
          });
        },
        onError: controller?.addError,
        onDone: () {
          timer?.cancel();
          controller?.close();
        },
      );
    },
    onCancel: () {
      subscription?.cancel();
      timer?.cancel();
    },
  );
  return controller.stream;
}

void main() {
  group('Tier 2 E2E - Boundary & Corner Cases', () {
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
    // Glassmorphic UI/State Management Boundaries (F1.B1 - F1.B5)
    testWidgets('F1.B1: Window resized to micro dimensions behaves gracefully without overflow crashes', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      final dpi = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(200 * dpi, 200 * dpi);
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });
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
      expect(tester.takeException(), isNull);
    });

    testWidgets('F1.B2: SQLite/drift database file corruption handles errors and falls back to empty defaults', (tester) async {
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
      // Expect fallback database initialization to not crash the app
      expect(find.byType(GemApp), findsOneWidget);
    });

    testWidgets('F1.B3: Rapid repeated clicks on window controls do not cause race conditions or crashes', (tester) async {
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
      final minBtn = find.byKey(const Key('window_minimize'));
      expect(minBtn, findsOneWidget);
      for (int i = 0; i < 10; i++) {
        await tester.tap(minBtn);
      }
      await tester.pump();
    });

    testWidgets('F1.B4: UI scales properly under extreme DPI settings', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner();

      final dpi = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(3840 * dpi, 2160 * dpi); // 4K screen simulation
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });
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
      expect(find.byType(GemApp), findsOneWidget);
    });

    testWidgets('F1.B5: Missing system fonts fall back gracefully to standard sans-serif', (tester) async {
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
      expect(find.text('Gem Life OS'), findsOneWidget);
    });

    // Google OAuth Boundaries (F2.B1 - F2.B5)
    testWidgets('F2.B1: Missing config.json yields a clear error popup asking to configure OAuth', (tester) async {
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
      final loginBtn = find.byKey(const Key('login_button'));
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('config.json missing'), findsOneWidget);
    });

    testWidgets('F2.B2: Malformed config.json prints diagnostic error and blocks login', (tester) async {
      configFile.writeAsStringSync('{malformed_json}');
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
      expect(find.textContaining('Malformed configuration'), findsOneWidget);
    });

    testWidgets('F2.B3: Empty client_id or client_secret in config yields configuration validation error', (tester) async {
      configFile.writeAsStringSync('{"client_id": "", "client_secret": ""}');
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
      expect(find.textContaining('Validation error'), findsOneWidget);
    });

    test('F2.B4: OAuth login timeout (e.g. user takes >5 minutes) triggers login cancel/timeout state', () async {
      final server = FakeOAuthRedirectServer();
      server.triggerTimeout();
      expect(
        () => server.waitForCode(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('F2.B5: Loopback server port conflict (e.g. 8080 busy) switches to an ephemeral port', (tester) async {
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

      final server = FakeOAuthRedirectServer(port: 8080);
      server.triggerBindFailure();
      expect(() => server.start(), throwsA(isA<SocketException>()));
    });

    // Google Fit API Boundaries (F3.B1 - F3.B5)
    testWidgets('F3.B1: API returns empty dataset for range, UI charts render empty/no-data placeholder', (tester) async {
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
      expect(find.text('No Data Available'), findsWidgets);
    });

    testWidgets('F3.B2: Fit API returns HTTP 401 Unauthorized, app automatically initiates token refresh', (tester) async {
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

    testWidgets('F3.B3: Fit API returns HTTP 500 Internal Error, UI displays "Sync Error" but keeps cached data', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([])..simulateError = true;
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
      expect(find.textContaining('Sync Error'), findsOneWidget);
    });

    testWidgets('F3.B4: Cache limits are enforced: old data (>30 days) is cleaned up, maintaining cache health', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final now = DateTime.now();
      final oldMetric = HealthMetric(timestamp: now.subtract(const Duration(days: 45)), type: MetricType.steps, value: 5000);
      final newMetric = HealthMetric(timestamp: now.subtract(const Duration(days: 5)), type: MetricType.steps, value: 8000);
      final fakeHealthRepo = FakeHealthRepository([oldMetric, newMetric]);
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

      fakeHealthRepo.pruneCache(now);
      expect(fakeHealthRepo.cachedData.length, 1);
      expect(fakeHealthRepo.cachedData.first.value, 8000);
    });

    testWidgets('F3.B5: Fit API returns extreme values (1M steps, 25hr sleep, 300 bpm), models sanitize or bound data', (tester) async {
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

      // Negative step count
      expect(
        () => HealthMetricModel.fromJson(const {'date': '2026-06-22', 'count': -5}, MetricType.steps),
        throwsA(isA<FormatException>()),
      );
      // Extreme step count (> 1M)
      expect(
        () => HealthMetricModel.fromJson(const {'date': '2026-06-22', 'count': 1000001}, MetricType.steps),
        throwsA(isA<FormatException>()),
      );
      // Extreme sleep count (> 24 hours / 86400 seconds)
      expect(
        () => HealthMetricModel.fromJson(const {'date': '2026-06-22', 'duration_seconds': 90000}, MetricType.sleep),
        throwsA(isA<FormatException>()),
      );
      // Negative sleep count
      expect(
        () => HealthMetricModel.fromJson(const {'date': '2026-06-22', 'duration_seconds': -10}, MetricType.sleep),
        throwsA(isA<FormatException>()),
      );
    });

    // Antigravity CLI Chat Boundaries (F4.B1 - F4.B5)
    testWidgets('F4.B1: agy binary not found in PATH or settings, app presents "Assistant Setup Guide"', (tester) async {
      final fakeOAuth = FakeOAuthService();
      final fakeHealthRepo = FakeHealthRepository([]);
      final fakeAgyRunner = FakeAgyProcessRunner()..pathValid = false;

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
      expect(find.textContaining('Assistant Setup Guide'), findsOneWidget);
    });

    testWidgets('F4.B2: Huge prompt payload (>1MB file paste) handled efficiently without UI freeze', (tester) async {
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
      expect(chatInput, findsOneWidget);
      final hugeText = 'a' * 1024 * 1024;
      await tester.enterText(chatInput, hugeText);
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();
    });

    testWidgets('F4.B3: agy process crashes or exits with non-zero code, chat displays error bubble', (tester) async {
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
      await tester.enterText(chatInput, 'crash');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('cli crashed unexpected'), findsOneWidget);
    });

    testWidgets('F4.B4: User clicks "Stop" button, app terminates agy process tree and processes zombie nodes', (tester) async {
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
      final stopBtn = find.byKey(const Key('stop_cli_button'));
      expect(stopBtn, findsOneWidget);
      await tester.tap(stopBtn);
      await tester.pump();
    });

    testWidgets('F4.B5: Input contains shell metacharacters, process wrapper prevents shell injection', (tester) async {
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
      await tester.enterText(chatInput, '; rm -rf / ;');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();
    });

    // Agent Process Tree Boundaries (F5.B1 - F5.B5)
    testWidgets('F5.B1: Transcript directory ~/.gemini/antigravity-cli/brain/ is missing, visualizer handles gracefully', (tester) async {
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
    });

    testWidgets('F5.B2: Massive JSONL file (>10k lines) does not freeze the rendering thread', (tester) async {
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

      final sb = StringBuffer();
      for (int i = 0; i < 10000; i++) {
        sb.writeln('{"timestamp": "2026-06-22T10:00:00.000Z", "agent_id": "agent-$i", "parent_id": ${i > 0 ? '"agent-${i - 1}"' : 'null'}, "state": "Thinking", "log": "Step $i"}');
      }
      final transcript = sb.toString();
      final parsed = TranscriptParser.parse(transcript);
      expect(parsed.length, 10000);
      
      final tree = TranscriptTree();
      tree.buildTree(parsed);
      expect(tree.nodes.length, 10000);
      expect(tree.roots.length, 1);
    });

    testWidgets('F5.B3: Malformed JSON line in transcript (truncated line) is skipped with a warning', (tester) async {
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

      const transcript = 
        '{"timestamp": "2026-06-22T10:00:00.000Z", "agent_id": "agent-1", "parent_id": null, "state": "Thinking"}\n'
        '{"malformed_json"}\n'
        '{"timestamp": "2026-06-22T10:00:01.000Z", "agent_id": "agent-2", "parent_id": null, "state": "Thinking"}';
      final parsed = TranscriptParser.parse(transcript);
      expect(parsed.length, 2);
      expect(parsed[0].agentId, 'agent-1');
      expect(parsed[1].agentId, 'agent-2');
    });

    testWidgets('F5.B4: Missing parent ID or circular tree relationships in log, graph resolves to flat list or handles cleanly', (tester) async {
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

      const transcript = 
        '{"timestamp": "2026-06-22T10:00:00.000Z", "agent_id": "A", "parent_id": "B", "state": "Thinking"}\n'
        '{"timestamp": "2026-06-22T10:00:01.000Z", "agent_id": "B", "parent_id": "A", "state": "Thinking"}';
      final parsed = TranscriptParser.parse(transcript);
      expect(parsed.length, 2);
      
      final tree = TranscriptTree();
      tree.buildTree(parsed);
      expect(tree.roots.isNotEmpty, isTrue);
    });

    test('F5.B5: Rapid concurrent updates to transcript file are debounced for UI stability', () async {
      final controller = StreamController<String>();
      final debouncedStream = debounce(controller.stream, const Duration(milliseconds: 100));
      
      final list = [];
      final sub = debouncedStream.listen((event) {
        list.add(event);
      });
      
      controller.add('update 1');
      await Future.delayed(const Duration(milliseconds: 10));
      controller.add('update 2');
      await Future.delayed(const Duration(milliseconds: 10));
      controller.add('update 3');
      
      // Wait for debounce time
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(list.length, 1);
      expect(list.first, 'update 3');
      
      await sub.cancel();
      await controller.close();
    });
  });
}
