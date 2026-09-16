import 'enums.dart';

class WorkZone {
  final String id;
  final String name;
  final String taskId;
  final double areaSquareMeters;
  final List<Map<String, double>> boundary;
  final double? accuracyMeters;
  final WorkZoneStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkZone({
    required this.id,
    required this.name,
    required this.taskId,
    required this.areaSquareMeters,
    this.boundary = const [],
    this.accuracyMeters,
    this.status = WorkZoneStatus.inProgress,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'taskId': taskId,
        'areaSquareMeters': areaSquareMeters,
        'boundary': boundary,
        'accuracyMeters': accuracyMeters,
        'status': status.index,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorkZone.fromMap(Map<String, dynamic> m) => WorkZone(
        id: m['id'] as String,
        name: m['name'] as String,
        taskId: m['taskId'] as String,
        areaSquareMeters: (m['areaSquareMeters'] as num).toDouble(),
        boundary: (m['boundary'] as List<dynamic>? ?? const []).map((point) {
          final p = Map<String, dynamic>.from(point as Map);
          return {
            'latitude': (p['latitude'] as num).toDouble(),
            'longitude': (p['longitude'] as num).toDouble(),
          };
        }).toList(),
        accuracyMeters: (m['accuracyMeters'] as num?)?.toDouble(),
        status: WorkZoneStatus.values[m['status'] as int? ?? WorkZoneStatus.inProgress.index],
        createdBy: m['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}
