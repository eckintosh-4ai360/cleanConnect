class PickupRequestEntity {
  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String location;
  final String timeSlot;
  final List<String> binTypes;
  final String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final String? assignedRiderId;
  final String? assignedRiderName;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const PickupRequestEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.location,
    required this.timeSlot,
    required this.binTypes,
    required this.status,
    this.assignedRiderId,
    this.assignedRiderName,
    required this.createdAt,
    this.acceptedAt,
  });
}
