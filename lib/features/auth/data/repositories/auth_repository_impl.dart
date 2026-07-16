import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  fb.FirebaseAuth get _firebaseAuth => fb.FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  AuthRepositoryImpl();

  bool get _isFirebaseAvailable {
    try {
      final app = Firebase.app();
      if (app.options.apiKey.contains('dummy')) {
        return false;
      }
      fb.FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!_isFirebaseAvailable) {
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

      try {
        final box = Hive.box('auth_box');
        await box.put('userId', mockUser.id);
        await box.put('fullName', mockUser.fullName);
        await box.put('email', mockUser.email);
        await box.put('phoneNumber', mockUser.phoneNumber);
        await box.put('address', mockUser.address);
        await box.put('gpsLocation', mockUser.gpsLocation);
        await box.put('role', mockUser.role.name);
      } catch (_) {}

      return mockUser;
    }

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('User authentication failed.');
      }

      // Fetch user profile from Firestore
      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!doc.exists) {
        throw Exception('User profile not found in database.');
      }

      final data = doc.data()!;
      data['id'] = fbUser.uid; // Ensure ID matches UID
      final userModel = UserModel.fromJson(data);
      return userModel.toEntity();
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication error occurred.');
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
    if (!_isFirebaseAvailable) {
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

      try {
        final box = Hive.box('auth_box');
        await box.put('userId', mockUser.id);
        await box.put('fullName', mockUser.fullName);
        await box.put('email', mockUser.email);
        await box.put('phoneNumber', mockUser.phoneNumber);
        await box.put('address', mockUser.address);
        await box.put('gpsLocation', mockUser.gpsLocation);
        await box.put('role', mockUser.role.name);
      } catch (_) {}

      return mockUser;
    }

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('Registration failed.');
      }

      final userModel = UserModel(
        id: fbUser.uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        role: role,
        address: address,
        gpsLocation: gpsLocation,
        profilePictureUrl: profilePicturePath,
        status: 'active',
        createdAt: DateTime.now(),
      );

      // Save user details to Firestore
      try {
        await _firestore.collection('users').doc(fbUser.uid).set(userModel.toJson());
      } catch (e) {
        // Log error but proceed to let the user log in locally even if Firestore write fails
        print('Firestore save failed during registration: $e');
      }

      return userModel.toEntity();
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Registration error occurred.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error sending password reset email.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> verifyOtp(String phoneNumber, String otpCode) async {
    // Left unimplemented as we use Firebase Email/Password Auth for production
    throw UnimplementedError('SMS OTP is not supported.');
  }

  @override
  Future<void> resendOtp(String phoneNumber) async {
    // Left unimplemented as we use Firebase Email/Password Auth for production
    throw UnimplementedError('SMS OTP is not supported.');
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    if (!_isFirebaseAvailable) {
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
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null) return null;

      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['id'] = fbUser.uid;
      final userModel = UserModel.fromJson(data);
      return userModel.toEntity();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    if (!_isFirebaseAvailable) {
      try {
        final box = Hive.box('auth_box');
        await box.clear();
      } catch (_) {}
      return;
    }

    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Error signing out.');
    }
  }
}
