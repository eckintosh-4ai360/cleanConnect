import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String address,
    required String gpsLocation,
    String? profilePicturePath,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> verifyOtp(String phoneNumber, String otpCode);

  Future<void> resendOtp(String phoneNumber);

  Future<UserEntity?> getCurrentUser();

  Future<void> signOut();
}
