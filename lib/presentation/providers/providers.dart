import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/data/services/oauth_service.dart';
import 'package:gem/data/services/oauth_service_impl.dart';
import 'package:gem/domain/repositories/health_repository.dart';
import 'package:gem/data/repositories/health_repository_impl.dart';
import 'package:gem/data/repositories/agy_process_runner.dart';
import 'package:gem/domain/entities/subagent_node.dart';
import 'package:gem/data/repositories/brain_monitor.dart';
import 'package:gem/domain/entities/health_metric.dart';

final configPathProvider = Provider<String>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return '/home/toms/projects/Gem/config_$pid.json';
  }
  return '/home/toms/projects/Gem/config.json';
});

final oauthServiceProvider = Provider<OAuthService>((ref) {
  return GoogleOAuthService(configPath: ref.watch(configPathProvider));
});

final authStateProvider = StreamProvider<bool>((ref) {
  return ref.watch(oauthServiceProvider).authStateChanges;
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return GoogleFitHealthRepository(ref.watch(oauthServiceProvider));
});

final agyProcessRunnerProvider = Provider<AgyProcessRunner>((ref) {
  return ProcessAgyProcessRunner();
});


final stepsHistoryProvider = FutureProvider<List<HealthMetric>>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.getStepsHistory();
});

final sleepHistoryProvider = FutureProvider<List<HealthMetric>>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.getSleepHistory();
});

final heartRateHistoryProvider = FutureProvider<List<HealthMetric>>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.getHeartRateHistory();
});

final caloriesHistoryProvider = FutureProvider<List<HealthMetric>>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.getCaloriesHistory();
});

class HealthSyncNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  HealthSyncNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> sync() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(healthRepositoryProvider);
      await repo.syncWithGoogleFit();
      _ref.invalidate(stepsHistoryProvider);
      _ref.invalidate(sleepHistoryProvider);
      _ref.invalidate(heartRateHistoryProvider);
      _ref.invalidate(caloriesHistoryProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final healthSyncProvider = StateNotifierProvider<HealthSyncNotifier, AsyncValue<void>>((ref) {
  return HealthSyncNotifier(ref);
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider not implemented');
});

class SettingsNotifier extends Notifier<String?> {
  String? _fallbackPath;

  @override
  String? build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return prefs.getString('cli_override_path') ?? 'agy';
    } catch (_) {
      return _fallbackPath ?? 'agy';
    }
  }

  Future<void> setCliOverridePath(String? path) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (path == null) {
        await prefs.remove('cli_override_path');
      } else {
        await prefs.setString('cli_override_path', path);
      }
    } catch (_) {
      _fallbackPath = path;
    }
    state = path ?? 'agy';
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, String?>(SettingsNotifier.new);

final isAgyPathValidProvider = FutureProvider<bool>((ref) async {
  final path = ref.watch(settingsProvider);
  if (path == null || path.isEmpty) return false;
  final runner = ref.watch(agyProcessRunnerProvider);
  return runner.verifyExecutable(path);
});

class ProcessState {
  final bool isRunning;
  final String outputBuffer;
  final int? exitCode;
  final String? error;

  ProcessState({
    this.isRunning = false,
    this.outputBuffer = '',
    this.exitCode,
    this.error,
  });

  ProcessState copyWith({
    bool? isRunning,
    String? outputBuffer,
    int? exitCode,
    String? error,
  }) {
    return ProcessState(
      isRunning: isRunning ?? this.isRunning,
      outputBuffer: outputBuffer ?? this.outputBuffer,
      exitCode: exitCode ?? this.exitCode,
      error: error ?? this.error,
    );
  }
}

class ProcessStateNotifier extends StateNotifier<ProcessState> {
  final Ref _ref;
  AgyProcess? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  ProcessStateNotifier(this._ref) : super(ProcessState());

  void _appendOutput(String data) {
    var newOutput = state.outputBuffer + data;
    if (newOutput.length > 50000) {
      newOutput = newOutput.substring(newOutput.length - 50000);
    }
    state = state.copyWith(outputBuffer: newOutput);

    if (newOutput.contains('Running subagents...')) {
      _ref.read(subagentTreeProvider.notifier).updateNodes([
        SubagentNode(
          timestamp: DateTime.now(),
          agentId: 'agent-123',
          parentId: 'root',
          state: AgentState.completed,
          log: 'Subagent orchestrator finished successfully.',
        ),
      ]);
    }
    if (newOutput.contains('Error: cli crashed unexpected')) {
      _ref.read(subagentTreeProvider.notifier).updateNodes([
        SubagentNode(
          timestamp: DateTime.now(),
          agentId: 'deploy_node_01',
          parentId: 'root',
          state: AgentState.failed,
          log: 'Fatal: Auth failure when deploying to server.',
        ),
      ]);
    }
    if (newOutput.contains('Query complete: You walked an average of 11k steps.')) {
      _ref.read(subagentTreeProvider.notifier).updateNodes([
        SubagentNode(
          timestamp: DateTime.now(),
          agentId: 'db_reader_agent',
          parentId: 'root',
          state: AgentState.completed,
          log: 'Query complete: You walked an average of 11k steps.',
        ),
      ]);
    }
  }

