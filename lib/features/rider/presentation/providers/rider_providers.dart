import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/rider_entities.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../domain/repositories/rider_repository.dart';
import '../../data/repositories/rider_repository_impl.dart';

part 'rider_providers.g.dart';

@riverpod
RiderRepository riderRepository(Ref ref) {
  return RiderRepositoryImpl();
}

@riverpod
class RiderProfile extends _$RiderProfile {
  @override
  Stream<RiderEntity?> build() {
    return ref.watch(riderRepositoryProvider).watchRiderProfile();
  }

  Future<void> updateStatus(String status) async {
    await ref.read(riderRepositoryProvider).updateRiderStatus(status);
  }

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    String? currentJobId,
  }) async {
    await ref.read(riderRepositoryProvider).updateRiderLocation(
          latitude: latitude,
          longitude: longitude,
          heading: heading,
          speed: speed,
          currentJobId: currentJobId,
        );
  }
}

@riverpod
class RiderActiveRoute extends _$RiderActiveRoute {
  @override
  Stream<ActiveRouteEntity?> build() {
    return ref.watch(riderRepositoryProvider).watchActiveRoute();
  }

  Future<void> markStopCollected({
    required String stopId,
    required double weightKg,
    String? photoPath,
    String? qrCodeData,
    String? notes,
  }) async {
    await ref.read(riderRepositoryProvider).markStopCollected(
          stopId: stopId,
          weightKg: weightKg,
          photoPath: photoPath,
          qrCodeData: qrCodeData,
          notes: notes,
        );
  }

  Future<void> markStopProblem({
    required String stopId,
    required String reason,
    String? notes,
  }) async {
    await ref.read(riderRepositoryProvider).markStopProblem(
          stopId: stopId,
          reason: reason,
          notes: notes,
        );
  }

  Future<void> completeRoute() async {
    final current = state.value;
    if (current != null) {
      await ref.read(riderRepositoryProvider).completeRoute(current.id);
    }
  }
}

@riverpod
class RiderCollectionHistory extends _$RiderCollectionHistory {
  @override
  Stream<List<CollectionLogEntity>> build() {
    return ref.watch(riderRepositoryProvider).watchCollectionHistory();
  }
}

@riverpod
class RiderPerformance extends _$RiderPerformance {
  @override
  Stream<RiderPerformanceEntity> build() {
    return ref.watch(riderRepositoryProvider).watchPerformanceStats();
  }
}

@riverpod
class RiderNotifications extends _$RiderNotifications {
  @override
  Stream<List<RiderNotificationEntity>> build() {
    return ref.watch(riderRepositoryProvider).watchNotifications();
  }

  Future<void> markRead(String id) async {
    await ref.read(riderRepositoryProvider).markNotificationRead(id);
  }

  Future<void> markAllRead() async {
    await ref.read(riderRepositoryProvider).markAllNotificationsRead();
  }
}

@riverpod
class AvailablePickups extends _$AvailablePickups {
  @override
  Stream<List<PickupRequestEntity>> build() {
    return ref.watch(riderRepositoryProvider).watchAvailablePickups();
  }

  Future<void> accept(String requestId, String customerId) async {
    await ref.read(riderRepositoryProvider).acceptPickup(
          requestId: requestId,
          customerId: customerId,
        );
  }

  Future<void> reject(String requestId, String customerId) async {
    await ref.read(riderRepositoryProvider).rejectPickup(
          requestId: requestId,
          customerId: customerId,
        );
  }
}
