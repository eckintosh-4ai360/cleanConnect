import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/entities/incident_report_entity.dart';
import '../../domain/repositories/customer_repository.dart';

/// Firestore-backed implementation of [CustomerRepository].
/// All data is scoped to the currently authenticated user's UID.
class CustomerRepositoryImpl implements CustomerRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Random _random = Random();

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _binsRef =>
      _db.collection('customers').doc(_uid).collection('bins');

  CollectionReference get _requestsRef =>
      _db.collection('customers').doc(_uid).collection('pickupRequests');

  CollectionReference get _binRequestsRef =>
      _db.collection('customers').doc(_uid).collection('binRequests');

  CollectionReference get _historyRef =>
      _db.collection('customers').doc(_uid).collection('serviceHistory');

  CollectionReference get _incidentReportsRef =>
      _db.collection('customers').doc(_uid).collection('incidentReports');

  DocumentReference get _customerRef => _db.collection('customers').doc(_uid);

  // ── Bins

  @override
  Stream<List<BinEntity>> watchBins() {
    return _binsRef
        .orderBy('registeredAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(_binFromDoc).toList());
  }

  @override
  Future<List<BinEntity>> getBins() async {
    final snap = await _binsRef
        .orderBy('registeredAt', descending: false)
        .get();
    return snap.docs.map(_binFromDoc).toList();
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
    final serialNumber = _generatePersonalBinSerial();
    final custDoc = await _customerRef.get();
    final custData = custDoc.data() as Map<String, dynamic>? ?? {};
    final name =
        _auth.currentUser?.displayName ??
        custData['displayName'] ??
        custData['fullName'] ??
        'Customer';

    final data = {
      'serialNumber': serialNumber,
      'type': type,
      'size': size,
      'ownership': 'personal',
      'status': 'active',
      'fillLevelPercentage': 0.0,
      'scheduleFrequency': frequency,
      'pickupDays': pickupDays,
      'gpsLocation': gpsLocation,
      'verificationPhotoUrl': photoPath,
      'customerId': _uid,
      'customerName': name,
      'registeredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final docRef = await _binsRef.add(data);

    // Upsert customer profile document in 'customers' collection so Admin Panel sees it
    try {
      final email = _auth.currentUser?.email ?? custData['email'] ?? '';

      await _customerRef.set({
        'displayName': name,
        'fullName': name,
        'email': email,
        'phoneNumber':
            custData['phoneNumber'] ?? _auth.currentUser?.phoneNumber ?? '',
        'contractType': 'Residential',
        'subscriptionPlan': '$frequency Plan',
        'subscriptionFee': 50.0,
        'subscriptionStatus': 'active',
        'paymentMethod': 'Mobile Money',
        'outstandingBalance': 0.0,
        'registeredBinsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': custData['createdAt'] ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Push real-time notification to admin_notifications
      await _db.collection('admin_notifications').add({
        'title': 'New Bin Registered',
        'message': '$name registered a $size $type bin.',
        'type': 'bin_registered',
        'customerId': _uid,
        'customerName': name,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return BinEntity(
      id: docRef.id,
      serialNumber: serialNumber,
      type: type,
      size: size,
      fillLevelPercentage: 0.0,
      scheduleFrequency: frequency,
      pickupDays: pickupDays,
      verificationPhotoUrl: photoPath,
      registeredDate: DateTime.now(),
    );
  }

  @override
  Future<void> requestCompanyBin({
    required String type,
    required String size,
    required String gpsLocation,
  }) async {
    final custDoc = await _customerRef.get();
    final custData = custDoc.data() as Map<String, dynamic>? ?? {};
    final name =
        _auth.currentUser?.displayName ??
        custData['displayName'] ??
        custData['fullName'] ??
        'Customer';
    final email = _auth.currentUser?.email ?? custData['email'] ?? '';

    final data = {
      'type': type,
      'size': size,
      'gpsLocation': gpsLocation,
      'status': 'pending',
      'requestType': 'company_bin',
      'customerId': _uid,
      'customerName': name,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final requestRef = await _binRequestsRef.add(data);

    await _customerRef.set({
      'displayName': name,
      'fullName': name,
      'email': email,
      'phoneNumber':
          custData['phoneNumber'] ?? _auth.currentUser?.phoneNumber ?? '',
      'pendingBinRequestsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': custData['createdAt'] ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('admin_notifications').add({
      'title': 'New Bin Requested',
      'message':
          '$name requested a company-owned $size $type bin. Admin should assign a bin with a serial number.',
      'type': 'bin_requested',
      'customerId': _uid,
      'customerName': name,
      'requestId': requestRef.id,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _generatePersonalBinSerial() {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final suffix = 1000 + _random.nextInt(9000);
    return 'PB-${timestamp.toRadixString(36).toUpperCase()}-$suffix';
  }

  BinEntity _binFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BinEntity(
      id: doc.id,
      serialNumber: d['serialNumber'] as String? ?? '',
      type: d['type'] as String? ?? 'general',
      size: d['size'] as String? ?? '240L',
      fillLevelPercentage:
          (d['fillLevelPercentage'] as num?)?.toDouble() ?? 0.0,
      scheduleFrequency: d['scheduleFrequency'] as String?,
      pickupDays: (d['pickupDays'] as List<dynamic>?)?.cast<String>(),
      gpsLocation: d['gpsLocation'] as String?,
      verificationPhotoUrl: d['verificationPhotoUrl'] as String?,
      registeredDate: d['registeredAt'] is Timestamp
          ? (d['registeredAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ── Pickup Requests ───────────────────────────────────────────────────────

  @override
  Stream<List<PickupRequestEntity>> watchPickupRequests() {
    return _requestsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_requestFromDoc).toList());
  }

  @override
  Future<List<PickupRequestEntity>> getPickupRequests() async {
    final snap = await _requestsRef
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(_requestFromDoc).toList();
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
  }) async {
    final custDoc = await _customerRef.get();
    final custData = custDoc.data() as Map<String, dynamic>? ?? {};
    final name =
        _auth.currentUser?.displayName ??
        custData['displayName'] ??
        custData['fullName'] ??
        'Customer';
    final email = _auth.currentUser?.email ?? custData['email'] ?? '';

    final data = {
      'binTypes': binTypes,
      'date': Timestamp.fromDate(date),
      'timeSlot': timeSlot,
      'location': location,
      'instructions': instructions,
      'status': 'pending',
      'paymentStatus': 'paid',
      'amountPaid': amountPaid,
      'originalAmount': originalAmount > 0 ? originalAmount : amountPaid,
      'discountAppliedPercentage': discountAppliedPercentage,
      'surchargeAppliedPercentage': surchargeAppliedPercentage,
      'paymentMethod': paymentMethod,
      'paidAt': FieldValue.serverTimestamp(),
      'customerId': _uid,
      'customerName': name,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final docRef = await _requestsRef.add(data);

    try {
      // 1. Also add to root 'pickupRequests' collection for Admin Panel overview
      await _db.collection('pickupRequests').doc(docRef.id).set({
        ...data,
        'id': docRef.id,
      });

      await _historyRef.add({
        'title': discountAppliedPercentage > 0
            ? 'Pickup Payment (${discountAppliedPercentage.toInt()}% Delay Bonus Applied)'
            : 'Pickup Request Payment',
        'type': 'payment',
        'date': FieldValue.serverTimestamp(),
        'status': 'completed',
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'receiptNumber':
            'PU-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 100000}',
        'pickupRequestId': docRef.id,
      });

      // 2. Upsert customer profile in 'customers' collection & reset delay bonus if used
      await _customerRef.set({
        'displayName': name,
        'fullName': name,
        'email': email,
        'phoneNumber':
            custData['phoneNumber'] ?? _auth.currentUser?.phoneNumber ?? '',
        'contractType': 'Residential',
        'subscriptionPlan': 'Weekly Plan',
        'subscriptionFee': 50.0,
        'subscriptionStatus': 'active',
        'paymentMethod': paymentMethod,
        'activeRequestsCount': FieldValue.increment(1),
        'lastPickupRequestDate': FieldValue.serverTimestamp(),
        if (discountAppliedPercentage > 0) 'delayBonusRedeemedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': custData['createdAt'] ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Add real-time notification to admin_notifications
      await _db.collection('admin_notifications').add({
        'title': 'Pickup Requested',
        'message':
            '$name paid GHS ${amountPaid.toStringAsFixed(2)}${discountAppliedPercentage > 0 ? " (with ${discountAppliedPercentage.toInt()}% Delay Bonus)" : ""} and requested pickup for ${binTypes.join(", ")} ($timeSlot at $location).',
        'type': 'pickup_requested',
        'customerId': _uid,
        'customerName': name,
        'requestId': docRef.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return PickupRequestEntity(
      id: docRef.id,
      binTypes: binTypes,
      date: date,
      timeSlot: timeSlot,
      location: location,
      instructions: instructions,
      status: 'pending',
      amountPaid: amountPaid,
      originalAmount: originalAmount > 0 ? originalAmount : amountPaid,
      discountAppliedPercentage: discountAppliedPercentage,
      surchargeAppliedPercentage: surchargeAppliedPercentage,
    );
  }

  PickupRequestEntity _requestFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PickupRequestEntity(
      id: doc.id,
      binTypes: (d['binTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      date: d['date'] is Timestamp
          ? (d['date'] as Timestamp).toDate()
          : DateTime.now(),
      timeSlot: d['timeSlot'] as String? ?? '',
      location: d['location'] as String? ?? '',
      instructions: d['instructions'] as String?,
      status: d['status'] as String? ?? 'pending',
      amountPaid: (d['amountPaid'] as num?)?.toDouble() ?? 0.0,
      originalAmount: (d['originalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAppliedPercentage:
          (d['discountAppliedPercentage'] as num?)?.toDouble() ?? 0.0,
      surchargeAppliedPercentage:
          (d['surchargeAppliedPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ── Service History ───────────────────────────────────────────────────────

  @override
  Stream<List<ServiceRecordEntity>> watchServiceHistory() {
    return _historyRef
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_recordFromDoc).toList());
  }

  @override
  Future<List<ServiceRecordEntity>> getServiceHistory() async {
    final snap = await _historyRef.orderBy('date', descending: true).get();
    return snap.docs.map(_recordFromDoc).toList();
  }

  ServiceRecordEntity _recordFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceRecordEntity(
      id: doc.id,
      title: d['title'] as String? ?? 'Service Record',
      type: d['type'] as String? ?? 'collection',
      date: d['date'] is Timestamp
          ? (d['date'] as Timestamp).toDate()
          : DateTime.now(),
      status: d['status'] as String? ?? 'completed',
      weightKg: (d['weightKg'] as num?)?.toDouble(),
      co2OffsetKg: (d['co2OffsetKg'] as num?)?.toDouble(),
      compositionPercentages: d['compositionPercentages'] != null
          ? Map<String, double>.from(
              (d['compositionPercentages'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ),
            )
          : null,
      amountPaid: (d['amountPaid'] as num?)?.toDouble() ?? 0.0,
      receiptNumber: d['receiptNumber'] as String?,
      paymentMethod: d['paymentMethod'] as String?,
    );
  }

  // ── Subscription ─────────────────────────────────────────────────────────

  @override
  Stream<SubscriptionEntity> watchSubscription() {
    return _customerRef.snapshots().map((doc) {
      if (!doc.exists) return _defaultSubscription();
      return _subscriptionFromDoc(doc);
    });
  }

  @override
  Future<SubscriptionEntity> getSubscription() async {
    final doc = await _customerRef.get();
    if (!doc.exists) return _defaultSubscription();
    return _subscriptionFromDoc(doc);
  }

  SubscriptionEntity _subscriptionFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SubscriptionEntity(
      currentPlan: d['subscriptionPlan'] as String? ?? 'Weekly Plan',
      fee: (d['subscriptionFee'] as num?)?.toDouble() ?? 0.0,
      status: d['subscriptionStatus'] as String? ?? 'active',
      paymentMethod: d['paymentMethod'] as String? ?? 'Mobile Money',
      outstandingBalance: (d['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
      nextPickupDate: d['nextPickupDate'] is Timestamp
          ? (d['nextPickupDate'] as Timestamp).toDate()
          : null,
      delayBonusAvailable: d['delayBonusAvailable'] as bool? ?? false,
      lastPickupCompletedAt: d['lastPickupCompletedAt'] is Timestamp
          ? (d['lastPickupCompletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Stream<List<PricingPlanEntity>> watchPricingPlans() {
    return _db
        .collection('pricingPlans')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              final rawPrices = d['prices'] as Map<String, dynamic>? ?? {};
              final pricesMap = <String, double>{};
              rawPrices.forEach((k, v) {
                pricesMap[k] = (v as num).toDouble();
              });
              return PricingPlanEntity(
                id: doc.id,
                name: d['name'] as String? ?? '',
                frequency: d['frequency'] as String? ?? 'Weekly',
                description: d['description'] as String? ?? '',
                isPayg: d['isPayg'] as bool? ?? false,
                prices: pricesMap,
              );
            }).toList());
  }

  SubscriptionEntity _defaultSubscription() => const SubscriptionEntity(
    currentPlan: 'Weekly Plan',
    fee: 0.0,
    status: 'active',
    paymentMethod: 'Mobile Money',
    outstandingBalance: 0.0,
  );

  @override
  Future<SubscriptionEntity> updateSubscription({
    required String newPlan,
    required double fee,
    required String paymentMethod,
  }) async {
    await _customerRef.set({
      'subscriptionPlan': newPlan,
      'subscriptionFee': fee,
      'paymentMethod': paymentMethod,
      'subscriptionStatus': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return getSubscription();
  }

  @override
  Future<void> payOutstandingBalance() async {
    final current = await getSubscription();
    final amountPaid = current.outstandingBalance;

    // Atomic: zero the balance + add service history record
    final batch = _db.batch();
    batch.set(_customerRef, {
      'outstandingBalance': 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_historyRef.doc(), {
      'title': 'Outstanding Balance Payment',
      'type': 'payment',
      'date': FieldValue.serverTimestamp(),
      'status': 'completed',
      'amountPaid': amountPaid,
      'receiptNumber':
          'REC-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}',
    });
    await batch.commit();
  }

  @override
  Future<void> reportProblem({
    required String category,
    required String description,
  }) async {
    await _historyRef.add({
      'title': 'Support Ticket: $category',
      'type': 'support',
      'date': FieldValue.serverTimestamp(),
      'status': 'pending',
      'amountPaid': 0.0,
      'description': description,
    });
  }

  // ── Incident Reports (waste dumps / choked gutters) ─────────────────────

  @override
  Stream<List<IncidentReportEntity>> watchIncidentReports() {
    return _incidentReportsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_incidentReportFromDoc).toList());
  }

  @override
  Future<IncidentReportEntity> submitIncidentReport({
    required String description,
    required String location,
    Uint8List? mediaBytes,
    String? mediaFileName,
    String? mediaType,
  }) async {
    final custDoc = await _customerRef.get();
    final custData = custDoc.data() as Map<String, dynamic>? ?? {};
    final name =
        _auth.currentUser?.displayName ??
        custData['displayName'] ??
        custData['fullName'] ??
        'Customer';
    final phone =
        custData['phoneNumber'] ?? _auth.currentUser?.phoneNumber ?? '';

    // Root 'incidentReports' collection is the source of truth the Admin
    // Panel reads from, so its id must be generated there.
    final docRef = _db.collection('incidentReports').doc();

    String? mediaUrl;
    if (mediaBytes != null && mediaFileName != null) {
      final ref = _storage
          .ref()
          .child('incident_reports')
          .child(_uid)
          .child(docRef.id)
          .child(mediaFileName);
      final uploadTask = await ref.putData(mediaBytes);
      mediaUrl = await uploadTask.ref.getDownloadURL();
    }

    final data = {
      'reporterId': _uid,
      'reporterName': name,
      'reporterPhone': phone,
      'description': description,
      'location': location,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Write to the Admin-visible root collection first. Let failures here
    // surface to the customer instead of being swallowed — otherwise the
    // customer sees "submitted" while the admin panel never gets the report.
    await docRef.set({...data, 'id': docRef.id});

    try {
      // Best-effort mirror into the customer's own subcollection (used for
      // their "My Reports" view) and an admin notification badge.
      await _incidentReportsRef.doc(docRef.id).set(data);

      await _db.collection('admin_notifications').add({
        'title': 'New Incident Reported',
        'message': '$name reported an issue: $description',
        'type': 'incident_reported',
        'customerId': _uid,
        'customerName': name,
        'requestId': docRef.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return IncidentReportEntity(
      id: docRef.id,
      reporterName: name,
      reporterPhone: phone,
      description: description,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      location: location,
      status: 'pending',
      createdAt: DateTime.now(),
    );
  }

  IncidentReportEntity _incidentReportFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return IncidentReportEntity(
      id: doc.id,
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
