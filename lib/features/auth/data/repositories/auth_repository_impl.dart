import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final _secureStorage = const FlutterSecureStorage();
  final String _userKey = 'cached_user';
  final String _tokenKey = 'auth_token';

  AuthRepositoryImpl();

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Simulate API network delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (email == 'error@ecowaste.com') {
      throw Exception('Invalid credentials. Please try again.');
    }

    // Determine role from email (e.g. contains 'rider' -> rider, 'admin' -> admin, else customer)
    String role = 'customer';
    if (email.contains('rider')) {
      role = 'rider';
    } else if (email.contains('admin')) {
      role = 'admin';
    }

    final user = UserModel(
      id: 'usr_mock_123',
      fullName: email.split('@').first.toUpperCase(),
      email: email,
      phoneNumber: '+1 (555) 019-2834',
      role: role,
      address: '123 Green St, Eco City',
      gpsLocation: '5.6037° N, 0.1870° W',
      profilePictureUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
    );

    // Save token and user data locally
    await _secureStorage.write(key: _tokenKey, value: 'mock_jwt_token_xyz');
    final authBox = Hive.box('auth_box');
    await authBox.put(_userKey, jsonEncode(user.toJson()));

    return user.toEntity();
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
  }) async {
    await Future.delayed(const Duration(milliseconds: 2000));

    final user = UserModel(
      id: 'usr_mock_new',
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      role: 'customer',
      address: address,
      gpsLocation: gpsLocation,
      profilePictureUrl: profilePicturePath,
    );

    // Save token and user data locally
    await _secureStorage.write(key: _tokenKey, value: 'mock_jwt_token_new');
    final authBox = Hive.box('auth_box');
    await authBox.put(_userKey, jsonEncode(user.toJson()));

    return user.toEntity();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    // Simulated success
  }

  @override
  Future<void> verifyOtp(String phoneNumber, String otpCode) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (otpCode != '1234') {
      throw Exception('Invalid verification code. Please enter 1234.');
    }
  }

  @override
  Future<void> resendOtp(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token == null) return null;

    final authBox = Hive.box('auth_box');
    final cachedUserJson = authBox.get(_userKey);
    if (cachedUserJson != null) {
      final userMap = jsonDecode(cachedUserJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap).toEntity();
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    await _secureStorage.delete(key: _tokenKey);
    final authBox = Hive.box('auth_box');
    await authBox.delete(_userKey);
  }
}
