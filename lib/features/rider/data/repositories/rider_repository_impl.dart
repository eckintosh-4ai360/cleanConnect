import '../../domain/entities/rider_entities.dart';
import '../../domain/repositories/rider_repository.dart';

class RiderRepositoryImpl implements RiderRepository {
  // Mock data for demonstration

  @override
  Future<RiderEntity> getRiderProfile() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return const RiderEntity(
      id: 'rider_001',
      fullName: 'Marcus Sterling',
      email: 'marcus.sterling@ecowaste.com',
      phoneNumber: '+1 (555) 234-5678',
      profilePhotoUrl:
          'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=200',
      vehicleType: 'compact_van',
      licenseNumber: 'DL-GH-20240312',
      nationalIdNumber: 'GHA-0012345678',
      status: 'active',
      rating: 4.8,
      totalCollections: 312,
      totalWeightKg: 14800,
      earningsThisMonth: 1248.50,
      efficiencyScore: 94.2,
    );
  }

  @override
  Future<RiderEntity> updateRiderStatus(String status) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return RiderEntity(
      id: 'rider_001',
      fullName: 'Marcus Sterling',
      email: 'marcus.sterling@ecowaste.com',
      phoneNumber: '+1 (555) 234-5678',
      profilePhotoUrl:
          'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=200',
      vehicleType: 'compact_van',
      licenseNumber: 'DL-GH-20240312',
      nationalIdNumber: 'GHA-0012345678',
      status: status,
      rating: 4.8,
      totalCollections: 312,
      totalWeightKg: 14800,
      earningsThisMonth: 1248.50,
      efficiencyScore: 94.2,
    );
  }

  @override
  Future<ActiveRouteEntity?> getActiveRoute() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return ActiveRouteEntity(
      id: 'route_oct_15',
      routeName: 'Zone A – Morning Run',
      zone: 'North District',
      totalDistanceKm: 18.4,
      completedDistanceKm: 7.2,
      totalStops: 14,
      completedStops: 5,
      startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      estimatedEndTime: DateTime.now().add(const Duration(hours: 2, minutes: 10)),
      status: 'active',
      stops: [
        RouteStopEntity(
          id: 'stop_01',
          customerName: 'Sarah Johnson',
          address: '12 Oak Street, North District',
          binType: 'general',
          status: 'collected',
          estimatedWeightKg: 18.0,
          actualWeightKg: 17.4,
          latitude: 5.6037,
          longitude: -0.1870,
          stopOrder: 1,
        ),
        RouteStopEntity(
          id: 'stop_02',
          customerName: 'Mark & Elena Davis',
          address: '45 Elm Avenue, North District',
          binType: 'recycling',
          status: 'collected',
          estimatedWeightKg: 12.0,
          actualWeightKg: 11.2,
          latitude: 5.6050,
          longitude: -0.1860,
          stopOrder: 2,
        ),
        RouteStopEntity(
          id: 'stop_03',
          customerName: 'Maria Kowalski',
          address: '78 Pine Road, North District',
          binType: 'organic',
          status: 'collected',
          estimatedWeightKg: 20.0,
          actualWeightKg: 19.8,
          latitude: 5.6065,
          longitude: -0.1845,
          stopOrder: 3,
        ),
        RouteStopEntity(
          id: 'stop_04',
          customerName: 'Other Residence',
          address: '90 Cedar Lane, North District',
          binType: 'general',
          status: 'collected',
          estimatedWeightKg: 15.0,
          actualWeightKg: 14.6,
          latitude: 5.6080,
          longitude: -0.1830,
          stopOrder: 4,
        ),
        RouteStopEntity(
          id: 'stop_05',
          customerName: 'James Osei',
          address: '102 Maple Close, North District',
          binType: 'recycling',
          status: 'collected',
          estimatedWeightKg: 10.0,
          actualWeightKg: 9.5,
          latitude: 5.6095,
          longitude: -0.1815,
          stopOrder: 5,
        ),
        RouteStopEntity(
          id: 'stop_06',
          customerName: 'Abena Mensah',
          address: '15 Baobab Street, North District',
          binType: 'general',
          status: 'pending',
          estimatedWeightKg: 22.0,
          latitude: 5.6110,
          longitude: -0.1800,
          stopOrder: 6,
        ),
        RouteStopEntity(
          id: 'stop_07',
          customerName: 'Kwame Asante',
          address: '33 Acacia Drive, North District',
          binType: 'recycling',
          status: 'pending',
          estimatedWeightKg: 14.0,
          latitude: 5.6125,
          longitude: -0.1790,
          stopOrder: 7,
        ),
        RouteStopEntity(
          id: 'stop_08',
          customerName: 'Chen Family',
          address: '55 Lotus Avenue, North District',
          binType: 'organic',
          status: 'pending',
          estimatedWeightKg: 18.0,
          latitude: 5.6140,
          longitude: -0.1780,
          stopOrder: 8,
        ),
        RouteStopEntity(
          id: 'stop_09',
          customerName: 'Fatima Al-Hassan',
          address: '67 Mango Boulevard, North District',
          binType: 'general',
          status: 'pending',
          estimatedWeightKg: 25.0,
          latitude: 5.6155,
          longitude: -0.1770,
          stopOrder: 9,
        ),
        RouteStopEntity(
          id: 'stop_10',
          customerName: 'David & Rose Ntim',
          address: '88 Palm Circle, North District',
          binType: 'recycling',
          status: 'pending',
          estimatedWeightKg: 16.0,
          latitude: 5.6170,
          longitude: -0.1760,
          stopOrder: 10,
        ),
        RouteStopEntity(
          id: 'stop_11',
          customerName: 'Grace Owusu',
          address: '99 Tulip Lane, North District',
          binType: 'general',
          status: 'pending',
          estimatedWeightKg: 20.0,
          latitude: 5.6185,
          longitude: -0.1750,
          stopOrder: 11,
        ),
        RouteStopEntity(
          id: 'stop_12',
          customerName: 'Emmanuel Boateng',
          address: '110 Orchid Street, North District',
          binType: 'organic',
          status: 'pending',
          estimatedWeightKg: 17.0,
          latitude: 5.6200,
          longitude: -0.1740,
          stopOrder: 12,
        ),
        RouteStopEntity(
          id: 'stop_13',
          customerName: 'Linda Acheampong',
          address: '122 Rose Avenue, North District',
          binType: 'general',
          status: 'pending',
          estimatedWeightKg: 21.0,
          latitude: 5.6215,
          longitude: -0.1730,
          stopOrder: 13,
        ),
        RouteStopEntity(
          id: 'stop_14',
          customerName: 'Felix Darko',
          address: '134 Sunflower Close, North District',
          binType: 'recycling',
          status: 'pending',
          estimatedWeightKg: 13.0,
          latitude: 5.6230,
          longitude: -0.1720,
          stopOrder: 14,
        ),
      ],
    );
  }

  @override
  Future<List<CollectionLogEntity>> getCollectionHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    return [
      CollectionLogEntity(
        id: 'col_001',
        customerName: 'Sarah Johnson',
        address: '12 Oak Street',
        binType: 'general',
        weightKg: 17.4,
        collectedAt: now.subtract(const Duration(hours: 1, minutes: 5)),
        status: 'verified',
        qrCodeData: 'BIN-GEN-0023',
      ),
      CollectionLogEntity(
        id: 'col_002',
        customerName: 'Mark & Elena Davis',
        address: '45 Elm Avenue',
        binType: 'recycling',
        weightKg: 11.2,
        collectedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
        status: 'verified',
        qrCodeData: 'BIN-REC-0041',
      ),
      CollectionLogEntity(
        id: 'col_003',
        customerName: 'Maria Kowalski',
        address: '78 Pine Road',
        binType: 'organic',
        weightKg: 19.8,
        collectedAt: now.subtract(const Duration(days: 1, hours: 2)),
        status: 'verified',
      ),
      CollectionLogEntity(
        id: 'col_004',
        customerName: 'Other Residence',
        address: '90 Cedar Lane',
        binType: 'general',
        weightKg: 14.6,
        collectedAt: now.subtract(const Duration(days: 1, hours: 3)),
        status: 'verified',
      ),
      CollectionLogEntity(
        id: 'col_005',
        customerName: 'James Osei',
        address: '102 Maple Close',
        binType: 'recycling',
        weightKg: 9.5,
        collectedAt: now.subtract(const Duration(days: 2)),
        status: 'pending_review',
        notes: 'Scale malfunction – estimated weight used',
      ),
      CollectionLogEntity(
        id: 'col_006',
        customerName: 'Yaa Asantewaa',
        address: '55 Heritage Rd',
        binType: 'general',
        weightKg: 22.1,
        collectedAt: now.subtract(const Duration(days: 2, hours: 4)),
        status: 'verified',
      ),
      CollectionLogEntity(
        id: 'col_007',
        customerName: 'Peter Mensah',
        address: '77 Accra Street',
        binType: 'recycling',
        weightKg: 8.3,
        collectedAt: now.subtract(const Duration(days: 3)),
        status: 'problem',
        notes: 'Bin was contaminated – hazardous materials found',
      ),
    ];
  }

  @override
  Future<RiderPerformanceEntity> getPerformanceStats() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const RiderPerformanceEntity(
      efficiencyScore: 94.2,
      averageRating: 4.8,
      collectionsThisWeek: 28,
      weightThisWeek: 412.6,
      earningsThisWeek: 287.50,
      earningsThisMonth: 1248.50,
      totalCollectionsAllTime: 312,
      onTimeDeliveryRate: 0.982,
      weeklyScores: [88.0, 91.5, 92.0, 94.2, 93.8, 95.1, 94.2],
    );
  }

  @override
  Future<List<RiderNotificationEntity>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      RiderNotificationEntity(
        id: 'notif_001',
        title: 'Emergency Alert',
        message:
            'Traffic closure on Accra Ring Road. Alternate route via Liberation Rd suggested for stops 6–10.',
        type: 'alert',
        receivedAt: now.subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
      RiderNotificationEntity(
        id: 'notif_002',
        title: 'New instruction assigned',
        message:
            'Stop #7 – Kwame Asante has moved bin to back gate. Use alley entrance.',
        type: 'new_route',
        receivedAt: now.subtract(const Duration(minutes: 45)),
        isRead: false,
      ),
      RiderNotificationEntity(
        id: 'notif_003',
        title: 'Route updated',
        message:
            'Stop #9 – Fatima Al-Hassan has been added to your route. Priority: HIGH.',
        type: 'new_route',
        receivedAt: now.subtract(const Duration(hours: 1)),
        isRead: true,
      ),
      RiderNotificationEntity(
        id: 'notif_004',
        title: 'Admin message',
        message:
            'Reminder: Team meeting at 4 PM today at depot. Attendance mandatory.',
        type: 'system',
        receivedAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        isRead: true,
      ),
      RiderNotificationEntity(
        id: 'notif_005',
        title: 'Payment processed',
        message:
            'Your earnings of \$287.50 for this week have been transferred to your account.',
        type: 'payment',
        receivedAt: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<RouteStopEntity> markStopCollected({
    required String stopId,
    required double weightKg,
    String? photoPath,
    String? qrCodeData,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return RouteStopEntity(
      id: stopId,
      customerName: 'Customer',
      address: 'Address',
      binType: 'general',
      status: 'collected',
      actualWeightKg: weightKg,
      notes: notes,
      latitude: 5.6037,
      longitude: -0.1870,
      stopOrder: 1,
    );
  }

  @override
  Future<RouteStopEntity> markStopProblem({
    required String stopId,
    required String reason,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return RouteStopEntity(
      id: stopId,
      customerName: 'Customer',
      address: 'Address',
      binType: 'general',
      status: 'problem',
      notes: notes ?? reason,
      latitude: 5.6037,
      longitude: -0.1870,
      stopOrder: 1,
    );
  }

  @override
  Future<void> completeRoute(String routeId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
