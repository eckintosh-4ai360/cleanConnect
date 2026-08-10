import '../entities/rider_entities.dart';
import '../entities/pickup_request_entity.dart';

abstract class RiderRepository {
  Stream<RiderEntity?> watchRiderProfile();
  Future<RiderEntity> getRiderProfile();
  Future<RiderEntity> updateRiderStatus(String status);

  Stream<ActiveRouteEntity?> watchActiveRoute();
  Future<ActiveRouteEntity?> getActiveRoute();

  Stream<List<CollectionLogEntity>> watchCollectionHistory();
  Future<List<CollectionLogEntity>> getCollectionHistory();

  Stream<RiderPerformanceEntity> watchPerformanceStats();
  Future<RiderPerformanceEntity> getPerformanceStats();

  Stream<List<RiderNotificationEntity>> watchNotifications();
  Future<List<RiderNotificationEntity>> getNotifications();

  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<RouteStopEntity> markStopCollected({
    required String stopId,
    required double weightKg,
    String? photoPath,
    String? qrCodeData,
    String? notes,
  });
  Future<RouteStopEntity> markStopProblem({
    required String stopId,
    required String reason,
    String? notes,
  });
  Future<void> completeRoute(String routeId);

  /// Streams all pickup requests with status 'pending' (not yet accepted).
  Stream<List<PickupRequestEntity>> watchAvailablePickups();

  /// Streams a single pickup request by id (used by the incoming-request
  /// notification screen, which only receives a requestId from the push).
  Stream<PickupRequestEntity?> watchPickupById(String requestId);

  /// Saves/updates this rider's FCM push token so Cloud Functions can target
  /// them with new-pickup-request notifications.
  Future<void> updateFcmToken(String token);

  /// Accept a pickup request — assigns this rider and sets status to 'accepted'.
  Future<void> acceptPickup({
    required String requestId,
    required String customerId,
  });

  /// Reject / pass on a pickup request (status unchanged, rider passed).
  Future<void> rejectPickup({
    required String requestId,
    required String customerId,
  });

  /// Update live GPS position of rider in Firestore for admin live tracking.
  Future<void> updateRiderLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    String? currentJobId,
  });
}
