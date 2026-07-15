import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/rider_entities.dart';
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
  FutureOr<RiderEntity> build() async {
    return ref.watch(riderRepositoryProvider).getRiderProfile();
  }

  Future<void> updateStatus(String status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(riderRepositoryProvider).updateRiderStatus(status);
    });
  }
}

@riverpod
class RiderActiveRoute extends _$RiderActiveRoute {
  @override
  FutureOr<ActiveRouteEntity?> build() async {
    return ref.watch(riderRepositoryProvider).getActiveRoute();
  }

  Future<void> markStopCollected({
    required String stopId,
    required double weightKg,
    String? photoPath,
    String? qrCodeData,
    String? notes,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(riderRepositoryProvider).markStopCollected(
            stopId: stopId,
            weightKg: weightKg,
            photoPath: photoPath,
            qrCodeData: qrCodeData,
            notes: notes,
          );
      // Update local state
      final updatedStops = current.stops.map((s) {
        if (s.id == stopId) {
          return s.copyWith(status: 'collected', actualWeightKg: weightKg);
        }
        return s;
      }).toList();
      return ActiveRouteEntity(
        id: current.id,
        routeName: current.routeName,
        zone: current.zone,
        stops: updatedStops,
        startTime: current.startTime,
        estimatedEndTime: current.estimatedEndTime,
        status: current.status,
        totalDistanceKm: current.totalDistanceKm,
        completedDistanceKm: current.completedDistanceKm,
        totalStops: current.totalStops,
        completedStops: current.completedStops + 1,
      );
    });
  }

  Future<void> markStopProblem({
    required String stopId,
    required String reason,
    String? notes,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(riderRepositoryProvider).markStopProblem(
            stopId: stopId,
            reason: reason,
            notes: notes,
          );
      final updatedStops = current.stops.map((s) {
        if (s.id == stopId) {
          return s.copyWith(status: 'problem', notes: notes ?? reason);
        }
        return s;
      }).toList();
      return ActiveRouteEntity(
        id: current.id,
        routeName: current.routeName,
        zone: current.zone,
        stops: updatedStops,
        startTime: current.startTime,
        estimatedEndTime: current.estimatedEndTime,
        status: current.status,
        totalDistanceKm: current.totalDistanceKm,
        completedDistanceKm: current.completedDistanceKm,
        totalStops: current.totalStops,
        completedStops: current.completedStops,
      );
    });
  }

  Future<void> completeRoute() async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(riderRepositoryProvider).completeRoute(current.id);
      return ActiveRouteEntity(
        id: current.id,
        routeName: current.routeName,
        zone: current.zone,
        stops: current.stops,
        startTime: current.startTime,
        estimatedEndTime: current.estimatedEndTime,
        status: 'completed',
        totalDistanceKm: current.totalDistanceKm,
        completedDistanceKm: current.totalDistanceKm,
        totalStops: current.totalStops,
        completedStops: current.totalStops,
      );
    });
  }
}

@riverpod
class RiderCollectionHistory extends _$RiderCollectionHistory {
  @override
  FutureOr<List<CollectionLogEntity>> build() async {
    return ref.watch(riderRepositoryProvider).getCollectionHistory();
  }
}

@riverpod
class RiderPerformance extends _$RiderPerformance {
  @override
  FutureOr<RiderPerformanceEntity> build() async {
    return ref.watch(riderRepositoryProvider).getPerformanceStats();
  }
}

@riverpod
class RiderNotifications extends _$RiderNotifications {
  @override
  FutureOr<List<RiderNotificationEntity>> build() async {
    return ref.watch(riderRepositoryProvider).getNotifications();
  }

  Future<void> markRead(String id) async {
    final current = state.value ?? [];
    await ref.read(riderRepositoryProvider).markNotificationRead(id);
    state = AsyncValue.data(
      current.map((n) => n.id == id
          ? RiderNotificationEntity(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              receivedAt: n.receivedAt,
              isRead: true,
            )
          : n).toList(),
    );
  }

  void markAllRead() {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((n) => RiderNotificationEntity(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            receivedAt: n.receivedAt,
            isRead: true,
          )).toList(),
    );
  }
}
