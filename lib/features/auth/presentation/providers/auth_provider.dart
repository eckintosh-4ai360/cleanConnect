import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/services/notification_service.dart';

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
  StreamSubscription<sb.AuthState>? _subscription;

  @override
  AuthState build() {
    _subscription?.cancel();

    final useMock = !AuthRepositoryImpl.isSupabaseAvailable;

    if (useMock) {
      try {
        final box = Hive.box('auth_box');
        final savedUserId = box.get('userId');
        if (savedUserId != null) {
          final fullName = box.get('fullName') ?? 'Demo User';
          final email = box.get('email') ?? 'demo@ecowaste.com';
          final phoneNumber = box.get('phoneNumber') ?? '0000000000';
          final address = box.get('address');
          final gpsLocation = box.get('gpsLocation');
          final roleStr = box.get('role') ?? 'customer';
          final role = UserRole.values.firstWhere(
            (r) => r.name == roleStr,
            orElse: () => UserRole.customer,
          );

          final user = UserEntity(
            id: savedUserId,
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            address: address,
            gpsLocation: gpsLocation,
            role: role,
            status: 'active',
            createdAt: DateTime.now(),
          );
          return AuthAuthenticated(user);
        }
      } catch (e) {
        debugPrint('Failed to load mock auth state: $e');
      }
      return const AuthUnauthenticated();
    }

    try {
      // Listen to Supabase auth changes in real-time
      _subscription = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        if (data.session == null) {
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
      // Return AuthError to prevent app crash if Supabase is not initialized
      return AuthError('Supabase is not initialized: ${e.toString()}');
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
    Uint8List? housePhotoBytes,
    String? housePhotoFileName,
    UserRole role = UserRole.customer,
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
            housePhotoBytes: housePhotoBytes,
            housePhotoFileName: housePhotoFileName,
            role: role,
          );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    // Before the session goes away, while RLS still allows the write: hand
    // back this device's push registration. The new-pickup fan-out targets
    // every token stored on the riders table, so one left behind here keeps
    // alerting (and vibrating) whoever signs in on this device next.
    await NotificationService.instance.handleLogout();
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
