import 'enums.dart';

class WorkProgress {
  final String id;
  final String workZoneId;
  final double assignedSquareMeters;
  final double completedSquareMeters;
  final ProgressStatus status;
  final String? workerId;
  final String? evidenceNote;
  final DateTime recordedAt;
  final String recordedBy;

  const WorkProgress({
    required this.id,
    required this.workZoneId,
    required this.assignedSquareMeters,
    required this.completedSquareMeters,
    required this.status,
    this.workerId,
    this.evidenceNote,
    required this.recordedAt,
    required this.recordedBy,
  });

  double get remainingSquareMeters => assignedSquareMeters - completedSquareMeters;

  Map<String, dynamic> toMap() => {
        'id': id,
        'workZoneId': workZoneId,
        'assignedSquareMeters': assignedSquareMeters,
        'completedSquareMeters': completedSquareMeters,
        'status': status.index,
        'workerId': workerId,
        'evidenceNote': evidenceNote,
        'recordedAt': recordedAt.toIso8601String(),
        'recordedBy': recordedBy,
      };

  factory WorkProgress.fromMap(Map<String, dynamic> m) => WorkProgress(
        id: m['id'] as String,
        workZoneId: m['workZoneId'] as String,
        assignedSquareMeters: (m['assignedSquareMeters'] as num).toDouble(),
        completedSquareMeters: (m['completedSquareMeters'] as num).toDouble(),
        status: ProgressStatus.values[m['status'] as int? ?? ProgressStatus.notStarted.index],
        workerId: m['workerId'] as String?,
        evidenceNote: m['evidenceNote'] as String?,
        recordedAt: DateTime.parse(m['recordedAt'] as String),
        recordedBy: m['recordedBy'] as String? ?? '',
      );
}
