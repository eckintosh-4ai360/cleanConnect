part of 'user_model.dart';

// JsonSerializableGenerator

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: json['id'] as String,
  fullName: json['fullName'] as String,
  email: json['email'] as String,
  phoneNumber: json['phoneNumber'] as String,
  address: json['address'] as String?,
  gpsLocation: json['gpsLocation'] as String?,
  profilePictureUrl: json['profilePictureUrl'] as String?,
  role: json['role'] as String,
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'address': instance.address,
      'gpsLocation': instance.gpsLocation,
      'profilePictureUrl': instance.profilePictureUrl,
      'role': instance.role,
    };
