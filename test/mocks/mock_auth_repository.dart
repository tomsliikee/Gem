import '../auth_provider_test.dart';

class FakeAuthRepository implements AuthRepository {
  bool shouldFail = false;
  @override
  Future<String> login() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldFail) throw Exception('OAuth timeout');
    return 'mock_access_token_123';
  }
}
