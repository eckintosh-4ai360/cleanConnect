import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/incident_report_entity.dart';
import '../providers/rider_providers.dart';

class AssignedReportsScreen extends ConsumerWidget {
  const AssignedReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(assignedIncidentReportsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Assigned Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: reportsAsync.when(
          data: (reports) {
            final active = reports
                .where((r) => r.status != 'resolved')
                .toList();
            final resolved = reports
                .where((r) => r.status == 'resolved')
                .toList();

            if (reports.isEmpty) {
              return const _EmptyState();
            }

            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(assignedIncidentReportsProvider),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (active.isNotEmpty) ...[
                    const Text(
                      'Active',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ...active.map(
                      (r) => _ReportCard(report: r, ref: ref),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (resolved.isNotEmpty) ...[
                    const Text(
                      'Resolved',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ...resolved.map(
                      (r) => _ReportCard(report: r, ref: ref),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load reports: $e')),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_problem_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No reports assigned to you yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IncidentReportEntity report;
  final WidgetRef ref;

  const _ReportCard({required this.report, required this.ref});

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Assigned';
    }
  }

  Future<void> _openLocation() async {
    final parts = report.location.split(',');
    if (parts.length < 2) return;
    final lat = parts[0].trim();
    final lng = parts[1].split('(').first.trim();
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  report.description,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(report.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (report.mediaUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: report.mediaType == 'video'
                  ? Container(
                      height: 100,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.videocam, size: 32, color: Colors.grey),
                    )
                  : Image.network(
                      report.mediaUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(height: 10),
          ],
          GestureDetector(
            onTap: _openLocation,
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.location,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${report.reporterName}${report.reporterPhone.isNotEmpty ? ' · ${report.reporterPhone}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (report.status != 'resolved') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (report.status != 'in_progress')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(assignedIncidentReportsProvider.notifier)
                          .updateStatus(
                            reportId: report.id,
                            reporterId: report.reporterId,
                            status: 'in_progress',
                          ),
                      child: const Text('Start Work'),
                    ),
                  ),
                if (report.status != 'in_progress') const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(assignedIncidentReportsProvider.notifier)
                        .updateStatus(
                          reportId: report.id,
                          reporterId: report.reporterId,
                          status: 'resolved',
                        ),
                    child: const Text('Mark Resolved'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
