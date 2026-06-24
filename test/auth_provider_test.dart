import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mocks/mock_auth_repository.dart';

abstract class AuthRepository {
  Future<String> login();
}

// State model
class AuthState {
  final bool isAuthenticating;
  final String? token;
  final String? error;
  AuthState({required this.isAuthenticating, this.token, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repository;
  AuthNotifier(this.repository) : super(AuthState(isAuthenticating: false));

  Future<void> signIn() async {
    state = AuthState(isAuthenticating: true);
    try {
      final token = await repository.login();
      state = AuthState(isAuthenticating: false, token: token);
    } catch (e) {
      state = AuthState(isAuthenticating: false, error: e.toString());
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => throw UnimplementedError());
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

void main() {
  test('Riverpod Auth State transitions from Unauthenticated to Authenticating to Success', () async {
    final fakeRepo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    // Initial state check
    expect(container.read(authStateProvider).isAuthenticating, false);
    expect(container.read(authStateProvider).token, isNull);

    // Start OAuth flow
    final loginFuture = container.read(authStateProvider.notifier).signIn();
    
    // Check loading transition
    expect(container.read(authStateProvider).isAuthenticating, true);

    await loginFuture;

    // Check completed state
    expect(container.read(authStateProvider).isAuthenticating, false);
    expect(container.read(authStateProvider).token, 'mock_access_token_123');
  });
}
