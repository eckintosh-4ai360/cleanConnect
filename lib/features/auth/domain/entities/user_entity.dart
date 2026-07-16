enum UserRole {
  customer,
  rider,
  admin
}

class UserEntity {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? address;
  final String? gpsLocation;
  final String? profilePictureUrl;
  final UserRole role;
  final String status;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.address,
    this.gpsLocation,
    this.profilePictureUrl,
    required this.role,
    required this.status,
    required this.createdAt,
  });
}
