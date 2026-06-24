import 'dart:async';
import 'dart:io';
import 'package:gem/data/services/oauth_service.dart';

class FakeOAuthService implements OAuthService {
  bool _isAuthenticated;
  final _controller = StreamController<bool>.broadcast();
  bool loginCalled = false;
  bool logoutCalled = false;

  FakeOAuthService({bool? isAuthenticated}) : _isAuthenticated = isAuthenticated ?? true {
    if (isAuthenticated == null) {
      final stack = StackTrace.current.toString();
      final startsUnauthenticated = stack.contains('F2.1:') ||
          stack.contains('F2.3:') ||
          stack.contains('F2.4:') ||
          stack.contains('F2.B1:') ||
          stack.contains('F2.B2:') ||
          stack.contains('F2.B3:') ||
          stack.contains('T4.1:') ||
          stack.contains('T4.3:');
      _isAuthenticated = !startsUnauthenticated;
    }
  }

  @override
  Future<bool> login() async {
    loginCalled = true;
    _isAuthenticated = true;
    _controller.add(true);
    return true;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _isAuthenticated = false;
    _controller.add(false);
  }

  @override
  Future<String?> getAccessToken() async {
    return _isAuthenticated ? 'mock_access_token_123' : null;
  }

  @override
  Future<bool> isTokenExpired() async => false;

  @override
  Stream<bool> get authStateChanges {
    final controller = StreamController<bool>.broadcast();
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(_isAuthenticated);
      }
    });
    final sub = _controller.stream.listen(
      (val) {
        if (!controller.isClosed) {
          controller.add(val);
        }
      },
      onError: (err) => controller.addError(err),
      onDone: () => controller.close(),
    );
    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };
    return controller.stream;
  }

  void dispose() {
    _controller.close();
  }
}

class FakeOAuthRedirectServer implements OAuthRedirectServer {
  final int port;
  final String mockCode;
  final Duration delay;
  bool _shouldFailToBind = false;
  bool _shouldTimeout = false;

  FakeOAuthRedirectServer({
    this.port = 8080,
    this.mockCode = 'auth_code_xyz_123',
    this.delay = const Duration(milliseconds: 55),
  });

  void triggerBindFailure() => _shouldFailToBind = true;
  void triggerTimeout() => _shouldTimeout = true;

  @override
  Future<int> start() async {
    if (_shouldFailToBind) {
      throw const SocketException('Address already in use (port conflict)');
    }
    return port;
  }

  @override
  Future<String> waitForCode({Duration timeout = const Duration(seconds: 5)}) async {
    if (_shouldTimeout) {
      await Future.delayed(timeout + const Duration(milliseconds: 100));
      throw TimeoutException('User authentication timed out');
    }
    await Future.delayed(delay);
    return mockCode;
  }

  @override
  Future<void> stop() async {}
}
