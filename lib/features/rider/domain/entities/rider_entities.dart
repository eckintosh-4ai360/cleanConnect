class RiderEntity {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? profilePhotoUrl;
  final String vehicleType; // 'motorbike', 'compact_van', 'cargo_bike', 'heavy_duty'
  final String licenseNumber;
  final String nationalIdNumber;
  final String status; // 'active', 'offline', 'on_route', 'pending_approval'
  final double rating; // 1.0 - 5.0
  final int totalCollections;
  final double totalWeightKg;
  final double earningsThisMonth;
  final double efficiencyScore; // 0 - 100

  const RiderEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profilePhotoUrl,
    required this.vehicleType,
    required this.licenseNumber,
    required this.nationalIdNumber,
    required this.status,
    required this.rating,
    required this.totalCollections,
    required this.totalWeightKg,
    required this.earningsThisMonth,
    required this.efficiencyScore,
  });

  RiderEntity copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? vehicleType,
    String? licenseNumber,
    String? nationalIdNumber,
    String? status,
    double? rating,
    int? totalCollections,
    double? totalWeightKg,
    double? earningsThisMonth,
    double? efficiencyScore,
  }) {
    return RiderEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      totalCollections: totalCollections ?? this.totalCollections,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      earningsThisMonth: earningsThisMonth ?? this.earningsThisMonth,
      efficiencyScore: efficiencyScore ?? this.efficiencyScore,
    );
  }
}

class RouteStopEntity {
  final String id;
  final String customerName;
  final String address;
  final String binType; // 'general', 'recycling', 'organic'
  final String status; // 'pending', 'collected', 'skipped', 'problem'
  final double? estimatedWeightKg;
  final double? actualWeightKg;
  final String? notes;
  final double latitude;
  final double longitude;
  final int stopOrder;

  const RouteStopEntity({
    required this.id,
    required this.customerName,
    required this.address,
    required this.binType,
    required this.status,
    this.estimatedWeightKg,
    this.actualWeightKg,
    this.notes,
    required this.latitude,
    required this.longitude,
    required this.stopOrder,
  });

  RouteStopEntity copyWith({
    String? id,
    String? customerName,
    String? address,
    String? binType,
    String? status,
    double? estimatedWeightKg,
    double? actualWeightKg,
    String? notes,
    double? latitude,
    double? longitude,
    int? stopOrder,
  }) {
    return RouteStopEntity(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      binType: binType ?? this.binType,
      status: status ?? this.status,
      estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      stopOrder: stopOrder ?? this.stopOrder,
    );
  }
}

class ActiveRouteEntity {
  final String id;
  final String routeName;
  final String zone;
  final List<RouteStopEntity> stops;
  final DateTime startTime;
  final DateTime? estimatedEndTime;
  final String status; // 'active', 'completed', 'paused'
  final double totalDistanceKm;
  final double completedDistanceKm;
  final int totalStops;
  final int completedStops;

  const ActiveRouteEntity({
    required this.id,
    required this.routeName,
    required this.zone,
    required this.stops,
    required this.startTime,
    this.estimatedEndTime,
    required this.status,
    required this.totalDistanceKm,
    required this.completedDistanceKm,
    required this.totalStops,
    required this.completedStops,
  });
}

class CollectionLogEntity {
  final String id;
  final String customerName;
  final String address;
  final String binType;
  final double weightKg;
  final DateTime collectedAt;
  final String status; // 'verified', 'pending_review', 'problem'
  final String? photoUrl;
  final String? qrCodeData;
  final String? notes;

  const CollectionLogEntity({
    required this.id,
    required this.customerName,
    required this.address,
    required this.binType,
    required this.weightKg,
    required this.collectedAt,
    required this.status,
    this.photoUrl,
    this.qrCodeData,
    this.notes,
  });
}

class RiderPerformanceEntity {
  final double efficiencyScore;
  final double averageRating;
  final int collectionsThisWeek;
  final double weightThisWeek;
  final double earningsThisWeek;
  final double earningsThisMonth;
  final int totalCollectionsAllTime;
  final double onTimeDeliveryRate;
  final List<double> weeklyScores; // last 7 days

  const RiderPerformanceEntity({
    required this.efficiencyScore,
    required this.averageRating,
    required this.collectionsThisWeek,
    required this.weightThisWeek,
    required this.earningsThisWeek,
    required this.earningsThisMonth,
    required this.totalCollectionsAllTime,
    required this.onTimeDeliveryRate,
    required this.weeklyScores,
  });
}

class RiderNotificationEntity {
  final String id;
  final String title;
  final String message;
  final String type; // 'new_route', 'alert', 'payment', 'system'
  final DateTime receivedAt;
  final bool isRead;

  const RiderNotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.receivedAt,
    required this.isRead,
  });
}
