import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:hive/hive.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  AuthRepositoryImpl();

  /// Whether a real Supabase backend is initialized. Mirrors the app's
  /// pre-existing Firebase demo-mode precedent: if `Supabase.initialize()`
  /// was never called (e.g. a stripped-down test harness), fall back to a
  /// local Hive-backed mock auth instead of crashing.
  static bool get isSupabaseAvailable {
    try {
      sb.Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  UserRole _roleFromString(String? value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.customer,
      );

  UserEntity _entityFromProfileRow(Map<String, dynamic> row) => UserEntity(
        id: row['id'] as String,
        fullName: row['full_name'] as String? ?? 'User',
        email: row['email'] as String? ?? '',
        phoneNumber: row['phone_number'] as String? ?? '',
        address: row['address'] as String?,
        gpsLocation: row['gps_location'] as String?,
        profilePictureUrl: row['profile_picture_url'] as String?,
        role: _roleFromString(row['role'] as String?),
        status: row['status'] as String? ?? 'active',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

  Future<void> _saveMockSession(UserEntity user) async {
    try {
      final box = Hive.box('auth_box');
      await box.put('userId', user.id);
      await box.put('fullName', user.fullName);
      await box.put('email', user.email);
      await box.put('phoneNumber', user.phoneNumber);
      await box.put('address', user.address);
      await box.put('gpsLocation', user.gpsLocation);
      await box.put('role', user.role.name);
    } catch (_) {}
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!isSupabaseAvailable) {
      if (email.trim().isEmpty) {
        throw Exception('Please enter email address.');
      }
      if (password.isEmpty) {
        throw Exception('Please enter password.');
      }

      final emailLower = email.toLowerCase();
      UserRole role = UserRole.customer;
      String fullName = 'Demo Customer';
      if (emailLower.contains('rider')) {
        role = UserRole.rider;
        fullName = 'Demo Rider';
      } else if (emailLower.contains('admin')) {
        role = UserRole.admin;
        fullName = 'Demo Admin';
      }

      final mockUser = UserEntity(
        id: 'mock-uid-${role.name}',
        fullName: fullName,
        email: email,
        phoneNumber: '+15550000000',
        address: '123 Mock Street',
        gpsLocation: '5.6037° N, 0.1870° W',
        role: role,
        status: 'active',
        createdAt: DateTime.now(),
      );

      await _saveMockSession(mockUser);
      return mockUser;
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('User authentication failed.');
      }

      final row = await _client.from('profiles').select().eq('id', authUser.id).single();
      return _entityFromProfileRow(row);
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String address,
    required String gpsLocation,
    String? profilePicturePath,
    UserRole role = UserRole.customer,
  }) async {
    if (!isSupabaseAvailable) {
      final mockUser = UserEntity(
        id: 'mock-uid-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        gpsLocation: gpsLocation,
        profilePictureUrl: profilePicturePath,
        role: role,
        status: 'active',
        createdAt: DateTime.now(),
      );

      await _saveMockSession(mockUser);
      return mockUser;
    }

    try {
      // The handle_new_user() Postgres trigger fans this metadata out into
      // profiles + customers/riders (and an admin_notifications row) as soon
      // as the auth.users row is inserted — see supabase/migrations.
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'address': address,
          'gps_location': gpsLocation,
          'role': role.name,
        },
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Registration failed.');
      }

      if (profilePicturePath != null) {
        try {
          await _client
              .from('profiles')
              .update({'profile_picture_url': profilePicturePath}).eq('id', authUser.id);
        } catch (_) {}
      }

      return UserEntity(
        id: authUser.id,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        gpsLocation: gpsLocation,
        profilePictureUrl: profilePicturePath,
        role: role,
        status: 'active',
        createdAt: DateTime.now(),
      );
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> verifyOtp(String phoneNumber, String otpCode) async {
    // Left unimplemented as we use email/password auth for production
    throw UnimplementedError('SMS OTP is not supported.');
  }

  @override
  Future<void> resendOtp(String phoneNumber) async {
    // Left unimplemented as we use email/password auth for production
    throw UnimplementedError('SMS OTP is not supported.');
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    if (!isSupabaseAvailable) {
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
          final role = _roleFromString(roleStr);

          return UserEntity(
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
        }
      } catch (_) {}
      return null;
    }

    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;

      final row = await _client.from('profiles').select().eq('id', authUser.id).single();
      return _entityFromProfileRow(row);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    if (!isSupabaseAvailable) {
      try {
        final box = Hive.box('auth_box');
        await box.clear();
      } catch (_) {}
      return;
    }

    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Error signing out.');
    }
  }
}
