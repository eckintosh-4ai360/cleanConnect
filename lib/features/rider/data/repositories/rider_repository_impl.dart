import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/rider_entities.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../domain/entities/incident_report_entity.dart';
import '../../domain/repositories/rider_repository.dart';

/// Supabase (Postgres)-backed implementation of [RiderRepository].
/// All data is scoped to the currently authenticated user's id via RLS.
class RiderRepositoryImpl implements RiderRepository {
  SupabaseClient get _db => Supabase.instance.client;
  GoTrueClient get _auth => _db.auth;

  String get _uid => _auth.currentUser?.id ?? 'rider_default';

  // ── Profile & Status ─────────────────────────────────────────────────────

  @override
  Stream<RiderEntity?> watchRiderProfile() {
    return _db
        .from('riders')
        .stream(primaryKey: ['id'])
        .eq('id', _uid)
        .map((rows) => rows.isEmpty ? _fallbackProfile() : _riderFromRow(rows.first));
  }

  @override
  Future<RiderEntity> getRiderProfile() async {
    final row = await _db.from('riders').select().eq('id', _uid).maybeSingle();
    if (row == null) return _fallbackProfile();
    return _riderFromRow(row);
  }

  @override
  Future<RiderEntity> updateRiderStatus(String status) async {
    await _db.from('riders').update({'status': status}).eq('id', _uid);
    return getRiderProfile();
  }

  // Identity fields (name/email/photo) come from Supabase Auth rather than a
  // profiles join, since this repo only ever looks at the current rider's own
  // profile and Realtime streams can't embed joined tables — matches the
  // same source Phase 3's UI screens already use.
  RiderEntity _riderFromRow(Map<String, dynamic> r) {
    final authUser = _auth.currentUser;
    return RiderEntity(
      id: r['id'] as String,
      fullName: authUser?.userMetadata?['full_name'] as String? ?? 'Rider',
      email: authUser?.email ?? '',
      phoneNumber: authUser?.userMetadata?['phone_number'] as String? ?? '',
      profilePhotoUrl: authUser?.userMetadata?['avatar_url'] as String?,
      vehicleType: r['vehicle_type'] as String? ?? 'Motorbike',
      licenseNumber: r['license_number'] as String? ?? '',
      nationalIdNumber: r['national_id_number'] as String? ?? '',
      status: r['status'] as String? ?? 'active',
      rating: (r['rating'] as num?)?.toDouble() ?? 5.0,
      totalCollections: (r['total_collections'] as num?)?.toInt() ?? 0,
      totalWeightKg: (r['total_weight_kg'] as num?)?.toDouble() ?? 0.0,
      earningsThisMonth: (r['earnings_this_month'] as num?)?.toDouble() ?? 0.0,
      efficiencyScore: (r['efficiency_score'] as num?)?.toDouble() ?? 100.0,
    );
  }

  RiderEntity _fallbackProfile() {
    final authUser = _auth.currentUser;
    return RiderEntity(
      id: _uid,
      fullName: authUser?.userMetadata?['full_name'] as String? ?? 'Marcus Sterling',
      email: authUser?.email ?? 'marcus@ecowaste.com',
      phoneNumber: '+1 (555) 234-5678',
      profilePhotoUrl:
          'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=200',
      vehicleType: 'compact_van',
      licenseNumber: 'DL-GH-20240312',
      nationalIdNumber: 'GHA-0012345678',
      status: 'active',
      rating: 4.8,
      totalCollections: 12,
      totalWeightKg: 450.0,
      earningsThisMonth: 850.0,
      efficiencyScore: 95.0,
    );
  }

  // ── Active Route & Stops ─────────────────────────────────────────────────

  @override
  Stream<ActiveRouteEntity?> watchActiveRoute() {
    return _db
        .from('routes')
        .stream(primaryKey: ['id'])
        .eq('assigned_rider_id', _uid)
        .asyncMap((rows) async {
      final active = rows.where((r) => r['status'] == 'active').toList();
      if (active.isEmpty) return null;
      return _buildActiveRoute(active.first);
    });
  }

