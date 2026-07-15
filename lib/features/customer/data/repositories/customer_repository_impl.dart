import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_models.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  // In-memory list cache to simulate persistent remote changes
  static final List<BinEntity> _mockBins = [
    BinEntity(
      id: 'bin_1',
      serialNumber: 'BSD-8824-U1',
      type: 'general',
      size: '240L',
      fillLevelPercentage: 0.45,
      scheduleFrequency: 'Weekly',
      pickupDays: const ['Monday', 'Thursday'],
      registeredDate: DateTime.now().subtract(const Duration(days: 30)),
    ),
    BinEntity(
      id: 'bin_2',
      serialNumber: 'BSD-9182-R2',
      type: 'recycling',
      size: '240L',
      fillLevelPercentage: 0.20,
      scheduleFrequency: 'Bi-weekly',
      pickupDays: const ['Wednesday'],
      registeredDate: DateTime.now().subtract(const Duration(days: 20)),
    ),
    BinEntity(
      id: 'bin_3',
      serialNumber: 'BSD-5541-O3',
      type: 'organic',
      size: '120L',
      fillLevelPercentage: 0.10,
      scheduleFrequency: 'Weekly',
      pickupDays: const ['Friday'],
      registeredDate: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  static final List<PickupRequestEntity> _mockRequests = [
    PickupRequestEntity(
      id: 'req_1',
      binTypes: const ['general', 'recycling'],
      date: DateTime.now().add(const Duration(days: 3)),
      timeSlot: '08:00 AM - 12:00 PM',
      location: '123 Green St, Eco City',
      instructions: 'Keep outside gate.',
      status: 'scheduled',
    )
  ];

  static final List<ServiceRecordEntity> _mockRecords = [
    ServiceRecordEntity(
      id: 'rec_1',
      title: 'General & Recycling Collection',
      type: 'collection',
      date: DateTime.now().subtract(const Duration(days: 4)),
      status: 'completed',
      weightKg: 12.5,
      co2OffsetKg: 8.2,
      compositionPercentages: const {
        'Plastics': 45.0,
        'Paper': 35.0,
        'Glass': 20.0,
      },
      amountPaid: 15.00,
      receiptNumber: 'REC-2026-8841',
    ),
    ServiceRecordEntity(
      id: 'rec_2',
      title: 'Monthly Subscription Payment',
      type: 'payment',
      date: DateTime.now().subtract(const Duration(days: 12)),
      status: 'completed',
      amountPaid: 15.00,
      receiptNumber: 'REC-2026-7712',
    ),
    ServiceRecordEntity(
      id: 'rec_3',
      title: 'Organic Waste Collection',
      type: 'collection',
      date: DateTime.now().subtract(const Duration(days: 18)),
      status: 'completed',
      weightKg: 8.4,
      co2OffsetKg: 5.1,
      compositionPercentages: const {
        'Organic': 100.0,
      },
      amountPaid: 0.00,
      receiptNumber: 'REC-2026-6632',
    ),
  ];

  static SubscriptionEntity _mockSubscription = SubscriptionEntity(
    currentPlan: 'Weekly Plan',
    fee: 15.00,
    status: 'active',
    paymentMethod: 'Credit/Debit Card',
    outstandingBalance: 15.00,
    nextPickupDate: DateTime.now().add(const Duration(days: 3)),
  );

  CustomerRepositoryImpl();

  @override
  Future<List<BinEntity>> getBins() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return List.from(_mockBins);
  }

  @override
  Future<BinEntity> registerBin({
    required String type,
    required String size,
    required String serialNumber,
    required String frequency,
    required List<String> pickupDays,
    required String gpsLocation,
    String? photoPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final newBin = BinEntity(
      id: 'bin_${DateTime.now().millisecondsSinceEpoch}',
      serialNumber: serialNumber,
      type: type,
      size: size,
      fillLevelPercentage: 0.0, // newly registered bin starts empty
      scheduleFrequency: frequency,
      pickupDays: pickupDays,
      verificationPhotoUrl: photoPath,
      registeredDate: DateTime.now(),
    );

    _mockBins.add(newBin);
    return newBin;
  }

  @override
  Future<List<PickupRequestEntity>> getPickupRequests() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.from(_mockRequests);
  }

  @override
  Future<PickupRequestEntity> schedulePickup({
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    String? instructions,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final newRequest = PickupRequestEntity(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      binTypes: binTypes,
      date: date,
      timeSlot: timeSlot,
      location: location,
      instructions: instructions,
      status: 'pending',
    );

    _mockRequests.add(newRequest);
    return newRequest;
  }

  @override
  Future<List<ServiceRecordEntity>> getServiceHistory() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.from(_mockRecords);
  }

  @override
  Future<SubscriptionEntity> getSubscription() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockSubscription;
  }

  @override
  Future<SubscriptionEntity> updateSubscription({
    required String newPlan,
    required double fee,
    required String paymentMethod,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    _mockSubscription = SubscriptionEntity(
      currentPlan: newPlan,
      fee: fee,
      status: 'active',
      paymentMethod: paymentMethod,
      outstandingBalance: fee,
      nextPickupDate: DateTime.now().add(const Duration(days: 3)),
    );

    return _mockSubscription;
  }

  @override
  Future<void> payOutstandingBalance() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    _mockSubscription = SubscriptionEntity(
      currentPlan: _mockSubscription.currentPlan,
      fee: _mockSubscription.fee,
      status: _mockSubscription.status,
      paymentMethod: _mockSubscription.paymentMethod,
      outstandingBalance: 0.00,
      nextPickupDate: _mockSubscription.nextPickupDate,
    );

    // Add a receipt payment record to service history
    _mockRecords.insert(
      0,
      ServiceRecordEntity(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Outstanding Balance Payment',
        type: 'payment',
        date: DateTime.now(),
        status: 'completed',
        amountPaid: 15.00,
        receiptNumber: 'REC-${DateTime.now().year}-${DateTime.now().millisecond}',
      ),
    );
  }

  @override
  Future<void> reportProblem({
    required String category,
    required String description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    // Add a support record to history
    _mockRecords.insert(
      0,
      ServiceRecordEntity(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Support Ticket: $category',
        type: 'support',
        date: DateTime.now(),
        status: 'pending',
        amountPaid: 0.00,
      ),
    );
  }
}
