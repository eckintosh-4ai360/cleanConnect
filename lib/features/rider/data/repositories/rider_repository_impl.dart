import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/rider_entities.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../domain/entities/incident_report_entity.dart';
import '../../domain/repositories/rider_repository.dart';

class RiderRepositoryImpl implements RiderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? 'rider_default';

  DocumentReference get _riderRef => _db.collection('riders').doc(_uid);

  CollectionReference get _notificationsRef =>
      _riderRef.collection('notifications');

  CollectionReference get _routesRef => _db.collection('routes');

  CollectionReference get _collectionsRef => _db.collection('collections');

  // ── Profile & Status ──────────────────────────────────────────────────────

  @override
  Stream<RiderEntity?> watchRiderProfile() {
    return _riderRef.snapshots().map((doc) {
      if (!doc.exists) return _fallbackProfile();
      return _riderFromDoc(doc);
    });
  }

  @override
  Future<RiderEntity> getRiderProfile() async {
    final doc = await _riderRef.get();
    if (!doc.exists) return _fallbackProfile();
    return _riderFromDoc(doc);
  }

  @override
  Future<RiderEntity> updateRiderStatus(String status) async {
    await _riderRef.set(
      {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return getRiderProfile();
  }

  RiderEntity _riderFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RiderEntity(
      id: doc.id,
      fullName: d['fullName'] as String? ?? 'Rider',
      email: d['email'] as String? ?? '',
      phoneNumber: d['phoneNumber'] as String? ?? '',
      profilePhotoUrl: d['photoUrl'] as String? ?? d['profilePhotoUrl'] as String? ?? '',
      vehicleType: d['vehicleType'] as String? ?? 'Motorbike',
      licenseNumber: d['licenseNumber'] as String? ?? '',
      nationalIdNumber: d['nationalIdNumber'] as String? ?? '',
      status: d['status'] as String? ?? 'active',
      rating: (d['rating'] as num?)?.toDouble() ?? 5.0,
      totalCollections: (d['totalCollections'] as num?)?.toInt() ?? 0,
      totalWeightKg: (d['totalWeightKg'] as num?)?.toDouble() ?? 0.0,
      earningsThisMonth: (d['earningsThisMonth'] as num?)?.toDouble() ?? 0.0,
      efficiencyScore: (d['efficiencyScore'] as num?)?.toDouble() ?? 100.0,
    );
  }

  RiderEntity _fallbackProfile() => RiderEntity(
        id: _uid,
        fullName: _auth.currentUser?.displayName ?? 'Marcus Sterling',
        email: _auth.currentUser?.email ?? 'marcus@ecowaste.com',
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

  // ── Active Route & Stops ──────────────────────────────────────────────────

  @override
  Stream<ActiveRouteEntity?> watchActiveRoute() {
    return _routesRef
        .where('assignedRiderId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return null;
      final routeDoc = snap.docs.first;
      return _buildActiveRoute(routeDoc);
    });
  }

  @override
  Future<ActiveRouteEntity?> getActiveRoute() async {
    final snap = await _routesRef
        .where('assignedRiderId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return _buildActiveRoute(snap.docs.first);
  }

  Future<ActiveRouteEntity> _buildActiveRoute(DocumentSnapshot routeDoc) async {
    final d = routeDoc.data() as Map<String, dynamic>? ?? {};

    // Fetch stops subcollection
    final stopsSnap = await routeDoc.reference
        .collection('stops')
        .orderBy('stopOrder', descending: false)
        .get();

    final stops = stopsSnap.docs.map(_stopFromDoc).toList();

    final completedCount = stops.where((s) => s.status == 'collected').length;

    return ActiveRouteEntity(
      id: routeDoc.id,
      routeName: d['routeName'] as String? ?? 'Daily Route',
      zone: d['zone'] as String? ?? 'Central District',
      totalDistanceKm: (d['totalDistanceKm'] as num?)?.toDouble() ?? 12.0,
      completedDistanceKm: (d['completedDistanceKm'] as num?)?.toDouble() ?? 0.0,
      totalStops: stops.isEmpty ? (d['totalStops'] as num?)?.toInt() ?? 0 : stops.length,
      completedStops: completedCount,
      startTime: d['startTime'] is Timestamp
          ? (d['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      estimatedEndTime: d['estimatedEndTime'] is Timestamp
          ? (d['estimatedEndTime'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 3)),
      status: d['status'] as String? ?? 'active',
      stops: stops,
    );
  }

  RouteStopEntity _stopFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RouteStopEntity(
      id: doc.id,
      customerName: d['customerName'] as String? ?? 'Customer',
      address: d['address'] as String? ?? '',
      binType: d['binType'] as String? ?? 'general',
      status: d['status'] as String? ?? 'pending',
      estimatedWeightKg: (d['estimatedWeightKg'] as num?)?.toDouble() ?? 15.0,
      actualWeightKg: (d['actualWeightKg'] as num?)?.toDouble(),
      notes: d['notes'] as String?,
      latitude: (d['latitude'] as num?)?.toDouble() ?? 5.6037,
      longitude: (d['longitude'] as num?)?.toDouble() ?? -0.1870,
      stopOrder: (d['stopOrder'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<RouteStopEntity> markStopCollected({
    required String stopId,
    required double weightKg,
    String? photoPath,
    String? qrCodeData,
    String? notes,
  }) async {
    final route = await getActiveRoute();
    if (route != null) {
      final stopRef = _routesRef.doc(route.id).collection('stops').doc(stopId);
      await stopRef.update({
        'status': 'collected',
        'actualWeightKg': weightKg,
        if (notes != null) 'notes': notes,
        'collectedAt': FieldValue.serverTimestamp(),
      });

      // Find stop details to add to global collections log
      final stopDoc = await stopRef.get();
      final stopData = stopDoc.data() as Map<String, dynamic>? ?? {};

      final riderProfile = await getRiderProfile();
      final carbonOffset = weightKg * 0.52; // standard CO2 calculation factor

      await _collectionsRef.add({
        'riderId': _uid,
        'riderName': riderProfile.fullName,
        'customerName': stopData['customerName'] ?? 'Customer',
        'address': stopData['address'] ?? '',
        'binType': stopData['binType'] ?? 'general',
        'weightKg': weightKg,
        'carbonOffset': double.parse(carbonOffset.toStringAsFixed(1)),
        'qrVerified': qrCodeData != null && qrCodeData.isNotEmpty,
        'status': 'completed',
        'routeId': route.id,
        'collectedAt': FieldValue.serverTimestamp(),
      });

      // Update rider stats atomically
      await _riderRef.set({
        'totalCollections': FieldValue.increment(1),
        'totalWeightKg': FieldValue.increment(weightKg),
        'earningsThisMonth': FieldValue.increment(weightKg * 0.15),
      }, SetOptions(merge: true));
    }

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
    final route = await getActiveRoute();
    if (route != null) {
      await _routesRef.doc(route.id).collection('stops').doc(stopId).update({
        'status': 'problem',
        'notes': notes ?? reason,
      });
    }
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
    await _routesRef.doc(routeId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Collection History ────────────────────────────────────────────────────

  @override
  Stream<List<CollectionLogEntity>> watchCollectionHistory() {
    return _collectionsRef
        .where('riderId', isEqualTo: _uid)
        .orderBy('collectedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_collectionFromDoc).toList());
  }

  @override
  Future<List<CollectionLogEntity>> getCollectionHistory() async {
    final snap = await _collectionsRef
        .where('riderId', isEqualTo: _uid)
        .orderBy('collectedAt', descending: true)
        .get();
    return snap.docs.map(_collectionFromDoc).toList();
  }

  CollectionLogEntity _collectionFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CollectionLogEntity(
      id: doc.id,
      customerName: d['customerName'] as String? ?? 'Customer',
      address: d['address'] as String? ?? '',
      binType: d['binType'] as String? ?? 'general',
      weightKg: (d['weightKg'] as num?)?.toDouble() ?? 0.0,
      collectedAt: d['collectedAt'] is Timestamp
          ? (d['collectedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: d['status'] as String? ?? 'verified',
      notes: d['notes'] as String?,
      qrCodeData: d['qrVerified'] == true ? 'QR-VERIFIED' : null,
    );
  }

  // ── Performance Stats ─────────────────────────────────────────────────────

  @override
  Stream<RiderPerformanceEntity> watchPerformanceStats() {
    return _riderRef.snapshots().map((doc) => _performanceFromDoc(doc));
  }

  @override
  Future<RiderPerformanceEntity> getPerformanceStats() async {
    final doc = await _riderRef.get();
    return _performanceFromDoc(doc);
  }

  RiderPerformanceEntity _performanceFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RiderPerformanceEntity(
      efficiencyScore: (d['efficiencyScore'] as num?)?.toDouble() ?? 94.2,
      averageRating: (d['rating'] as num?)?.toDouble() ?? 4.8,
      collectionsThisWeek: (d['totalCollections'] as num?)?.toInt() ?? 28,
      weightThisWeek: (d['totalWeightKg'] as num?)?.toDouble() ?? 412.6,
      earningsThisWeek: 287.50,
      earningsThisMonth: (d['earningsThisMonth'] as num?)?.toDouble() ?? 1248.50,
      totalCollectionsAllTime: (d['totalCollections'] as num?)?.toInt() ?? 312,
      onTimeDeliveryRate: 0.982,
      weeklyScores: const [88.0, 91.5, 92.0, 94.2, 93.8, 95.1, 94.2],
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  @override
  Stream<List<RiderNotificationEntity>> watchNotifications() {
    return _notificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_notificationFromDoc).toList());
  }

  @override
  Future<List<RiderNotificationEntity>> getNotifications() async {
    final snap =
        await _notificationsRef.orderBy('createdAt', descending: true).get();
    return snap.docs.map(_notificationFromDoc).toList();
  }

  RiderNotificationEntity _notificationFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RiderNotificationEntity(
      id: doc.id,
      title: d['title'] as String? ?? 'Notification',
      message: d['message'] as String? ?? '',
      type: d['type'] as String? ?? 'system',
      receivedAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: d['isRead'] as bool? ?? false,
    );
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final unread =
        await _notificationsRef.where('isRead', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Available Pickup Requests ──────────────────────────────────────────────

  @override
  Stream<List<PickupRequestEntity>> watchAvailablePickups() {
    // Listen to root pickupRequests collection, filter to 'pending' only
    return _db
        .collection('pickupRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(_pickupFromDoc).toList());
  }

  @override
  Future<void> acceptPickup({
    required String requestId,
    required String customerId,
  }) async {
    final rider = await getRiderProfile();
    final rootRef = _db.collection('pickupRequests').doc(requestId);
    final custRef = _db
        .collection('customers')
        .doc(customerId)
        .collection('pickupRequests')
        .doc(requestId);

    // Broadcasting new requests to every rider means more than one rider can
    // swipe "accept" around the same time — guard the assignment with a
    // transaction so only the first accept actually wins.
    await _db.runTransaction((txn) async {
      final rootSnap = await txn.get(rootRef);
      final rootData = rootSnap.data() ?? {};
      if (rootData['status'] != 'pending') {
        throw Exception('This pickup was already accepted by another rider.');
      }

      final assignment = {
        'status': 'accepted',
        'assignedRiderId': _uid,
        'assignedRiderName': rider.fullName,
        'acceptedAt': FieldValue.serverTimestamp(),
      };

      txn.set(rootRef, assignment, SetOptions(merge: true));
      txn.set(custRef, assignment, SetOptions(merge: true));
      txn.set(
        _db.collection('admin_notifications').doc(),
        {
          'title': 'Pickup Accepted',
          'message': '${rider.fullName} accepted a pickup request.',
          'type': 'pickup_accepted',
          'riderId': _uid,
          'riderName': rider.fullName,
          'requestId': requestId,
          'customerId': customerId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  @override
  Stream<PickupRequestEntity?> watchPickupById(String requestId) {
    return _db
        .collection('pickupRequests')
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists ? _pickupFromDoc(doc) : null);
  }

  @override
  Future<void> updateFcmToken(String token) async {
    await _riderRef.set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> rejectPickup({
    required String requestId,
    required String customerId,
  }) async {
    // Track that this rider rejected the request (array so multiple riders can reject)
    await _db.collection('pickupRequests').doc(requestId).set(
      {
        'rejectedBy': FieldValue.arrayUnion([_uid]),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> completePickup({
    required String requestId,
    required String customerId,
    required double weightKg,
    String? notes,
  }) async {
    final rootRef = _db.collection('pickupRequests').doc(requestId);
    final custPickupRef = _db
        .collection('customers')
        .doc(customerId)
        .collection('pickupRequests')
        .doc(requestId);
    final custRef = _db.collection('customers').doc(customerId);

    final rootSnap = await rootRef.get();
    final rootData = rootSnap.data() ?? {};
    final custSnap = await custRef.get();
    final custData = custSnap.data() ?? {};

    final riderProfile = await getRiderProfile();
    final carbonOffset = weightKg * 0.52;

    final completion = {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'actualWeightKg': weightKg,
      if (notes != null && notes.isNotEmpty) 'completionNotes': notes,
    };

    // Only clear the customer's "next pickup" banner if this job is the one
    // it's currently showing — an older job finishing late shouldn't wipe
    // out a newer pickup the customer has since scheduled.
    final storedNext = custData['nextPickupDate'];
    final requestDate = rootData['date'];
    final matchesNext = storedNext is Timestamp &&
        requestDate is Timestamp &&
        storedNext.seconds == requestDate.seconds;

    final batch = _db.batch();
    batch.set(rootRef, completion, SetOptions(merge: true));
    batch.set(custPickupRef, completion, SetOptions(merge: true));
    batch.set(
      custRef,
      {
        'lastPickupCompletedAt': FieldValue.serverTimestamp(),
        'activeRequestsCount': FieldValue.increment(-1),
        if (matchesNext) 'nextPickupDate': FieldValue.delete(),
        if (matchesNext) 'nextPickupTimeSlot': FieldValue.delete(),
        if (matchesNext) 'nextPickupBinTypes': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_collectionsRef.doc(), {
      'riderId': _uid,
      'riderName': riderProfile.fullName,
      'customerId': customerId,
      'customerName':
          rootData['customerName'] ?? custData['fullName'] ?? 'Customer',
      'address': rootData['location'] as String? ?? '',
      'binType': (rootData['binTypes'] as List<dynamic>?)?.join(', ') ??
          'general',
      'weightKg': weightKg,
      'carbonOffset': double.parse(carbonOffset.toStringAsFixed(1)),
      'status': 'verified',
      'requestId': requestId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'collectedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _riderRef,
      {
        'totalCollections': FieldValue.increment(1),
        'totalWeightKg': FieldValue.increment(weightKg),
        'earningsThisMonth': FieldValue.increment(weightKg * 0.15),
      },
      SetOptions(merge: true),
    );
    batch.set(_db.collection('admin_notifications').doc(), {
      'title': 'Pickup Completed',
      'message':
          '${riderProfile.fullName} completed the pickup for ${rootData['customerName'] ?? 'a customer'}.',
      'type': 'pickup_completed',
      'riderId': _uid,
      'riderName': riderProfile.fullName,
      'requestId': requestId,
      'customerId': customerId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  PickupRequestEntity _pickupFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PickupRequestEntity(
      id: doc.id,
      customerId: d['customerId'] as String? ?? '',
      customerName: d['customerName'] as String? ?? 'Customer',
      customerEmail: d['customerEmail'] as String? ?? '',
      customerPhone: d['customerPhone'] as String? ?? '',
      location: d['location'] as String? ?? d['address'] as String? ?? 'Unknown location',
      timeSlot: d['timeSlot'] as String? ?? '',
      binTypes: (d['binTypes'] as List<dynamic>?)?.cast<String>() ??
          (d['binType'] != null ? [d['binType'] as String] : ['general']),
      status: d['status'] as String? ?? 'pending',
      assignedRiderId: d['assignedRiderId'] as String?,
      assignedRiderName: d['assignedRiderName'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<void> updateRiderLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    String? currentJobId,
  }) async {
    final batch = _db.batch();
    final riderProfile = await getRiderProfile();

    // 1. Update rider document in riders collection
    batch.set(
      _riderRef,
      {
        'id': _uid,
        'fullName': riderProfile.fullName,
        'currentLat': latitude,
        'currentLng': longitude,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading ?? 0.0,
        'speed': speed ?? 0.0,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 2. If rider is currently fulfilling a specific pickup request, mirror coordinates on that job
    if (currentJobId != null && currentJobId.isNotEmpty) {
      batch.set(
        _db.collection('pickupRequests').doc(currentJobId),
        {
          'riderLat': latitude,
          'riderLng': longitude,
          'riderHeading': heading ?? 0.0,
          'riderSpeed': speed ?? 0.0,
          'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  // ── Incident Reports (waste dumps / choked gutters) ──────────────────────

  @override
  Stream<List<IncidentReportEntity>> watchAssignedIncidentReports() {
    return _db
        .collection('incidentReports')
        .where('assignedRiderId', isEqualTo: _uid)
        .snapshots()
        .map((snap) => snap.docs.map(_incidentReportFromDoc).toList());
  }

  @override
  Future<void> updateIncidentReportStatus({
    required String reportId,
    required String reporterId,
    required String status,
  }) async {
    final update = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(
      _db.collection('incidentReports').doc(reportId),
      update,
      SetOptions(merge: true),
    );
    batch.set(
      _db
          .collection('customers')
          .doc(reporterId)
          .collection('incidentReports')
          .doc(reportId),
      update,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  IncidentReportEntity _incidentReportFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return IncidentReportEntity(
      id: doc.id,
      reporterId: d['reporterId'] as String? ?? '',
      reporterName: d['reporterName'] as String? ?? 'Customer',
      reporterPhone: d['reporterPhone'] as String? ?? '',
      description: d['description'] as String? ?? '',
      mediaUrl: d['mediaUrl'] as String?,
      mediaType: d['mediaType'] as String?,
      location: d['location'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      assignedRiderId: d['assignedRiderId'] as String?,
      assignedRiderName: d['assignedRiderName'] as String?,
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