  @override
  Future<ActiveRouteEntity?> getActiveRoute() async {
    final rows = await _db
        .from('routes')
        .select()
        .eq('assigned_rider_id', _uid)
        .eq('status', 'active')
        .limit(1);
    if (rows.isEmpty) return null;
    return _buildActiveRoute(rows.first);
  }

  Future<ActiveRouteEntity> _buildActiveRoute(Map<String, dynamic> r) async {
    final stopRows = await _db
        .from('route_stops')
        .select()
        .eq('route_id', r['id'])
        .order('stop_order');
    final stops = (stopRows as List)
        .map((s) => _stopFromRow(s as Map<String, dynamic>))
        .toList();
    final completedCount = stops.where((s) => s.status == 'collected').length;

    return ActiveRouteEntity(
      id: r['id'] as String,
      routeName: r['route_name'] as String? ?? 'Daily Route',
      zone: r['zone'] as String? ?? 'Central District',
      totalDistanceKm: (r['total_distance_km'] as num?)?.toDouble() ?? 12.0,
      completedDistanceKm: (r['completed_distance_km'] as num?)?.toDouble() ?? 0.0,
      totalStops: stops.isEmpty ? (r['total_stops'] as num?)?.toInt() ?? 0 : stops.length,
      completedStops: completedCount,
      startTime: r['start_time'] != null
          ? DateTime.tryParse(r['start_time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedEndTime: r['estimated_end_time'] != null
          ? DateTime.tryParse(r['estimated_end_time'].toString())
          : DateTime.now().add(const Duration(hours: 3)),
      status: r['status'] as String? ?? 'active',
      stops: stops,
    );
  }

  RouteStopEntity _stopFromRow(Map<String, dynamic> r) => RouteStopEntity(
        id: r['id'] as String,
        customerName: r['customer_name'] as String? ?? 'Customer',
        address: r['address'] as String? ?? '',
        binType: r['bin_type'] as String? ?? 'general',
        status: r['status'] as String? ?? 'pending',
        estimatedWeightKg: (r['estimated_weight_kg'] as num?)?.toDouble() ?? 15.0,
        actualWeightKg: (r['actual_weight_kg'] as num?)?.toDouble(),
        notes: r['notes'] as String?,
        latitude: (r['latitude'] as num?)?.toDouble() ?? 5.6037,
        longitude: (r['longitude'] as num?)?.toDouble() ?? -0.1870,
        stopOrder: (r['stop_order'] as num?)?.toInt() ?? 1,
      );

  @override
  Future<RouteStopEntity> markStopCollected({
    required String stopId,
    required double weightKg,
    String? photoPath,
    String? qrCodeData,
    String? notes,
  }) async {
    final row = await _db.rpc('mark_stop_collected', params: {
      'p_stop_id': stopId,
      'p_weight_kg': weightKg,
      'p_notes': notes,
      'p_qr_code_data': qrCodeData,
    });
    return _stopFromRow(row as Map<String, dynamic>);
  }

  @override
  Future<RouteStopEntity> markStopProblem({
    required String stopId,
    required String reason,
    String? notes,
  }) async {
    final row = await _db
        .from('route_stops')
        .update({'status': 'problem', 'notes': notes ?? reason})
        .eq('id', stopId)
        .select()
        .single();
    return _stopFromRow(row);
  }

  @override
  Future<void> completeRoute(String routeId) async {
    await _db
        .from('routes')
        .update({'status': 'completed', 'completed_at': DateTime.now().toIso8601String()})
        .eq('id', routeId);
  }

  // ── Collection History ───────────────────────────────────────────────────

  @override
  Stream<List<CollectionLogEntity>> watchCollectionHistory() {
    return _db
        .from('collection_events')
        .stream(primaryKey: ['id'])
        .eq('rider_id', _uid)
        .order('collected_at', ascending: false)
        .map((rows) => rows.map(_collectionFromRow).toList());
  }

  @override
  Future<List<CollectionLogEntity>> getCollectionHistory() async {
    final rows = await _db
        .from('collection_events')
        .select()
        .eq('rider_id', _uid)
        .order('collected_at', ascending: false);
    return (rows as List).map((r) => _collectionFromRow(r as Map<String, dynamic>)).toList();
  }

  CollectionLogEntity _collectionFromRow(Map<String, dynamic> r) => CollectionLogEntity(
        id: r['id'] as String,
        customerName: r['customer_name'] as String? ?? 'Customer',
        address: r['address'] as String? ?? '',
        binType: r['bin_type'] as String? ?? 'general',
        weightKg: (r['weight_kg'] as num?)?.toDouble() ?? 0.0,
        collectedAt: DateTime.tryParse(r['collected_at']?.toString() ?? '') ?? DateTime.now(),
        status: r['status'] as String? ?? 'verified',
        notes: r['notes'] as String?,
        qrCodeData: r['qr_verified'] == true ? 'QR-VERIFIED' : null,
      );

  // ── Performance Stats ────────────────────────────────────────────────────
  // NOTE: several fields here were already hardcoded/fake in the original
  // Firestore implementation (earningsThisWeek, onTimeDeliveryRate,
  // weeklyScores) rather than derived from real data — preserved as-is since
  // building real weekly aggregation is a separate feature, not part of this
  // migration.

  @override
  Stream<RiderPerformanceEntity> watchPerformanceStats() {
    return _db
        .from('riders')
        .stream(primaryKey: ['id'])
        .eq('id', _uid)
        .map((rows) => rows.isEmpty ? _performanceFromRow({}) : _performanceFromRow(rows.first));
  }

  @override
  Future<RiderPerformanceEntity> getPerformanceStats() async {
    final row = await _db.from('riders').select().eq('id', _uid).maybeSingle();
    return _performanceFromRow(row ?? {});
  }

  RiderPerformanceEntity _performanceFromRow(Map<String, dynamic> r) => RiderPerformanceEntity(
        efficiencyScore: (r['efficiency_score'] as num?)?.toDouble() ?? 94.2,
        averageRating: (r['rating'] as num?)?.toDouble() ?? 4.8,
        collectionsThisWeek: (r['total_collections'] as num?)?.toInt() ?? 28,
        weightThisWeek: (r['total_weight_kg'] as num?)?.toDouble() ?? 412.6,
        earningsThisWeek: 287.50,
        earningsThisMonth: (r['earnings_this_month'] as num?)?.toDouble() ?? 1248.50,
        totalCollectionsAllTime: (r['total_collections'] as num?)?.toInt() ?? 312,
        onTimeDeliveryRate: 0.982,
        weeklyScores: const [88.0, 91.5, 92.0, 94.2, 93.8, 95.1, 94.2],
      );

  // ── Notifications ─────────────────────────────────────────────────────────

  @override
  Stream<List<RiderNotificationEntity>> watchNotifications() {
    return _db
        .from('rider_notifications')
        .stream(primaryKey: ['id'])
        .eq('rider_id', _uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_notificationFromRow).toList());
  }

  @override
  Future<List<RiderNotificationEntity>> getNotifications() async {
    final rows = await _db
        .from('rider_notifications')
        .select()
        .eq('rider_id', _uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _notificationFromRow(r as Map<String, dynamic>)).toList();
  }

  RiderNotificationEntity _notificationFromRow(Map<String, dynamic> r) => RiderNotificationEntity(
        id: r['id'] as String,
        title: r['title'] as String? ?? 'Notification',
        message: r['message'] as String? ?? '',
        type: r['type'] as String? ?? 'system',
        receivedAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        isRead: r['is_read'] as bool? ?? false,
      );

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _db.from('rider_notifications').update({'is_read': true}).eq('id', notificationId);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _db.rpc('mark_all_rider_notifications_read');
  }

