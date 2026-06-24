import 'dart:async';
import 'dart:io';

abstract class AgyProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  IOSink get stdin;
  Future<int> get exitCode;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

abstract class AgyProcessRunner {
  Future<AgyProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
  Future<bool> verifyExecutable(String path);
  Future<String> resolveExecutable(String path);
}

class ProcessAgyProcess implements AgyProcess {
  final Process _process;
  late final Stream<List<int>> _stdout;
  late final Stream<List<int>> _stderr;
  ProcessAgyProcess(this._process) {
    _stdout = _process.stdout.asBroadcastStream();
    _stderr = _process.stderr.asBroadcastStream();
  }

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => _process.kill(signal);
}

class ProcessAgyProcessRunner implements AgyProcessRunner {
  @override
  Future<AgyProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return ProcessAgyProcess(process);
  }

  @override
  Future<String> resolveExecutable(String path) async {
    if (path.isEmpty) return path;

    final hasSeparator = path.contains('/') || (Platform.isWindows && path.contains('\\'));
    if (!hasSeparator) {
      // 1. Check system PATH
      final pathEnv = Platform.environment['PATH'] ?? Platform.environment['Path'] ?? Platform.environment['path'] ?? '';
      final separator = Platform.isWindows ? ';' : ':';
      final dirs = pathEnv.split(separator);
      for (final dir in dirs) {
        if (dir.isEmpty) continue;
        final resolvedPath = '$dir${Platform.pathSeparator}$path';
        if (await _isValidExecutableFile(resolvedPath)) {
          return resolvedPath;
        }
      }

      // 2. Check fallback paths (e.g. ~/.local/bin/agy)
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final fallbackPath = '$home/.local/bin/$path';
          if (await _isValidExecutableFile(fallbackPath)) {
            return fallbackPath;
          }
        }
      }
      return path;
    } else {
      // If it's already an absolute or relative path, check if it contains tilde ~
      if (path.startsWith('~/') && (Platform.isLinux || Platform.isMacOS)) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final resolved = path.replaceFirst('~', home);
          if (await _isValidExecutableFile(resolved)) {
            return resolved;
          }
        }
      }
      return path;
    }
  }

  @override
  Future<bool> verifyExecutable(String path) async {
    final resolved = await resolveExecutable(path);
    if (resolved == path) {
      final hasSeparator = path.contains('/') || (Platform.isWindows && path.contains('\\'));
      if (!hasSeparator) {
        return false;
      }
      return await _isValidExecutableFile(path);
    }
    return await _isValidExecutableFile(resolved);
  }

  Future<bool> _isValidExecutableFile(String filePath) async {
    if (Platform.isWindows) {
      final pathExt = Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD;.COM';
      final exts = pathExt.split(';').map((e) => e.toLowerCase()).toList();
      
      final lowerPath = filePath.toLowerCase();
      final hasExecutableExtension = exts.any((ext) => lowerPath.endsWith(ext));
      if (hasExecutableExtension) {
        final file = File(filePath);
        if (await file.exists() && (await FileSystemEntity.type(filePath)) == FileSystemEntityType.file) {
          return true;
        }
      } else {
        for (final ext in exts) {
          final extendedPath = '$filePath$ext';
          final file = File(extendedPath);
          if (await file.exists() && (await FileSystemEntity.type(extendedPath)) == FileSystemEntityType.file) {
            return true;
          }
        }
      }
      return false;
    } else {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        return false;
      }
      if ((stat.mode & 73) == 0) {
        return false;
      }
      return true;
    }
  }
}
