import 'dart:async';

abstract class OAuthService {
  Future<bool> login();
  Future<void> logout();
  Future<String?> getAccessToken();
  Future<bool> isTokenExpired();
  Stream<bool> get authStateChanges;
}

abstract class OAuthRedirectServer {
  Future<int> start();
  Future<String> waitForCode({Duration timeout});
  Future<void> stop();
}
