import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/entities/incident_report_entity.dart';
import '../../domain/entities/pickup_tracking_entity.dart';
import '../../domain/repositories/customer_repository.dart';

/// Supabase (Postgres)-backed implementation of [CustomerRepository].
/// All data is scoped to the currently authenticated user's id via RLS.
class CustomerRepositoryImpl implements CustomerRepository {
  SupabaseClient get _db => Supabase.instance.client;
  GoTrueClient get _auth => _db.auth;
  final Random _random = Random();

  String get _uid => _auth.currentUser?.id ?? '';

  // ── Bins ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<BinEntity>> watchBins() {
    return _db
        .from('bins')
        .stream(primaryKey: ['id'])
        .eq('customer_id', _uid)
        .order('registered_at')
        .map((rows) => rows.map(_binFromRow).toList());
  }

  @override
  Future<List<BinEntity>> getBins() async {
    final rows = await _db
        .from('bins')
        .select()
        .eq('customer_id', _uid)
        .order('registered_at');
    return (rows as List).map((r) => _binFromRow(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<BinEntity> registerBin({
    required String type,
    required String size,
    required String frequency,
    required List<String> pickupDays,
    required String gpsLocation,
    String? photoPath,
  }) async {
    final serialNumber = _generatePersonalBinSerial(type);
    final row = await _db.rpc('register_bin', params: {
      'p_serial_number': serialNumber,
      'p_type': type,
      'p_size': size,
      'p_frequency': frequency,
      'p_pickup_days': pickupDays,
      'p_gps_location': gpsLocation,
      'p_photo_path': photoPath,
    });
    return _binFromRow(row as Map<String, dynamic>);
  }

  @override
  Future<void> requestCompanyBin({
    required String type,
    required String size,
    required String gpsLocation,
  }) async {
    await _db.rpc('request_company_bin', params: {
      'p_type': type,
      'p_size': size,
      'p_gps_location': gpsLocation,
    });
  }

  /// Matches the admin panel's bin serial format (see admin_panel/src/components/Bins.jsx
  /// generateSerialNumber), e.g. "CCB-REC-9LDHV6775", so personal and
  /// admin-assigned bins share one consistent scheme.
  String _generatePersonalBinSerial(String type) {
    final prefix = type == 'organic' ? 'ORG' : 'REC';
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final timePart = timestamp.toRadixString(36).toUpperCase();
    final timeSuffix = timePart.length > 5
        ? timePart.substring(timePart.length - 5)
        : timePart;
    final randomPart = 1000 + _random.nextInt(9000);
    return 'CCB-$prefix-$timeSuffix$randomPart';
  }

  BinEntity _binFromRow(Map<String, dynamic> r) => BinEntity(
        id: r['id'] as String,
        serialNumber: r['serial_number'] as String? ?? '',
        type: r['type'] as String? ?? 'general',
        size: r['size'] as String? ?? '240L',
        fillLevelPercentage: (r['fill_level_percentage'] as num?)?.toDouble() ?? 0.0,
        scheduleFrequency: r['schedule_frequency'] as String?,
        pickupDays: (r['pickup_days'] as List<dynamic>?)?.cast<String>(),
        gpsLocation: r['gps_location'] as String?,
        verificationPhotoUrl: r['verification_photo_url'] as String?,
        registeredDate:
            DateTime.tryParse(r['registered_at']?.toString() ?? '') ?? DateTime.now(),
        ownership: r['ownership'] as String? ?? 'personal',
      );

  @override
  Future<BinEntity> updateBin({
    required String binId,
    required String frequency,
    required List<String> pickupDays,
  }) async {
    final row = await _db.rpc('customer_update_bin', params: {
      'p_bin_id': binId,
      'p_frequency': frequency,
      'p_pickup_days': pickupDays,
    });
    return _binFromRow(row as Map<String, dynamic>);
  }

  @override
  Future<void> deleteBin(String binId) async {
    await _db.rpc('customer_delete_bin', params: {'p_bin_id': binId});
  }

  // ── Pickup Requests ──────────────────────────────────────────────────────

  @override
  Stream<List<PickupRequestEntity>> watchPickupRequests() {
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('customer_id', _uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_requestFromRow).toList());
  }

  @override
  Future<List<PickupRequestEntity>> getPickupRequests() async {
    final rows = await _db
        .from('pickup_requests')
        .select()
        .eq('customer_id', _uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _requestFromRow(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<PickupRequestEntity> schedulePickup({
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    required double amountPaid,
    required String paymentMethod,
    String? instructions,
    double originalAmount = 0.0,
    double discountAppliedPercentage = 0.0,
    double surchargeAppliedPercentage = 0.0,
    double? locationLat,
    double? locationLng,
    String? paymentReference,
  }) async {
    final receiptNumber =
        'PU-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final row = await _db.rpc('schedule_pickup', params: {
      'p_bin_types': binTypes,
      'p_date': date.toIso8601String(),
      'p_time_slot': timeSlot,
      'p_location': location,
      'p_amount_paid': amountPaid,
      'p_payment_method': paymentMethod,
      'p_instructions': instructions,
      'p_original_amount': originalAmount,
      'p_discount_applied_percentage': discountAppliedPercentage,
      'p_surcharge_applied_percentage': surchargeAppliedPercentage,
      'p_receipt_number': receiptNumber,
      'p_payment_reference': paymentReference,
      // Sent only when the device actually produced a fix. Omitting the keys
      // (rather than passing nulls) lets schedule_pickup fall back to parsing
      // coordinates out of the location text, which is where a saved bin's
      // gps_location already puts them.
      if (locationLat != null && locationLng != null) 'p_location_lat': locationLat,
      if (locationLat != null && locationLng != null) 'p_location_lng': locationLng,
    });

    return _requestFromRow(row as Map<String, dynamic>);
  }

  @override
  Future<void> cancelPickupRequest(String requestId) async {
    await _db.rpc('cancel_pickup', params: {'p_request_id': requestId});
  }

  // -- Live tracking --------------------------------------------------------

  @override
  Stream<PickupTrackingEntity?> watchPickupTracking(String requestId) {
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          return _trackingFromRow(rows.first);
        });
  }

  @override
  Stream<PickupTrackingEntity?> watchActivePickupTracking() {
    // .stream() supports a single .eq(), so the status filter is applied in
    // Dart. The customer's own request list is small, and doing it here keeps
    // the Realtime subscription on the same channel the rest of the customer
    // screens already use.
    return _db
        .from('pickup_requests')
        .stream(primaryKey: ['id'])
        .eq('customer_id', _uid)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          const liveStatuses = {'pending', 'accepted', 'assigned', 'confirmed'};
          Map<String, dynamic>? best;
          for (final row in rows) {
            if (!liveStatuses.contains(row['status'] as String? ?? '')) continue;
            // An assigned request outranks a still-pending one: that is the
            // one with a rider to actually follow on the map.
            if (best == null ||
                (row['assigned_rider_id'] != null && best['assigned_rider_id'] == null)) {
              best = row;
            }
          }
          if (best == null) return null;
          return _trackingFromRow(best);
        });
  }

  @override
  Future<void> setPickupDestination({
    required String requestId,
    required double latitude,
    required double longitude,
  }) async {
    await _db.rpc('set_pickup_destination', params: {
      'p_request_id': requestId,
      'p_lat': latitude,
      'p_lng': longitude,
    });
  }

  /// Rider contact details are fetched through an RPC rather than a join --
  /// customers have no select policy on `riders` or another user's `profiles`.
  /// Cached per request id so a position update every few seconds does not
  /// re-fetch a card that cannot have changed.
  final Map<String, Map<String, dynamic>?> _riderCardCache = {};

  Future<Map<String, dynamic>?> _riderCard(String requestId, String? riderId) async {
    if (riderId == null) return null;
    if (_riderCardCache.containsKey(requestId)) return _riderCardCache[requestId];

    try {
      final rows = await _db.rpc('get_pickup_rider_card', params: {
        'p_request_id': requestId,
      });
      final list = (rows as List?) ?? const [];
      final card = list.isEmpty ? null : list.first as Map<String, dynamic>;
      _riderCardCache[requestId] = card;
      return card;
    } catch (_) {
      // Contact details are a nicety; losing them must not blank the map.
      return null;
    }
  }

  Future<PickupTrackingEntity> _trackingFromRow(Map<String, dynamic> r) async {
    final requestId = r['id'] as String;
    final riderId = r['assigned_rider_id'] as String?;
    final card = await _riderCard(requestId, riderId);

    return PickupTrackingEntity(
      requestId: requestId,
      status: r['status'] as String? ?? 'pending',
      location: r['location'] as String? ?? '',
      destinationLat: (r['location_lat'] as num?)?.toDouble(),
      destinationLng: (r['location_lng'] as num?)?.toDouble(),
      riderId: riderId,
      riderName: (card?['full_name'] as String?) ??
          r['assigned_rider_name'] as String?,
      riderPhone: card?['phone_number'] as String?,
      riderPhotoUrl: card?['photo_url'] as String?,
      vehicleType: card?['vehicle_type'] as String?,
      riderRating: (card?['rating'] as num?)?.toDouble(),
      riderLat: (r['rider_lat'] as num?)?.toDouble(),
      riderLng: (r['rider_lng'] as num?)?.toDouble(),
      riderHeading: (r['rider_heading'] as num?)?.toDouble(),
      riderSpeed: (r['rider_speed'] as num?)?.toDouble(),
      riderLocationUpdatedAt:
          DateTime.tryParse(r['rider_location_updated_at']?.toString() ?? ''),
      acceptedAt: DateTime.tryParse(r['accepted_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(r['completed_at']?.toString() ?? ''),
    );
  }

  PickupRequestEntity _requestFromRow(Map<String, dynamic> r) => PickupRequestEntity(
        id: r['id'] as String,
        binTypes: (r['bin_types'] as List<dynamic>?)?.cast<String>() ?? [],
        date: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
        timeSlot: r['time_slot'] as String? ?? '',
        location: r['location'] as String? ?? '',
        instructions: r['instructions'] as String?,
        status: r['status'] as String? ?? 'pending',
        amountPaid: (r['amount_paid'] as num?)?.toDouble() ?? 0.0,
        originalAmount: (r['original_amount'] as num?)?.toDouble() ?? 0.0,
        discountAppliedPercentage:
            (r['discount_applied_percentage'] as num?)?.toDouble() ?? 0.0,
        surchargeAppliedPercentage:
            (r['surcharge_applied_percentage'] as num?)?.toDouble() ?? 0.0,
      );

  // ── Service History ──────────────────────────────────────────────────────

  @override
  Stream<List<ServiceRecordEntity>> watchServiceHistory() {
    return _db
        .from('service_history')
        .stream(primaryKey: ['id'])
        .eq('customer_id', _uid)
        .order('date', ascending: false)
        .map((rows) => rows.map(_recordFromRow).toList());
  }

  @override
  Future<List<ServiceRecordEntity>> getServiceHistory() async {
    final rows = await _db
        .from('service_history')
        .select()
        .eq('customer_id', _uid)
        .order('date', ascending: false);
    return (rows as List).map((r) => _recordFromRow(r as Map<String, dynamic>)).toList();
  }

  ServiceRecordEntity _recordFromRow(Map<String, dynamic> r) => ServiceRecordEntity(
        id: r['id'] as String,
        title: r['title'] as String? ?? 'Service Record',
        type: r['type'] as String? ?? 'collection',
        date: DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now(),
        status: r['status'] as String? ?? 'completed',
        weightKg: (r['weight_kg'] as num?)?.toDouble(),
        co2OffsetKg: (r['co2_offset_kg'] as num?)?.toDouble(),
        compositionPercentages: r['composition_percentages'] != null
            ? Map<String, double>.from(
                (r['composition_percentages'] as Map).map(
                  (k, v) => MapEntry(k as String, (v as num).toDouble()),
                ),
              )
            : null,
        amountPaid: (r['amount_paid'] as num?)?.toDouble() ?? 0.0,
        receiptNumber: r['receipt_number'] as String?,
        paymentMethod: r['payment_method'] as String?,
      );

  // ── Subscription ─────────────────────────────────────────────────────────

  @override
  Stream<SubscriptionEntity> watchSubscription() {
    return _db
        .from('customers')
        .stream(primaryKey: ['id'])
        .eq('id', _uid)
        .map((rows) => rows.isEmpty ? _defaultSubscription() : _subscriptionFromRow(rows.first));
  }

  @override
  Future<SubscriptionEntity> getSubscription() async {
    final row = await _db.from('customers').select().eq('id', _uid).maybeSingle();
    if (row == null) return _defaultSubscription();
    return _subscriptionFromRow(row);
  }

  SubscriptionEntity _subscriptionFromRow(Map<String, dynamic> r) => SubscriptionEntity(
        currentPlan: r['subscription_plan_name'] as String? ?? 'Weekly Plan',
        fee: (r['subscription_fee'] as num?)?.toDouble() ?? 0.0,
        status: r['subscription_status'] as String? ?? 'active',
        paymentMethod: r['payment_method'] as String? ?? 'Mobile Money',
        outstandingBalance: (r['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
        nextPickupDate: r['next_pickup_date'] != null
            ? DateTime.tryParse(r['next_pickup_date'].toString())
            : null,
        nextPickupTimeSlot: r['next_pickup_time_slot'] as String?,
        nextPickupBinTypes: (r['next_pickup_bin_types'] as List<dynamic>?)?.cast<String>(),
        delayBonusAvailable: r['delay_bonus_available'] as bool? ?? false,
        lastPickupCompletedAt: r['last_pickup_completed_at'] != null
            ? DateTime.tryParse(r['last_pickup_completed_at'].toString())
            : null,
        housePhotoUrl: r['house_photo_url'] as String?,
      );

  SubscriptionEntity _defaultSubscription() => const SubscriptionEntity(
        currentPlan: 'Weekly Plan',
        fee: 0.0,
        status: 'active',
        paymentMethod: 'Mobile Money',
        outstandingBalance: 0.0,
      );

  @override
  Stream<List<PricingPlanEntity>> watchPricingPlans() {
    return _db
        .from('pricing_plans')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(_pricingPlanFromRow).toList());
  }

  PricingPlanEntity _pricingPlanFromRow(Map<String, dynamic> r) {
    final rawPrices = r['prices'] as Map<String, dynamic>? ?? {};
    final pricesMap = <String, double>{};
    rawPrices.forEach((k, v) => pricesMap[k] = (v as num).toDouble());
    return PricingPlanEntity(
      id: r['id'] as String,
      name: r['name'] as String? ?? '',
      frequency: r['frequency'] as String? ?? 'Weekly',
      description: r['description'] as String? ?? '',
      isPayg: r['is_payg'] as bool? ?? false,
      prices: pricesMap,
    );
  }

  @override
  Future<SubscriptionEntity> updateSubscription({
    required String newPlan,
    required double fee,
    required String paymentMethod,
    String? paymentReference,
  }) async {
    await _db.from('customers').update({
      'subscription_plan_name': newPlan,
      'subscription_fee': fee,
      'payment_method': paymentMethod,
      'subscription_status': 'active',
      'last_payment_reference': ?paymentReference,
    }).eq('id', _uid);
    return getSubscription();
  }

  @override
  Future<void> updateHousePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    // Fixed path per customer (not a new file per upload) so re-uploading
    // overwrites the old photo instead of accumulating orphaned files, and so
    // every pickup_requests snapshot that already points at this URL updates
    // too -- see schedule_pickup, which copies the URL at request time.
    final path = '$_uid/house.$extension';
    await _db.storage.from('house-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final publicUrl = _db.storage.from('house-photos').getPublicUrl(path);
    // The path is fixed per customer, so a re-upload keeps the same URL --
    // append a cache-busting query param or every viewer (rider app, this
    // app's own Image.network cache) keeps showing the photo it fetched
    // before this update.
    final url = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('customers').update({'house_photo_url': url}).eq('id', _uid);
  }

  @override
  Future<void> payOutstandingBalance() async {
    final receiptNumber =
        'REC-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';
    await _db.rpc('pay_outstanding_balance', params: {'p_receipt_number': receiptNumber});
  }

  @override
  Future<void> reportProblem({
    required String category,
    required String description,
  }) async {
    await _db.from('service_history').insert({
      'customer_id': _uid,
      'title': 'Support Ticket: $category',
      'type': 'support',
      'status': 'pending',
      'amount_paid': 0.0,
      'description': description,
    });
  }

  // ── Incident Reports (waste dumps / choked gutters) ─────────────────────

  @override
  Stream<List<IncidentReportEntity>> watchIncidentReports() {
    return _db
        .from('incident_reports')
        .stream(primaryKey: ['id'])
        .eq('reporter_id', _uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_incidentReportFromRow).toList());
  }

  @override
  Future<IncidentReportEntity> submitIncidentReport({
    required String description,
    required String location,
    Uint8List? mediaBytes,
    String? mediaFileName,
    String? mediaType,
  }) async {
    String? mediaUrl;
    if (mediaBytes != null && mediaFileName != null) {
      final reportFolderId = DateTime.now().millisecondsSinceEpoch.toString();
      final path = '$_uid/$reportFolderId/$mediaFileName';
      await _db.storage.from('incident-reports').uploadBinary(path, mediaBytes);
      mediaUrl = _db.storage.from('incident-reports').getPublicUrl(path);
    }

    final row = await _db.rpc('submit_incident_report', params: {
      'p_description': description,
      'p_location': location,
      'p_media_url': mediaUrl,
      'p_media_type': mediaType,
    });

    return _incidentReportFromRow(row as Map<String, dynamic>);
  }

  IncidentReportEntity _incidentReportFromRow(Map<String, dynamic> r) => IncidentReportEntity(
        id: r['id'] as String,
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
