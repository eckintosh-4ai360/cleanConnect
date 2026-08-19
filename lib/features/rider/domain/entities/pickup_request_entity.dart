import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickupRequestEntity {
  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String location;

  /// Where the pickup actually is, for the navigation map. Null on legacy rows
  /// whose [location] was captured as a plain address rather than coordinates.
  final double? destinationLat;
  final double? destinationLng;

  final String timeSlot;
  final List<String> binTypes;
  final String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final String? assignedRiderId;
  final String? assignedRiderName;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  /// Photo of the customer's house/building, captured at registration and
  /// snapshotted onto this request. Lets a rider visually confirm the exact
  /// address, since the map pin alone can be off by tens of metres. Null when
  /// the customer never uploaded one.
  final String? housePhotoUrl;

  const PickupRequestEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.location,
    this.destinationLat,
    this.destinationLng,
    required this.timeSlot,
    required this.binTypes,
    required this.status,
    this.assignedRiderId,
    this.assignedRiderName,
    required this.createdAt,
    this.acceptedAt,
    this.housePhotoUrl,
  });

  /// Plottable destination, or null when the request has no coordinates yet.
  LatLng? get destination {
    final lat = destinationLat;
    final lng = destinationLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}