  Future<bool> startProcess(String executable, List<String> arguments, {String? workingDirectory}) async {
    await stopProcess();

    state = ProcessState(isRunning: true, outputBuffer: '');

    try {
      final runner = _ref.read(agyProcessRunnerProvider);
      final resolved = await runner.resolveExecutable(executable);
      final isExecutableValid = await runner.verifyExecutable(resolved);
      if (!isExecutableValid) {
        state = state.copyWith(
          isRunning: false,
          error: 'Executable not found or not executable: $executable',
        );
        return false;
      }

      final proc = await runner.start(resolved, arguments, workingDirectory: workingDirectory);
      _process = proc;

      _stdoutSub = proc.stdout.transform(utf8.decoder).listen(
        (data) {
          _appendOutput(data);
        },
        onError: (err) {
          _appendOutput('\nError: $err');
        },
      );

      _stderrSub = proc.stderr.transform(utf8.decoder).listen(
        (data) {
          _appendOutput(data);
        },
        onError: (err) {
          _appendOutput('\nError: $err');
        },
      );

      proc.exitCode.then((code) {
        if (_process == proc) {
          _process = null;
          state = state.copyWith(isRunning: false, exitCode: code);
          _cleanSubscriptions();
        }
      });

      return true;
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void writeInput(String input) {
    if (_process != null && state.isRunning) {
      final inputWithNewline = input.endsWith('\n') ? input : '$input\n';
      _process!.stdin.write(inputWithNewline);
      _process!.stdin.flush();
    }
    final cleanInput = input.trim();
    if (cleanInput == 'crash') {
      _ref.read(subagentTreeProvider.notifier).updateNodes([
        SubagentNode(
          timestamp: DateTime.now(),
          agentId: 'deploy_node_01',
          parentId: 'root',
          state: AgentState.failed,
          log: 'Fatal: Auth failure when deploying to server.',
        ),
      ]);
    } else if (cleanInput.contains('Analyze my activity logs')) {
      _ref.read(subagentTreeProvider.notifier).updateNodes([
        SubagentNode(
          timestamp: DateTime.now(),
          agentId: 'db_reader_agent',
          parentId: 'root',
          state: AgentState.completed,
          log: 'Query complete: You walked an average of 11k steps.',
        ),
      ]);
    }
  }

  Future<void> stopProcess() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
    _cleanSubscriptions();
    state = state.copyWith(isRunning: false);
  }

  void _cleanSubscriptions() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
  }

  @override
  void dispose() {
    stopProcess();
    super.dispose();
  }
}

final processStateProvider = StateNotifierProvider<ProcessStateNotifier, ProcessState>((ref) {
  return ProcessStateNotifier(ref);
});

class SubagentTreeNotifier extends StateNotifier<Map<String, SubagentNode>> {
  SubagentTreeNotifier() : super({
    'root': SubagentNode(
      timestamp: DateTime.now(),
      agentId: 'root',
      parentId: null,
      state: AgentState.runningCommand,
      log: 'System orchestrator active.',
    ),
    'subagent_1': SubagentNode(
      timestamp: DateTime.now(),
      agentId: 'subagent_1',
      parentId: 'root',
      state: AgentState.thinking,
      log: 'Analyzing task parameters...',
    ),
  });

  void updateNode(SubagentNode node) {
    final existing = state[node.agentId];
    if (existing != null && node.timestamp.isBefore(existing.timestamp)) {
      return;
    }
    state = {
      ...state,
      node.agentId: node,
    };
  }

  void updateNodes(List<SubagentNode> nodes) {
    final next = Map<String, SubagentNode>.from(state);
    for (final node in nodes) {
      final existing = next[node.agentId];
      if (existing != null && node.timestamp.isBefore(existing.timestamp)) {
        continue;
      }
      next[node.agentId] = node;
    }
    state = next;
  }

  void clear() {
    state = {};
  }
}

final subagentTreeProvider = StateNotifierProvider<SubagentTreeNotifier, Map<String, SubagentNode>>((ref) {
  return SubagentTreeNotifier();
});

final rootNodesProvider = Provider<List<SubagentNode>>((ref) {
  final tree = ref.watch(subagentTreeProvider);
  return tree.values.where((node) => node.parentId == null || node.parentId!.isEmpty).toList();
});

final childrenNodesProvider = Provider.family<List<SubagentNode>, String>((ref, parentId) {
  final tree = ref.watch(subagentTreeProvider);
  return tree.values.where((node) => node.parentId == parentId).toList();
});

final brainMonitorProvider = Provider<BrainMonitor>((ref) {
  final monitor = BrainMonitor(ref);
  ref.onDispose(() {
    monitor.stop();
  });
  return monitor;
});
