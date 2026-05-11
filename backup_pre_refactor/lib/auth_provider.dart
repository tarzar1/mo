import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'driver_api_service.dart';
import 'providers.dart';

// ─── AUTH STATE ───────────────────────────────────────────────────────────────

class AuthState {
  final String? token;
  final bool loading;
  final String? errorMessage;
  final UserProfile? userProfile;

  const AuthState({
    this.token,
    this.loading = true,
    this.errorMessage,
    this.userProfile,
  });

  bool get isLoggedIn => token != null;

  AuthState copyWith({
    String? token,
    bool? loading,
    String? errorMessage,
    UserProfile? userProfile,
  }) {
    return AuthState(
      token: token ?? this.token,
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}

// ─── AUTH NOTIFIER ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final DriverApiService api;

  AuthNotifier(this.api) : super(const AuthState(loading: false));

  /// Intenta restaurar sesión guardada (llamar después del primer frame)
  Future<void> tryAutoLogin() async {
    try {
      final token = await api.loadToken();
      if (token != null) {
        state = AuthState(token: token, loading: false);
      }
    } catch (_) {
      // Si falla el storage, mostramos login nomás
    }
  }

  /// Login with JWT — updates state so AuthGate rebuilds to MainShell
  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final token = await api.loginJwt(email: email, password: password);
      debugPrint('Login successful, token received: ${token.substring(0, 20)}...');
      state = AuthState(token: token, loading: false);
      debugPrint('Auth state updated, isLoggedIn: ${state.isLoggedIn}');
    } catch (e) {
      debugPrint('Login error: $e');
      final msg = e is ApiException ? e.message : 'Error de conexión';
      state = AuthState(token: null, loading: false, errorMessage: msg);
      rethrow;
    }
  }

  /// After login, load all data from the server
  Future<void> loadAllData(WidgetRef ref) async {
    try {
      await ref.read(userProfileProvider.notifier).loadProfile();
      final user = ref.read(userProfileProvider);
      if (user.id.isNotEmpty) {
        await Future.wait([
          ref.read(tripsProvider.notifier).loadTrips(),
          ref.read(notificationsProvider.notifier).loadNotifications(user.id),
          ref.read(conversationsProvider.notifier).loadConversations(user.id),
          ref.read(paymentMethodsProvider.notifier).loadPaymentMethods(user.id),
          ref.read(rideRequestsProvider.notifier).loadByRole(user.role),
        ]);
      }
      } catch (e) {
        debugPrint('loadAllData error: $e');
      }
  }

  /// Logout — clears token from storage and state
  Future<void> logout() async {
    await api.logout();
    state = const AuthState(token: null, loading: false);
  }

  /// Change password via JWT endpoint
  Future<void> changePassword({
    required String email,
    required String newPassword,
  }) async {
    await api.resetPasswordJwt(
      email: email,
      id: '',
      newPassword: newPassword,
    );
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.read(driverApiProvider);
  return AuthNotifier(api);
});
