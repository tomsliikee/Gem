import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/data/repositories/agy_process_runner.dart';
import 'package:gem/domain/entities/subagent_node.dart';
import 'package:gem/presentation/providers/providers.dart';
import 'mocks/mock_agy_process.dart';

void main() {
  group('ProcessAgyProcessRunner and ProcessAgyProcess tests', () {
    final runner = ProcessAgyProcessRunner();

    test('verifyExecutable resolves existing commands in PATH', () async {
      final shExists = await runner.verifyExecutable('sh');
      expect(shExists, isTrue);

      final absoluteShExists = await runner.verifyExecutable('/bin/sh');
      expect(absoluteShExists, isTrue);

      final nonexistent = await runner.verifyExecutable('nonexistent-command-xyz');
      expect(nonexistent, isFalse);
    });

    test('verifyExecutable handles files without execution permissions', () async {
      final tempDir = await Directory.systemTemp.createTemp('gem_test_runner');
      final tempFile = File('${tempDir.path}/no_exec.txt');
      await tempFile.writeAsString('hello world');
      
      final isExec = await runner.verifyExecutable(tempFile.path);
      expect(isExec, isFalse);

      await tempDir.delete(recursive: true);
    });

    test('start actually runs the executable and communicates', () async {
      final proc = await runner.start('sh', ['-c', 'echo "hello from test"']);
      final exitCodeFuture = proc.exitCode;
      
      final stdoutList = await proc.stdout.transform(utf8.decoder).toList();
      final fullStdout = stdoutList.join();
      expect(fullStdout, contains('hello from test'));
      
      final code = await exitCodeFuture;
      expect(code, 0);
    });
  });

  group('SettingsProvider tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('settingsProvider starts with null and persists path', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(settingsProvider), isNull);

      await container.read(settingsProvider.notifier).setCliOverridePath('/custom/path/agy');
      expect(container.read(settingsProvider), '/custom/path/agy');

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('cli_override_path'), '/custom/path/agy');

      await container.read(settingsProvider.notifier).setCliOverridePath(null);
      expect(container.read(settingsProvider), isNull);
      expect(prefs.getString('cli_override_path'), isNull);
    });
  });

  group('ProcessStateProvider tests', () {
    test('starts process and aggregates output from stdout/stderr', () async {
      final fakeRunner = FakeAgyProcessRunner();
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(fakeRunner),
        ],
      );
      addTearDown(container.dispose);

      final stateNotifier = container.read(processStateProvider.notifier);
      
      expect(container.read(processStateProvider).isRunning, isFalse);

      final started = await stateNotifier.startProcess('agy', []);
      expect(started, isTrue);
      expect(container.read(processStateProvider).isRunning, isTrue);

      final activeProc = fakeRunner.activeProcess!;

      activeProc.simulateStdout('Initializing subagent...\n');
      await Future.delayed(Duration.zero);
      expect(container.read(processStateProvider).outputBuffer, contains('Initializing subagent...'));

      activeProc.simulateStderr('Warn: low memory\n');
      await Future.delayed(Duration.zero);
      expect(container.read(processStateProvider).outputBuffer, contains('Warn: low memory'));

      stateNotifier.writeInput('world');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(container.read(processStateProvider).outputBuffer, contains('Echo: world'));

      activeProc.simulateExit(0);
      await Future.delayed(Duration.zero);
      expect(container.read(processStateProvider).isRunning, isFalse);
      expect(container.read(processStateProvider).exitCode, 0);
    });

    test('handles invalid executable start failure', () async {
      final fakeRunner = FakeAgyProcessRunner()..pathValid = false;
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(fakeRunner),
        ],
      );
      addTearDown(container.dispose);

      final stateNotifier = container.read(processStateProvider.notifier);
      final started = await stateNotifier.startProcess('invalid-path', []);
      expect(started, isFalse);
      expect(container.read(processStateProvider).isRunning, isFalse);
      expect(container.read(processStateProvider).error, contains('Executable not found or not executable'));
    });

    test('ProcessStateNotifier caps outputBuffer to 50,000 characters', () async {
      final fakeRunner = FakeAgyProcessRunner();
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(fakeRunner),
        ],
      );
      addTearDown(container.dispose);

      final stateNotifier = container.read(processStateProvider.notifier);
      await stateNotifier.startProcess('agy', []);
      final activeProc = fakeRunner.activeProcess!;

      final chunk1 = 'A' * 30000;
      final chunk2 = 'B' * 20010;
      activeProc.simulateStdout(chunk1);
      await Future.delayed(Duration.zero);
      activeProc.simulateStdout(chunk2);
      await Future.delayed(Duration.zero);

      final buffer = container.read(processStateProvider).outputBuffer;
      expect(buffer.length, 50000);
      expect(buffer.startsWith('A'), isTrue);
      expect(buffer.endsWith('B'), isTrue);
      expect(buffer.contains('B' * 20010), isTrue);
    });

    test('ProcessStateNotifier clears _process reference on exit', () async {
      final fakeRunner = FakeAgyProcessRunner();
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(fakeRunner),
        ],
      );
      addTearDown(container.dispose);

      final stateNotifier = container.read(processStateProvider.notifier);
      await stateNotifier.startProcess('agy', []);
      final activeProc = fakeRunner.activeProcess!;

      expect(container.read(processStateProvider).isRunning, isTrue);

      activeProc.simulateExit(0);
      await Future.delayed(Duration.zero);

      expect(container.read(processStateProvider).isRunning, isFalse);
      expect(container.read(processStateProvider).exitCode, 0);
    });
  });

  group('SubagentTreeProvider tests', () {
    test('updates nodes and selectors compute root/children nodes correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subagentTreeProvider.notifier);

      final node1 = SubagentNode(
        timestamp: DateTime.now(),
        agentId: 'agent-1',
        parentId: null,
        state: AgentState.thinking,
        log: 'Init',
      );
      final node2 = SubagentNode(
        timestamp: DateTime.now(),
        agentId: 'agent-2',
        parentId: 'agent-1',
        state: AgentState.runningCommand,
        log: 'Command',
      );
      final node3 = SubagentNode(
        timestamp: DateTime.now(),
        agentId: 'agent-3',
        parentId: 'agent-1',
        state: AgentState.completed,
        log: 'Done',
      );

      notifier.updateNode(node1);
      notifier.updateNode(node2);
      notifier.updateNode(node3);

      final tree = container.read(subagentTreeProvider);
      expect(tree.length, 3);
      expect(tree['agent-1'], node1);

      final rootNodes = container.read(rootNodesProvider);
      expect(rootNodes.length, 1);
      expect(rootNodes.first.agentId, 'agent-1');

      final childrenOf1 = container.read(childrenNodesProvider('agent-1'));
      expect(childrenOf1.length, 2);
      expect(childrenOf1.map((n) => n.agentId), unorderedEquals(['agent-2', 'agent-3']));

      final childrenOf2 = container.read(childrenNodesProvider('agent-2'));
      expect(childrenOf2, isEmpty);
    });

    test('updateNode and updateNodes prevent out-of-order logs from overwriting newer states', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subagentTreeProvider.notifier);

      final now = DateTime.now();
      final nodeNew = SubagentNode(
        timestamp: now,
        agentId: 'agent-ooo',
        parentId: null,
        state: AgentState.completed,
        log: 'Completed State',
      );
      final nodeOld = SubagentNode(
        timestamp: now.subtract(const Duration(minutes: 5)),
        agentId: 'agent-ooo',
        parentId: null,
        state: AgentState.thinking,
        log: 'Old Thinking State',
      );

      // 1. Single update: new then old
      notifier.updateNode(nodeNew);
      notifier.updateNode(nodeOld);

      expect(container.read(subagentTreeProvider)['agent-ooo']!.state, AgentState.completed);
      expect(container.read(subagentTreeProvider)['agent-ooo']!.log, 'Completed State');

      // 2. Batch update (updateNodes): new then old
      notifier.clear();
      notifier.updateNodes([nodeNew, nodeOld]);
      expect(container.read(subagentTreeProvider)['agent-ooo']!.state, AgentState.completed);

      // 3. Batch update (updateNodes): old then new
      notifier.clear();
      notifier.updateNodes([nodeOld, nodeNew]);
      expect(container.read(subagentTreeProvider)['agent-ooo']!.state, AgentState.completed);
    });
  });

  group('BrainMonitor tests', () {
    late Directory tempDir;
    
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gem_brain_monitor_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('scans existing JSONL files on startup', () async {
      final file1 = File('${tempDir.path}/log1.jsonl');
      await file1.writeAsString(
        '{"timestamp": "2026-06-19T18:50:00.000Z", "agent_id": "agent-s1", "parent_id": null, "state": "Thinking", "log": "Init"}\n'
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final tree = container.read(subagentTreeProvider);
      expect(tree.containsKey('agent-s1'), isTrue);
      expect(tree['agent-s1']!.log, 'Init');
      
      monitor.stop();
    });

    test('detects appended bytes in real-time', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/live.jsonl');
      await file.writeAsString(
        '{"timestamp": "2026-06-19T18:50:00.000Z", "agent_id": "agent-live", "parent_id": null, "state": "Thinking", "log": "Step 1"}\n'
      );

      await Future.delayed(const Duration(milliseconds: 1100));

      var tree = container.read(subagentTreeProvider);
      if (!tree.containsKey('agent-live')) {
        await Future.delayed(const Duration(seconds: 1));
        tree = container.read(subagentTreeProvider);
      }

      expect(tree.containsKey('agent-live'), isTrue);
      expect(tree['agent-live']!.log, 'Step 1');

      final sink = file.openWrite(mode: FileMode.append);
      sink.write('{"timestamp": "2026-06-19T18:51:00.000Z", "agent_id": "agent-live", "parent_id": null, "state": "Completed", "log": "Step 2"}\n');
      await sink.close();

      await Future.delayed(const Duration(milliseconds: 1100));
      tree = container.read(subagentTreeProvider);
      if (tree['agent-live']!.state != AgentState.completed) {
        await Future.delayed(const Duration(seconds: 1));
        tree = container.read(subagentTreeProvider);
      }

      expect(tree['agent-live']!.state, AgentState.completed);
      expect(tree['agent-live']!.log, 'Step 2');

      monitor.stop();
    });

    test('buffers partial lines correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/partial.jsonl');
      
      await file.writeAsString('{"timestamp": "2026-06-19T18:50:00.000Z", "agent_id": "agent-p1", "parent_id": null');
      
      await Future.delayed(const Duration(milliseconds: 500));
      expect(container.read(subagentTreeProvider).containsKey('agent-p1'), isFalse);

      final sink = file.openWrite(mode: FileMode.append);
      sink.write(', "state": "Failed", "log": "Err"}\n');
      await sink.close();

      await Future.delayed(const Duration(milliseconds: 1100));
      var tree = container.read(subagentTreeProvider);
      if (!tree.containsKey('agent-p1')) {
        await Future.delayed(const Duration(seconds: 1));
        tree = container.read(subagentTreeProvider);
      }

      expect(tree.containsKey('agent-p1'), isTrue);
      expect(tree['agent-p1']!.state, AgentState.failed);

      monitor.stop();
    });
  });
}
