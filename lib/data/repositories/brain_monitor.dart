import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/domain/entities/subagent_node.dart';
import 'package:gem/presentation/providers/providers.dart';

class BrainMonitor {
  final Ref _ref;
  Directory? _directory;
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  Timer? _pollTimer;
  bool _isMonitoring = false;

  final Map<String, int> _offsets = {};
  final Map<String, String> _buffers = {};
  final Map<String, DateTime> _lastModified = {};
  final Map<String, int> _lastLength = {};
  final Set<String> _processingFiles = {};

  BrainMonitor(this._ref);

  String _resolveHomePath(String path) {
    if (path.startsWith('~')) {
      final home = Platform.isWindows
          ? Platform.environment['USERPROFILE']
          : Platform.environment['HOME'];
      if (home == null) {
        throw StateError('Failed to resolve home directory environment variable');
      }
      return path.replaceFirst('~', home);
    }
    return path;
  }

  Future<void> start({String? directoryOverride}) async {
    if (_isMonitoring) return;
    _isMonitoring = true;

    final path = directoryOverride ?? _resolveHomePath('~/.gemini/antigravity-cli/brain');
    _directory = Directory(path);

    if (!await _directory!.exists()) {
      await _directory!.create(recursive: true);
    }

    // 1. Scan existing files on startup
    await _scanDirectory();

    // 2. Start monitoring (both watch and poll for maximum resilience)
    _startWatching();
    _startPolling();
  }

  Future<void> _scanDirectory() async {
    if (_directory == null) return;
    try {
      final files = await _directory!
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
          .cast<File>()
          .toList();

      for (final file in files) {
        await _processFile(file.path);
      }
    } catch (e) {
      // Gracefully handle any scanning issues
    }
  }

  Future<void> _processFile(String filePath) async {
    if (_processingFiles.contains(filePath)) return;
    _processingFiles.add(filePath);
    
    final file = File(filePath);
    if (!await file.exists()) {
      _processingFiles.remove(filePath);
      return;
    }

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final start = _offsets[filePath] ?? 0;
      final end = await raf.length();
      final stat = await file.stat();

      if (end < start) {
        // File truncated or reset
        _buffers[filePath] = '';
        await raf.setPosition(0);
        final bytes = await raf.read(end);
        _offsets[filePath] = end;
        _handleNewBytes(filePath, bytes);
      } else if (end > start) {
        await raf.setPosition(start);
        final bytes = await raf.read(end - start);
        _offsets[filePath] = end;
        _handleNewBytes(filePath, bytes);
      }

      _lastModified[filePath] = stat.modified;
      _lastLength[filePath] = end;
    } catch (e) {
      // Ignored: logging could be wired up here
    } finally {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }
      _processingFiles.remove(filePath);
    }
  }

  void _handleNewBytes(String filePath, List<int> bytes) {
    if (bytes.isEmpty) return;
    final text = utf8.decode(bytes, allowMalformed: true);
    final buffer = _buffers[filePath] ?? '';
    final fullText = buffer + text;
    final lines = fullText.split('\n');

    if (fullText.endsWith('\n')) {
      _buffers[filePath] = '';
      for (int i = 0; i < lines.length - 1; i++) {
        _parseAndPushLine(lines[i]);
      }
    } else {
      _buffers[filePath] = lines.last;
      for (int i = 0; i < lines.length - 1; i++) {
        _parseAndPushLine(lines[i]);
      }
    }
  }

  void _parseAndPushLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    try {
      final jsonMap = jsonDecode(trimmed) as Map<String, dynamic>;
      final node = SubagentNode.fromJson(jsonMap);
      _ref.read(subagentTreeProvider.notifier).updateNode(node);
    } catch (e) {
      // Gracefully ignore parse errors for malformed/incomplete JSON lines
    }
  }

  void _startWatching() {
    try {
      _watchSubscription = _directory!.watch().listen(
        (event) async {
          if (event.path.endsWith('.jsonl')) {
            await _processFile(event.path);
          }
        },
        onError: (err) {
          _startPolling();
        },
      );
    } catch (e) {
      _startPolling();
    }
  }

  void _startPolling() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isMonitoring || _directory == null) return;
      try {
        final files = await _directory!
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
            .cast<File>()
            .toList();

        for (final file in files) {
          final stat = await file.stat();
          final lastMod = _lastModified[file.path];
          final lastLen = _lastLength[file.path];
          final currentLen = stat.size;

          if (lastMod == null ||
              stat.modified.isAfter(lastMod) ||
              lastLen == null ||
              currentLen != lastLen) {
            await _processFile(file.path);
          }
        }
      } catch (e) {
        // Handle polling error
      }
    });
  }

  void stop() {
    _isMonitoring = false;
    _watchSubscription?.cancel();
    _watchSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _offsets.clear();
    _buffers.clear();
    _lastModified.clear();
    _lastLength.clear();
    _processingFiles.clear();
  }
}
