import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

class TimestampConverter implements JsonConverter<DateTime, dynamic> {
  const TimestampConverter();

  @override
  DateTime fromJson(dynamic json) {
    if (json is Timestamp) {
      return json.toDate();
    } else if (json is String) {
      return DateTime.parse(json);
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    return DateTime.now();
  }

  @override
  dynamic toJson(DateTime date) => Timestamp.fromDate(date);
}

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
    required UserRole role,
    required String status,
    @TimestampConverter() required DateTime createdAt,
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
        status: status,
        createdAt: createdAt,
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
        status: entity.status,
        createdAt: entity.createdAt,
      );
}
