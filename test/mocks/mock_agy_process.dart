import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gem/data/repositories/agy_process_runner.dart';

class MockIOSink implements IOSink {
  final Function(List<int>) onWrite;
  MockIOSink(this.onWrite);
  
  @override
  void add(List<int> data) => onWrite(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (var data in stream) {
      onWrite(data);
    }
  }

  @override
  void write(Object? object) => onWrite(utf8.encode(object.toString()));

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = ""]) => onWrite(utf8.encode('${object ?? ""}\n'));

  @override
  Future get done => Future.value(null);

  @override
  Future close() async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding encoding) {}

  @override
  Future flush() => Future.value(null);
}

class FakeAgyProcess implements AgyProcess {
  final _stdoutController = StreamController<List<int>>();
  final _stderrController = StreamController<List<int>>();
  final _exitCompleter = Completer<int>();
  late final IOSink _stdinSink;

  FakeAgyProcess() {
    _stdinSink = MockIOSink((bytes) {
      final input = utf8.decode(bytes);
      _handleInput(input);
    });
  }

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => _stdinSink;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exitCompleter.isCompleted) {
      simulateStdout('\n[Process Terminated by User]\n');
      _exitCompleter.complete(-1);
      _stdoutController.close();
      _stderrController.close();
      return true;
    }
    return false;
  }

  void simulateStdout(String text) {
    if (!_stdoutController.isClosed) {
      _stdoutController.add(utf8.encode(text));
    }
  }

  void simulateStderr(String text) {
    if (!_stderrController.isClosed) {
      _stderrController.add(utf8.encode(text));
    }
  }

  void simulateExit(int code) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
      _stdoutController.close();
      _stderrController.close();
    }
  }

  void _handleInput(String input) {
    final cleanInput = input.trim();
    if (cleanInput == 'hello' || cleanInput.contains('Find and fix project errors')) {
      simulateStdout('Running subagents...\n');
      simulateStdout('Echo: $cleanInput\n');
    } else if (cleanInput == 'crash') {
      simulateStderr('Error: cli crashed unexpected.\n');
      scheduleMicrotask(() {
        scheduleMicrotask(() {
          simulateExit(1);
        });
      });
    } else if (cleanInput.contains('Analyze my activity logs')) {
      simulateStdout('Query complete: You walked an average of 11k steps.\n');
    } else {
      simulateStdout('Echo: $cleanInput\n');
    }
  }
}

class FakeAgyProcessRunner implements AgyProcessRunner {
  FakeAgyProcess? activeProcess;
  bool shouldFailToStart = false;
  bool pathValid = true;

  @override
  Future<AgyProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (shouldFailToStart || !pathValid) {
      throw ProcessException(executable, arguments, 'Executable failed to start');
    }
    final process = FakeAgyProcess();
    activeProcess = process;
    
    if (arguments.isNotEmpty) {
      scheduleMicrotask(() {
        for (final arg in arguments) {
          process._handleInput(arg);
        }
      });
    }
    
    return process;
  }

  @override
  Future<String> resolveExecutable(String path) async => path;

  @override
  Future<bool> verifyExecutable(String path) async {
    return pathValid && (path.endsWith('agy') || path.endsWith('agy.exe'));
  }
}