  // ── Available Pickup Requests ────────────────────────────────────────────

  @override
  Stream<List<PickupRequestEntity>> watchAvailablePickups() {
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map((rows) => rows.map(_pickupFromRow).toList());
  }

  @override
  Future<void> acceptPickup({
    required String requestId,
    required String customerId,
  }) async {
    await _db.rpc('accept_pickup', params: {'p_request_id': requestId});
  }

  @override
  Stream<PickupRequestEntity?> watchPickupById(String requestId) {
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((rows) => rows.isEmpty ? null : _pickupFromRow(rows.first));
  }

  @override
  Future<void> updateFcmToken(String token) async {
    await _db.from('riders').update({'fcm_token': token}).eq('id', _uid);
  }

  @override
  Future<void> rejectPickup({
    required String requestId,
    required String customerId,
  }) async {
    await _db.rpc('reject_pickup', params: {'p_request_id': requestId});
  }

  @override
  Future<void> completePickup({
    required String requestId,
    required String customerId,
    required double weightKg,
    String? notes,
  }) async {
    await _db.rpc('complete_pickup', params: {
      'p_request_id': requestId,
      'p_weight_kg': weightKg,
      'p_notes': notes,
    });
  }

  PickupRequestEntity _pickupFromRow(Map<String, dynamic> r) => PickupRequestEntity(
        id: r['id'] as String,
        customerId: r['customer_id'] as String? ?? '',
        customerName: r['customer_name'] as String? ?? 'Customer',
        customerEmail: r['customer_email'] as String? ?? '',
        customerPhone: r['customer_phone'] as String? ?? '',
        location: r['location'] as String? ?? 'Unknown location',
        timeSlot: r['time_slot'] as String? ?? '',
        binTypes: (r['bin_types'] as List<dynamic>?)?.cast<String>() ?? ['general'],
        status: r['status'] as String? ?? 'pending',
        assignedRiderId: r['assigned_rider_id'] as String?,
        assignedRiderName: r['assigned_rider_name'] as String?,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        acceptedAt: r['accepted_at'] != null
            ? DateTime.tryParse(r['accepted_at'].toString())
            : null,
      );

