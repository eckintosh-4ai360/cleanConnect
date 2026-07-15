import '../entities/rider_entities.dart';

abstract class RiderRepository {
  Future<RiderEntity> getRiderProfile();
  Future<RiderEntity> updateRiderStatus(String status);
  Future<ActiveRouteEntity?> getActiveRoute();
  Future<List<CollectionLogEntity>> getCollectionHistory();
  Future<RiderPerformanceEntity> getPerformanceStats();
  Future<List<RiderNotificationEntity>> getNotifications();
  Future<void> markNotificationRead(String notificationId);
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
}
