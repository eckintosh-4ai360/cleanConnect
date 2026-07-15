class UserEntity {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? address;
  final String? gpsLocation;
  final String? profilePictureUrl;
  final String role; // 'customer' or 'rider' or 'admin'

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.address,
    this.gpsLocation,
    this.profilePictureUrl,
    required this.role,
  });
}