  @override
  Future<void> updateRiderLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    String? currentJobId,
  }) async {
    await _db.rpc('update_rider_location', params: {
      'p_lat': latitude,
      'p_lng': longitude,
      'p_heading': heading,
      'p_speed': speed,
      'p_current_job_id': currentJobId,
    });
  }

  // ── Incident Reports (waste dumps / choked gutters) ──────────────────────

  @override
  Stream<List<IncidentReportEntity>> watchAssignedIncidentReports() {
    return _db
        .from('incident_reports')
        .stream(primaryKey: ['id'])
        .eq('assigned_rider_id', _uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_incidentReportFromRow).toList());
  }

  @override
  Future<void> updateIncidentReportStatus({
    required String reportId,
    required String reporterId,
    required String status,
  }) async {
    await _db.from('incident_reports').update({'status': status}).eq('id', reportId);
  }

  IncidentReportEntity _incidentReportFromRow(Map<String, dynamic> r) => IncidentReportEntity(
        id: r['id'] as String,
        reporterId: r['reporter_id'] as String? ?? '',
        reporterName: r['reporter_name'] as String? ?? 'Customer',
        reporterPhone: r['reporter_phone'] as String? ?? '',
        description: r['description'] as String? ?? '',
        mediaUrl: r['media_url'] as String?,
        mediaType: r['media_type'] as String?,
        location: r['location'] as String? ?? '',
        status: r['status'] as String? ?? 'pending',
        assignedRiderId: r['assigned_rider_id'] as String?,
        assignedRiderName: r['assigned_rider_name'] as String?,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
