/// Live state of one pickup as seen by the customer who booked it.
///
/// Reads from the same `pickup_requests` row the rider writes to via
/// `update_rider_location`, so what the customer sees is the rider's actual
/// device position rather than a separate derived feed.
class PickupTrackingEntity {
  final String requestId;
  final String status;
  final String location;

  /// Destination coordinates. Null on legacy rows whose `location` was a plain
  /// address and which have not been geocoded yet.
  final double? destinationLat;
  final double? destinationLng;

  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? riderPhotoUrl;
  final String? vehicleType;
  final double? riderRating;

  final double? riderLat;
  final double? riderLng;
  final double? riderHeading;

  /// Rider ground speed in km/h as last reported.
  final double? riderSpeed;

  final DateTime? riderLocationUpdatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const PickupTrackingEntity({
    required this.requestId,
    required this.status,
    required this.location,
    this.destinationLat,
    this.destinationLng,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.riderPhotoUrl,
    this.vehicleType,
    this.riderRating,
    this.riderLat,
    this.riderLng,
    this.riderHeading,
    this.riderSpeed,
    this.riderLocationUpdatedAt,
    this.acceptedAt,
    this.completedAt,
  });

  bool get hasRiderPosition => riderLat != null && riderLng != null;
  bool get hasDestination => destinationLat != null && destinationLng != null;
  bool get isAssigned => riderId != null;
  bool get isComplete => status == 'completed' || status == 'cancelled';

  /// True when the rider has been assigned but their position has gone stale.
  ///
  /// A rider whose app is closed stops writing fixes, and a marker frozen on
  /// the map with no explanation reads as the app being broken. 90 seconds is
  /// well past the 5-second upload cadence, so this only trips on a real gap.
  bool get isPositionStale {
    if (!hasRiderPosition) return false;
    final at = riderLocationUpdatedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > const Duration(seconds: 90);
  }

  /// Customer-facing phase, driving which panel the tracking screen shows.
  PickupPhase get phase {
    if (status == 'cancelled') return PickupPhase.cancelled;
    if (status == 'completed') return PickupPhase.completed;
    if (!isAssigned) return PickupPhase.awaitingRider;
    return PickupPhase.enRoute;
  }
}

enum PickupPhase { awaitingRider, enRoute, completed, cancelled }
