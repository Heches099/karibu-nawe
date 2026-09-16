enum MeasurementSyncStatus { queued, syncing, synced, failed }

enum MeasurementStatus { draft, completed, archived }

class SurveyPoint {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;

  const SurveyPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory SurveyPoint.fromMap(Map<String, dynamic> map) => SurveyPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble() ?? 0,
        recordedAt: DateTime.parse(map['recordedAt'] as String),
      );
}

class AreaMeasurement {
  final String id;
  final String? taskId;
  final String measuredBy;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<SurveyPoint> points;
  final List<SurveyPoint> smoothedPoints;
  final double areaM2;
  final double perimeterM;
  final double averageAccuracyMeters;
  final String sensorInfo;
  final MeasurementStatus status;
  final MeasurementSyncStatus syncStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AreaMeasurement({
    required this.id,
    this.taskId,
    required this.measuredBy,
    required this.startedAt,
    this.finishedAt,
    this.points = const [],
    this.smoothedPoints = const [],
    required this.areaM2,
    required this.perimeterM,
    required this.averageAccuracyMeters,
    required this.sensorInfo,
    this.status = MeasurementStatus.completed,
    this.syncStatus = MeasurementSyncStatus.queued,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get hectares => areaM2 / 10000;
  double get acres => areaM2 / 4046.8564224;
  int get durationSeconds => (finishedAt ?? updatedAt).difference(startedAt).inSeconds;

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'measuredBy': measuredBy,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'points': points.map((point) => point.toMap()).toList(),
        'smoothedPoints': smoothedPoints.map((point) => point.toMap()).toList(),
        'areaM2': areaM2,
        'perimeterM': perimeterM,
        'averageAccuracyMeters': averageAccuracyMeters,
        'sensorInfo': sensorInfo,
        'status': status.index,
        'syncStatus': syncStatus.index,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AreaMeasurement.fromMap(Map<String, dynamic> map) => AreaMeasurement(
        id: map['id'] as String,
        taskId: map['taskId'] as String?,
        measuredBy: map['measuredBy'] as String? ?? '',
        startedAt: DateTime.parse(map['startedAt'] as String),
        finishedAt: (map['finishedAt'] as String?) == null ? null : DateTime.parse(map['finishedAt'] as String),
        points: _points(map['points']),
        smoothedPoints: _points(map['smoothedPoints']),
        areaM2: (map['areaM2'] as num).toDouble(),
        perimeterM: (map['perimeterM'] as num).toDouble(),
        averageAccuracyMeters: (map['averageAccuracyMeters'] as num?)?.toDouble() ?? 0,
        sensorInfo: map['sensorInfo'] as String? ?? 'Unavailable',
        status: MeasurementStatus.values[map['status'] as int? ?? MeasurementStatus.completed.index],
        syncStatus: MeasurementSyncStatus.values[map['syncStatus'] as int? ?? MeasurementSyncStatus.queued.index],
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );

  static List<SurveyPoint> _points(dynamic raw) => (raw as List<dynamic>? ?? const [])
      .map((point) => SurveyPoint.fromMap(Map<String, dynamic>.from(point as Map)))
      .toList();
}
