// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/data/repositories/agy_process_runner.dart';
import 'package:gem/domain/entities/subagent_node.dart';
import 'package:gem/presentation/providers/providers.dart';

void main() {
  group('1. verifyExecutable PATH-based resolution and permissions checking', () {
    final runner = ProcessAgyProcessRunner();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('verify_exec_challenger');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('verifyExecutable returns false for invalid paths or empty paths', () async {
      expect(await runner.verifyExecutable(''), isFalse);
      expect(await runner.verifyExecutable('   '), isFalse);
      expect(await runner.verifyExecutable('/nonexistent/path/to/exe'), isFalse);
    });

    test('verifyExecutable returns false for directories', () async {
      expect(await runner.verifyExecutable(tempDir.path), isFalse);
      expect(await runner.verifyExecutable('/tmp'), isFalse);
    });

    test('verifyExecutable returns false for non-executable files', () async {
      final nonExecFile = File('${tempDir.path}/non_exec.sh');
      await nonExecFile.writeAsString('#!/bin/sh\necho "Hello"');
      await Process.run('chmod', ['644', nonExecFile.path]);

      expect(await runner.verifyExecutable(nonExecFile.path), isFalse);
    });

    test('verifyExecutable returns true for executable files', () async {
      final execFile = File('${tempDir.path}/exec.sh');
      await execFile.writeAsString('#!/bin/sh\necho "Hello"');
      await Process.run('chmod', ['+x', execFile.path]);

      expect(await runner.verifyExecutable(execFile.path), isTrue);
    });

    test('verifyExecutable resolves command via custom PATH', () async {
      final customBinDir = Directory('${tempDir.path}/bin');
      await customBinDir.create(recursive: true);
      final customCmd = File('${customBinDir.path}/my-custom-cmd');
      await customCmd.writeAsString('#!/bin/sh\necho "Custom Command"');
      await Process.run('chmod', ['+x', customCmd.path]);

      final testScript = File('${tempDir.path}/run_sub_test.dart');
      await testScript.writeAsString('''
import 'dart:io';
import '/home/toms/projects/Gem/lib/data/repositories/agy_process_runner.dart';

void main() async {
  final runner = ProcessAgyProcessRunner();
  final result = await runner.verifyExecutable('my-custom-cmd');
  print('RESOLVED_RESULT: \$result');
  exit(result ? 0 : 1);
}
''');

      // Extend the existing PATH instead of replacing it completely
      final currentPath = Platform.environment['PATH'] ?? Platform.environment['Path'] ?? Platform.environment['path'] ?? '';
      final separator = Platform.isWindows ? ';' : ':';
      final extendedPath = '${customBinDir.path}$separator$currentPath';

      // Run via the 'dart' command directly
      final res = await Process.run(
        'dart',
        [testScript.path],
        environment: {
          'PATH': extendedPath,
        },
      );

      print('Subprocess stdout: ${res.stdout}');
      print('Subprocess stderr: ${res.stderr}');
      expect(res.exitCode, 0, reason: 'Command not resolved in custom PATH. Subprocess output: ${res.stdout} ${res.stderr}');
    });
  });

  group('2. BrainMonitor stress tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brain_monitor_challenger');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('handles concurrent file appends in real-time', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/concurrent.jsonl');
      await file.writeAsString(
        '{"timestamp": "2026-06-22T12:00:00.000Z", "agent_id": "agent-root", "parent_id": null, "state": "Thinking", "log": "Init"}\n'
      );

      // Perform rapid sequential appends (which fire watcher events rapidly, testing the lock and poll backup)
      for (int i = 0; i < 20; i++) {
        final secStr = i.toString().padLeft(2, '0');
        await file.writeAsString(
          '{"timestamp": "2026-06-22T12:00:$secStr.000Z", "agent_id": "agent-$i", "parent_id": "agent-root", "state": "Thinking", "log": "Log $i"}\n',
          mode: FileMode.append
        );
      }

      // Wait for poll timer or watcher to finish processing (at least 2.5 seconds to cover the 1s poll interval)
      await Future.delayed(const Duration(milliseconds: 2500));

      final tree = container.read(subagentTreeProvider);
      
      print('Parsed tree nodes size: ${tree.length}');
      print('File content length: ${await file.length()}');

      expect(tree.length, 21, reason: 'Some concurrent writes were lost');
      monitor.stop();
    });

    test('handles empty files', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/empty.jsonl');
      await file.create();

      await Future.delayed(const Duration(milliseconds: 500));
      expect(container.read(subagentTreeProvider), isEmpty);

      await file.writeAsString(
        '{"timestamp": "2026-06-22T12:00:00.000Z", "agent_id": "agent-empty-test", "parent_id": null, "state": "Completed"}\n'
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      final tree = container.read(subagentTreeProvider);
      expect(tree.containsKey('agent-empty-test'), isTrue);
      expect(tree['agent-empty-test']!.state, AgentState.completed);

      monitor.stop();
    });

    test('handles truncated files and checks buffer pollution bug', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/truncated.jsonl');
      
      await file.writeAsString('{"timestamp": "2026-06-22T12:00:00.000Z", "agent_id": "agent-partial"');
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(container.read(subagentTreeProvider).containsKey('agent-partial'), isFalse);

      // Truncate to 0
      await file.writeAsString('', mode: FileMode.write);
      await Future.delayed(const Duration(milliseconds: 500));

      // Append new line
      await file.writeAsString(
        '{"timestamp": "2026-06-22T12:01:00.000Z", "agent_id": "agent-new", "parent_id": null, "state": "Thinking"}\n',
        mode: FileMode.append
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      final tree = container.read(subagentTreeProvider);
      
      final bugPresent = !tree.containsKey('agent-new');
      print('Buffer pollution bug present: $bugPresent');
      
      expect(tree.containsKey('agent-new'), isTrue, reason: 'Buffer pollution prevented parsing new line after truncation');
      monitor.stop();
    });

    test('handles out-of-order logs (timestamp regression test)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/outoforder.jsonl');

      await file.writeAsString(
        '{"timestamp": "2026-06-22T12:10:00.000Z", "agent_id": "agent-ooo", "parent_id": null, "state": "Completed"}\n'
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(container.read(subagentTreeProvider)['agent-ooo']!.state, AgentState.completed);

      await file.writeAsString(
        '{"timestamp": "2026-06-22T12:00:00.000Z", "agent_id": "agent-ooo", "parent_id": null, "state": "Thinking"}\n',
        mode: FileMode.append
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final state = container.read(subagentTreeProvider)['agent-ooo']!.state;
      print('Final state for out-of-order log: $state');
      
      expect(state, AgentState.completed, reason: 'State regressed to Thinking due to out-of-order log line');
      monitor.stop();
    });

    test('handles malformed JSON lines gracefully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(brainMonitorProvider);
      await monitor.start(directoryOverride: tempDir.path);

      final file = File('${tempDir.path}/malformed.jsonl');
      await file.writeAsString(
        '{"invalid-json": true\n'
        '{"timestamp": "2026-06-22T12:00:00.000Z", "agent_id": "agent-valid", "parent_id": null, "state": "Thinking"}\n'
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      final tree = container.read(subagentTreeProvider);
      expect(tree.containsKey('agent-valid'), isTrue);
      expect(tree['agent-valid']!.state, AgentState.thinking);

      monitor.stop();
    });
  });

  group('3. ProcessStateNotifier lifecycle and crash tests', () {
    test('handles process crashes with non-zero exit code', () async {
      final runner = ProcessAgyProcessRunner();
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(processStateProvider.notifier);
      final started = await notifier.startProcess('sh', ['-c', 'exit 42']);
      expect(started, isTrue);
      
      while (container.read(processStateProvider).isRunning) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final state = container.read(processStateProvider);
      expect(state.isRunning, isFalse);
      expect(state.exitCode, 42);
    });

    test('handles stdin input correctly', () async {
      final runner = ProcessAgyProcessRunner();
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(processStateProvider.notifier);
      final started = await notifier.startProcess('sh', ['-c', 'read input && echo "Received: \$input"']);
      expect(started, isTrue);

      notifier.writeInput('hello challenger\n');

      while (container.read(processStateProvider).isRunning) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final state = container.read(processStateProvider);
      expect(state.outputBuffer, contains('Received: hello challenger'));
    });

    test('handles user force-termination', () async {
      final runner = ProcessAgyProcessRunner();
      final container = ProviderContainer(
        overrides: [
          agyProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(processStateProvider.notifier);
      final started = await notifier.startProcess('sh', ['-c', 'sleep 100']);
      expect(started, isTrue);
      expect(container.read(processStateProvider).isRunning, isTrue);

      await notifier.stopProcess();
      expect(container.read(processStateProvider).isRunning, isFalse);
    });

    test('verifies broadcast stream prevents single-subscription stdout issue', () async {
      final runner = ProcessAgyProcessRunner();
      final proc = await runner.start('sh', ['-c', 'echo "hello"']);
      
      final stream1 = proc.stdout;
      stream1.listen((_) {});

      // Exposing as broadcast stream allows multiple listeners without throwing StateError
      expect(
        () => proc.stdout.listen((_) {}),
        returnsNormally,
      );

      await proc.exitCode;
    });
  });
}
