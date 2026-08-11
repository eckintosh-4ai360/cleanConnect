class IncidentReportEntity {
  final String id;
  final String reporterName;
  final String reporterPhone;
  final String description;
  final String? mediaUrl;
  final String? mediaType; // 'photo', 'video'
  final String location;
  final String status; // 'pending', 'assigned', 'in_progress', 'resolved'
  final String? assignedRiderId;
  final String? assignedRiderName;
  final DateTime createdAt;

  const IncidentReportEntity({
    required this.id,
    required this.reporterName,
    required this.reporterPhone,
    required this.description,
    this.mediaUrl,
    this.mediaType,
    required this.location,
    required this.status,
    this.assignedRiderId,
    this.assignedRiderName,
    required this.createdAt,
  });
}
