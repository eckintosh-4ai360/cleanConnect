import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  fb.FirebaseAuth get _firebaseAuth => fb.FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  AuthRepositoryImpl();

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
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
  }) async {
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
        role: UserRole.customer,
        address: address,
        gpsLocation: gpsLocation,
        profilePictureUrl: profilePicturePath,
        status: 'active',
        createdAt: DateTime.now(),
      );

      // Save user details to Firestore
      await _firestore.collection('users').doc(fbUser.uid).set(userModel.toJson());

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
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Error signing out.');
    }
  }
}
