import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

part 'auth_provider.g.dart';

sealed class AuthState {
  const AuthState();

  bool get isLoading => this is AuthLoading;
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl();
}

@riverpod
class AuthStateController extends _$AuthStateController {
  StreamSubscription<fb.User?>? _subscription;

  @override
  AuthState build() {
    _subscription?.cancel();
    
    try {
      // Listen to Firebase auth changes in real-time
      _subscription = fb.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
        if (fbUser == null) {
          state = const AuthUnauthenticated();
        } else {
          try {
            final user = await ref.read(authRepositoryProvider).getCurrentUser();
            if (user != null) {
              state = AuthAuthenticated(user);
            } else {
              state = const AuthUnauthenticated();
            }
          } catch (e) {
            state = AuthError(e.toString());
          }
        }
      });
      
      ref.onDispose(() {
        _subscription?.cancel();
      });
    } catch (e) {
      // Return AuthError to prevent app crash if Firebase core is not initialized
      return AuthError('Firebase is not initialized: ${e.toString()}');
    }

    return const AuthLoading();
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final user = await ref.read(authRepositoryProvider).signInWithEmailAndPassword(
            email: email,
            password: password,
          );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String address,
    required String gpsLocation,
    String? profilePicturePath,
  }) async {
    state = const AuthLoading();
    try {
      final user = await ref.read(authRepositoryProvider).register(
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            password: password,
            address: address,
            gpsLocation: gpsLocation,
            profilePicturePath: profilePicturePath,
          );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }
}

@riverpod
UserEntity? currentUser(Ref ref) {
  final authState = ref.watch(authStateControllerProvider);
  if (authState is AuthAuthenticated) {
    return authState.user;
  }
  return null;
}

@riverpod
UserRole? currentUserRole(Ref ref) {
  return ref.watch(currentUserProvider)?.role;
}
