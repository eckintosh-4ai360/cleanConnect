import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/rider_entities.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../domain/entities/incident_report_entity.dart';
import '../../domain/entities/bin_verification_result.dart';
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

  // A rider's day is driven by the pickups they accept: nothing in the app or
  // the admin panel ever writes a `routes` / `route_stops` row, so watching
  // that table alone left the Route screen permanently empty. The dispatcher
  // table still wins when a row is actually there -- the accepted pickups are
  // the fallback, which today is the only case that fires.
  @override
  Stream<ActiveRouteEntity?> watchActiveRoute() {
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('assigned_rider_id', _uid)
        .asyncMap((rows) async {
      final dispatched = await _activeRouteRow();
      if (dispatched != null) return _buildActiveRoute(dispatched);
      return _routeFromPickups(rows.map(_pickupFromRow).toList());
    });
  }

  @override
  Future<ActiveRouteEntity?> getActiveRoute() async {
    final dispatched = await _activeRouteRow();
    if (dispatched != null) return _buildActiveRoute(dispatched);

    final rows = await _db
        .from('pickup_requests')
        .select()
        .eq('assigned_rider_id', _uid);
    return _routeFromPickups(
      (rows as List).map((r) => _pickupFromRow(r as Map<String, dynamic>)).toList(),
    );
  }

  Future<Map<String, dynamic>?> _activeRouteRow() async {
    final rows = await _db
        .from('routes')
        .select()
        .eq('assigned_rider_id', _uid)
        .eq('status', 'active')
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Folds the rider's pickups into the shape the Route screen already draws:
  /// still-accepted requests become pending stops, and requests completed
  /// today become collected ones so the progress strip reflects the real day
  /// rather than sitting at zero. Returns null when there is nothing to work.
  ActiveRouteEntity? _routeFromPickups(List<PickupRequestEntity> pickups) {
    final today = DateTime.now();
    bool completedToday(PickupRequestEntity p) {
      final at = p.acceptedAt;
      return p.status == 'completed' &&
          at != null &&
          at.year == today.year &&
          at.month == today.month &&
          at.day == today.day;
    }

    final relevant = pickups
        .where((p) => p.status == 'accepted' || completedToday(p))
        .toList()
      ..sort((a, b) =>
          (a.acceptedAt ?? a.createdAt).compareTo(b.acceptedAt ?? b.createdAt));
    if (relevant.isEmpty) return null;

    final stops = <RouteStopEntity>[];
    for (var i = 0; i < relevant.length; i++) {
      final p = relevant[i];
      stops.add(RouteStopEntity(
        id: p.id,
        customerName: p.customerName,
        address: p.location,
        binType: p.binTypes.isEmpty ? 'general' : p.binTypes.first,
        status: p.status == 'completed' ? 'collected' : 'pending',
        // Weight is only known once the bin is on the scale, so the tile shows
        // nothing rather than a made-up estimate.
        estimatedWeightKg: null,
        // 0,0 for a request with no coordinates: the map reads that as "not
        // plottable" instead of dropping a pin somewhere the rider isn't.
        latitude: p.destinationLat ?? 0,
        longitude: p.destinationLng ?? 0,
        stopOrder: i + 1,
        pickupRequest: p,
      ));
    }

    final pending = stops.where((s) => s.status == 'pending').length;
    final distanceKm = _chainDistanceKm(stops);
    return ActiveRouteEntity(
      id: 'accepted-pickups',
      routeName: "Today's Pickups",
      zone: '$pending stop${pending == 1 ? '' : 's'} remaining',
      totalDistanceKm: distanceKm,
      completedDistanceKm: 0,
      totalStops: stops.length,
      completedStops: stops.length - pending,
      startTime: relevant.first.acceptedAt ?? relevant.first.createdAt,
      // Rough finish: driving the remaining chain plus ten minutes on site per
      // stop. Nothing here is a promise to the customer, it fills the "Est.
      // End" chip on the dashboard.
      estimatedEndTime: pending == 0
          ? null
          : DateTime.now()
              .add(GeoUtils.estimateDuration(distanceKm * 1000))
              .add(Duration(minutes: 10 * pending)),
      status: 'active',
      stops: stops,
    );
  }

  /// Straight-line distance along the stops in order, skipping any without
  /// coordinates. An under-estimate of the driven distance, but derived from
  /// the actual stops rather than the schema's 12 km placeholder.
  double _chainDistanceKm(List<RouteStopEntity> stops) {
    final points = stops
        .where((s) => s.latitude != 0 || s.longitude != 0)
        .map((s) => LatLng(s.latitude, s.longitude))
        .toList();
    var metres = 0.0;
    for (var i = 1; i < points.length; i++) {
      metres += GeoUtils.distanceMeters(points[i - 1], points[i]);
    }
    return metres / 1000;
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
  // Weekly/monthly figures are derived client-side from collection_events and
  // route_stops (RLS already scopes both to the signed-in rider) rather than
  // stored precomputed, since there's no historical daily-snapshot table.
  // earningsPerKg matches the rate the mark_stop_collected/complete_pickup
  // RPCs use to increment riders.earnings_this_month.

  static const double _earningsPerKg = 0.15;

  @override
  Stream<RiderPerformanceEntity> watchPerformanceStats() {
    return _db
        .from('riders')
        .stream(primaryKey: ['id'])
        .eq('id', _uid)
        .asyncMap((rows) => _computePerformanceStats(rows.isEmpty ? {} : rows.first));
  }

  @override
  Future<RiderPerformanceEntity> getPerformanceStats() async {
    final row = await _db.from('riders').select().eq('id', _uid).maybeSingle();
    return _computePerformanceStats(row ?? {});
  }

  Future<RiderPerformanceEntity> _computePerformanceStats(Map<String, dynamic> r) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final windowStart = today.subtract(const Duration(days: 34));

    final eventRows = ((await _db
            .from('collection_events')
            .select('weight_kg, customer_id, address, collected_at')
            .eq('rider_id', _uid)
            .gte('collected_at', windowStart.toIso8601String())) as List)
        .cast<Map<String, dynamic>>();

    // route_stops RLS ("route_stops_select_own_rider") already scopes this
    // to routes assigned to the current rider.
    final stopRows = ((await _db
            .from('route_stops')
            .select('status, created_at')
            .gte('created_at', windowStart.toIso8601String())) as List)
        .cast<Map<String, dynamic>>();

    bool onOrAfter(DateTime cutoff, dynamic raw) {
      final ts = DateTime.tryParse(raw?.toString() ?? '');
      return ts != null && !ts.isBefore(cutoff);
    }

    bool sameDay(DateTime a, dynamic raw) {
      final ts = DateTime.tryParse(raw?.toString() ?? '');
      return ts != null && ts.year == a.year && ts.month == a.month && ts.day == a.day;
    }

    double weightOf(Iterable<Map<String, dynamic>> rows) =>
        rows.fold(0.0, (sum, e) => sum + ((e['weight_kg'] as num?)?.toDouble() ?? 0.0));

    int countStatus(Iterable<Map<String, dynamic>> rows, String status) =>
        rows.where((s) => s['status'] == status).length;

    final weekEvents = eventRows.where((e) => onOrAfter(startOfWeek, e['collected_at'])).toList();
    final monthEvents = eventRows.where((e) => onOrAfter(startOfMonth, e['collected_at'])).toList();

    final weightThisWeek = weightOf(weekEvents);
    final earningsThisWeek = weightThisWeek * _earningsPerKg;

    final topLocationsThisMonth = monthEvents
        .map((e) => (e['customer_id'] as String?) ?? (e['address'] as String? ?? ''))
        .where((v) => v.isNotEmpty)
        .toSet()
        .length;

    final weekStops = stopRows.where((s) => onOrAfter(startOfWeek, s['created_at'])).toList();
    final monthStops = stopRows.where((s) => onOrAfter(startOfMonth, s['created_at'])).toList();
    final monthCollected = countStatus(monthStops, 'collected');
    final monthProblem = countStatus(monthStops, 'problem');
    final monthResolved = monthCollected + monthProblem;
    final onTimeDeliveryRate = monthResolved == 0 ? 1.0 : monthCollected / monthResolved;

    final fallbackScore = (r['efficiency_score'] as num?)?.toDouble() ?? 100.0;
    // null = no stops that day, rendered as "no data" rather than a fabricated score.
    final weeklyScores = List<double?>.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      final dayStops = stopRows.where((s) => sameDay(day, s['created_at']));
      final collected = countStatus(dayStops, 'collected');
      final problem = countStatus(dayStops, 'problem');
      final resolved = collected + problem;
      return resolved == 0 ? null : (collected / resolved) * 100;
    });

    final monthWeight = weightOf(monthEvents);
    final avgEarningsPerCollection =
        monthEvents.isEmpty ? 0.0 : (monthWeight * _earningsPerKg) / monthEvents.length;

    return RiderPerformanceEntity(
      efficiencyScore: fallbackScore,
      averageRating: (r['rating'] as num?)?.toDouble() ?? 5.0,
      collectionsThisWeek: weekEvents.length,
      weightThisWeek: weightThisWeek,
      earningsThisWeek: earningsThisWeek,
      earningsThisMonth: (r['earnings_this_month'] as num?)?.toDouble() ?? 0.0,
      totalCollectionsAllTime: (r['total_collections'] as num?)?.toInt() ?? 0,
      onTimeDeliveryRate: onTimeDeliveryRate,
      weeklyScores: weeklyScores,
      missedStopsThisWeek: countStatus(weekStops, 'problem'),
      missedStopsThisMonth: monthProblem,
      topLocationsThisMonth: topLocationsThisMonth,
      collectionsThisMonth: monthEvents.length,
      avgEarningsPerCollection: avgEarningsPerCollection,
    );
  }

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
  Stream<List<PickupRequestEntity>> watchMyAcceptedPickups() {
    // .stream() only supports one .eq(), so (like watchActivePickupTracking
    // on the customer side) the status check happens client-side.
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('assigned_rider_id', _uid)
        .order('accepted_at', ascending: false)
        .map(
          (rows) => rows
              .where((r) => r['status'] == 'accepted')
              .map(_pickupFromRow)
              .toList(),
        );
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
  Future<void> clearFcmToken() async {
    await _db.from('riders').update({'fcm_token': null}).eq('id', _uid);
  }

  @override
  Future<void> releaseDeviceFcmToken(String token) async {
    // RPC rather than a direct update: nulling *another* rider's row is
    // deliberately outside what the riders RLS policies allow, and the caller
    // here is usually a customer. See release_device_fcm_token's migration.
    await _db.rpc('release_device_fcm_token', params: {'p_token': token});
  }

  @override
  Future<void> rejectPickup({
    required String requestId,
    required String customerId,
  }) async {
    await _db.rpc('reject_pickup', params: {'p_request_id': requestId});
  }

  @override
  Future<BinVerificationResult> verifyPickupBin({
    required String requestId,
    required String serialNumber,
  }) async {
    final result = await _db.rpc('verify_pickup_bin', params: {
      'p_request_id': requestId,
      'p_serial_number': serialNumber,
    });
    final map = result as Map<String, dynamic>;
    return BinVerificationResult(
      verified: map['verified'] as bool? ?? false,
      reason: map['reason'] as String?,
      binId: map['bin_id'] as String?,
      binType: map['bin_type'] as String?,
      binSize: map['bin_size'] as String?,
    );
  }

  @override
  Future<void> completePickup({
    required String requestId,
    required String customerId,
    required double weightKg,
    required String qrCodeData,
    String? notes,
  }) async {
    await _db.rpc('complete_pickup', params: {
      'p_request_id': requestId,
      'p_weight_kg': weightKg,
      'p_qr_code_data': qrCodeData,
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
        destinationLat: (r['location_lat'] as num?)?.toDouble(),
        destinationLng: (r['location_lng'] as num?)?.toDouble(),
        timeSlot: r['time_slot'] as String? ?? '',
        binTypes: (r['bin_types'] as List<dynamic>?)?.cast<String>() ?? ['general'],
        status: r['status'] as String? ?? 'pending',
        assignedRiderId: r['assigned_rider_id'] as String?,
        assignedRiderName: r['assigned_rider_name'] as String?,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        acceptedAt: r['accepted_at'] != null
            ? DateTime.tryParse(r['accepted_at'].toString())
            : null,
        housePhotoUrl: r['house_photo_url'] as String?,
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
