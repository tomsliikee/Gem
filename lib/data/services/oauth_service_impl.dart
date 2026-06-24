import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/app_config.dart';
import 'oauth_service.dart';

class LocalRedirectServer implements OAuthRedirectServer {
  HttpServer? _server;

  @override
  Future<int> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _server!.port;
  }

  @override
  Future<String> waitForCode({Duration timeout = const Duration(minutes: 5)}) async {
    final server = _server;
    if (server == null) {
      throw StateError('Server is not started.');
    }

    final completer = Completer<String>();
    StreamSubscription<HttpRequest>? subscription;
    Timer? timer;

    timer = Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Authentication timed out'));
      }
    });

    subscription = server.listen((HttpRequest request) async {
      try {
        if (request.uri.path == '/') {
          final code = request.uri.queryParameters['code'];
          if (code != null) {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.html
              ..write('Authentication successful! You can close this window now.');
            await request.response.close();

            timer?.cancel();
            subscription?.cancel();

            if (!completer.isCompleted) {
              completer.complete(code);
            }
          } else {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write('Error: Code parameter missing.');
            await request.response.close();
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

class GoogleOAuthService implements OAuthService {
  final http.Client _client;
  final OAuthRedirectServer _redirectServer;
  final String _configPath;

  final _authStateController = StreamController<bool>.broadcast();

  AppConfig? _config;
  bool _isMock = false;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiry;
  bool _initialized = false;
  bool _mockLoggedInState = false;

  GoogleOAuthService({
    http.Client? client,
    OAuthRedirectServer? redirectServer,
    this._configPath = '/home/toms/projects/Gem/config.json',
  })  : _client = client ?? http.Client(),
        _redirectServer = redirectServer ?? LocalRedirectServer() {
    _loadConfig();
  }

  void _loadConfig() {
    try {
      final file = File(_configPath);
      if (!file.existsSync()) {
        developer.log('config.json file not found at $_configPath. Using mock capabilities.', name: 'GoogleOAuthService');
        // ignore: avoid_print
        print('config.json file not found at $_configPath. Using mock capabilities.');
        _isMock = true;
        return;
      }
      final content = file.readAsStringSync();
      final Map<String, dynamic> json = jsonDecode(content);
      _config = AppConfig.fromJson(json);
      _isMock = false;
    } catch (e) {
      developer.log('Error loading config from $_configPath: $e. Using mock capabilities.', error: e, name: 'GoogleOAuthService');
      // ignore: avoid_print
      print('Error loading config from $_configPath: $e. Using mock capabilities.');
      _isMock = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_isMock) {
      _initialized = true;
      return;
    }
    try {
      final file = await _getTokenFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        if (data['expiry_ms'] != null) {
          _expiry = DateTime.fromMillisecondsSinceEpoch(data['expiry_ms'] as int);
        }
      }
    } catch (e) {
      developer.log('Failed to load tokens from disk: $e', name: 'GoogleOAuthService');
    }
    _initialized = true;
  }

  Future<File> _getTokenFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/oauth_tokens.json');
    } catch (e) {
      return File('${Directory.systemTemp.path}/oauth_tokens.json');
    }
  }

  Future<void> _saveTokens() async {
    if (_isMock) return;
    try {
      final file = await _getTokenFile();
      final data = {
        if (_accessToken != null) 'access_token': _accessToken,
        if (_refreshToken != null) 'refresh_token': _refreshToken,
        if (_expiry != null) 'expiry_ms': _expiry!.millisecondsSinceEpoch,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      developer.log('Failed to save tokens to disk: $e', name: 'GoogleOAuthService');
    }
  }

  Future<void> _deleteTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _expiry = null;
    if (_isMock) return;
    try {
      final file = await _getTokenFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      developer.log('Failed to delete tokens: $e', name: 'GoogleOAuthService');
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_isMock || _refreshToken == null) return false;
    try {
      final response = await _client.post(
        Uri.parse(_config!.tokenUri),
        body: {
          'client_id': _config!.clientId,
          'client_secret': _config!.clientSecret,
          'refresh_token': _refreshToken,
          'grant_type': 'refresh_token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = body['access_token'] as String?;
        if (body['refresh_token'] != null) {
          _refreshToken = body['refresh_token'] as String?;
        }
        final expiresIn = body['expires_in'] as int?;
        if (expiresIn != null) {
          _expiry = DateTime.now().add(Duration(seconds: expiresIn));
        }
        await _saveTokens();
        return true;
      } else {
        developer.log('Failed to refresh token: ${response.body}', name: 'GoogleOAuthService');
        return false;
      }
    } catch (e) {
      developer.log('Exception while refreshing token: $e', error: e, name: 'GoogleOAuthService');
      return false;
    }
  }

  @override
  Future<bool> login() async {
    await _ensureInitialized();
    if (_isMock) {
      _mockLoggedInState = true;
      _authStateController.add(true);
      return true;
    }

    if (_accessToken != null && !(await isTokenExpired())) {
      _authStateController.add(true);
      return true;
    }
    if (_refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        _authStateController.add(true);
        return true;
      }
    }

    int? port;
    try {
      port = await _redirectServer.start();
      final activePort = port;
      final uri = Uri.parse(_config!.authUri).replace(
        queryParameters: {
          'client_id': _config!.clientId,
          'redirect_uri': 'http://localhost:$activePort',
          'response_type': 'code',
          'scope': 'https://www.googleapis.com/auth/fitness.activity.read https://www.googleapis.com/auth/fitness.sleep.read https://www.googleapis.com/auth/fitness.body.read',
        },
      );
      final authUrl = uri.toString();
      // ignore: avoid_print
      print('Please open the following URL in your browser to authenticate:');
      // ignore: avoid_print
      print(authUrl);
      developer.log('Auth URL: $authUrl', name: 'GoogleOAuthService');

      try {
        if (Platform.isLinux) {
          Process.run('xdg-open', [authUrl]);
        } else if (Platform.isWindows) {
          Process.run('cmd', ['/c', 'start', '', authUrl]);
        }
      } catch (e) {
        developer.log('Failed to auto-launch browser: $e', name: 'GoogleOAuthService');
      }

      final code = await _redirectServer.waitForCode();
      await _redirectServer.stop();
      port = null;

      final response = await _client.post(
        Uri.parse(_config!.tokenUri),
        body: {
          'client_id': _config!.clientId,
          'client_secret': _config!.clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': 'http://localhost:$activePort',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = body['access_token'] as String?;
        _refreshToken = body['refresh_token'] as String?;
        final expiresIn = body['expires_in'] as int?;
        if (expiresIn != null) {
          _expiry = DateTime.now().add(Duration(seconds: expiresIn));
        }
        await _saveTokens();
        _authStateController.add(true);
        return true;
      } else {
        throw Exception('Failed to exchange authorization code for tokens: ${response.body}');
      }
    } catch (e) {
      if (port != null) {
        try {
          await _redirectServer.stop();
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _ensureInitialized();
    if (_isMock) {
      _mockLoggedInState = false;
      _authStateController.add(false);
      return;
    }
    await _deleteTokens();
    _authStateController.add(false);
  }

  @override
  Future<String?> getAccessToken() async {
    await _ensureInitialized();
    if (_isMock) {
      return 'mock_access_token_123';
    }
    if (_accessToken == null) return null;
    if (await isTokenExpired()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return null;
      }
    }
    return _accessToken;
  }

  @override
  Future<bool> isTokenExpired() async {
    await _ensureInitialized();
    if (_isMock) return false;
    if (_expiry == null) return true;
    return DateTime.now().isAfter(_expiry!);
  }

  @override
  Stream<bool> get authStateChanges {
    final controller = StreamController<bool>.broadcast();
    _ensureInitialized().then((_) {
      if (!controller.isClosed) {
        final isLoggedIn = _isMock ? _mockLoggedInState : (_accessToken != null);
        controller.add(isLoggedIn);
      }
    });
    final sub = _authStateController.stream.listen((val) {
      if (!controller.isClosed) {
        controller.add(val);
      }
    });
    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };
    return controller.stream;
  }
}
