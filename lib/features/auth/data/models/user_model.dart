import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String fullName,
    required String email,
    required String phoneNumber,
    String? address,
    String? gpsLocation,
    String? profilePictureUrl,
    required String role,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  const UserModel._();

  UserEntity toEntity() => UserEntity(
        id: id,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        gpsLocation: gpsLocation,
        profilePictureUrl: profilePictureUrl,
        role: role,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        id: entity.id,
        fullName: entity.fullName,
        email: entity.email,
        phoneNumber: entity.phoneNumber,
        address: entity.address,
        gpsLocation: entity.gpsLocation,
        profilePictureUrl: entity.profilePictureUrl,
        role: entity.role,
      );
}
