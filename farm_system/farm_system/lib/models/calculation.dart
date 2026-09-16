/// The permanent, official record of how a Task's Expected Amount was
/// derived. Once saved this record is the baseline — Rule 2 in the spec:
/// "The Expected Amount must never silently change." If a Boss needs to
/// correct a measurement, a NEW Calculation revision is created; the old
/// one is kept (superseded, not deleted) so history is never destroyed.
class Calculation {
  final String id;
  final String taskId;
  final String workTypeId;

  /// Raw inputs used to produce the result, e.g. {length: 30, width: 30,
  /// agreedPayment: 4000} or {area: 900, coveragePerLitre: 1000,
  /// pricePerLitre: 8000, applications: 1}. Keeping the raw inputs (not
  /// just the final number) is what lets anyone reconstruct/justify the
  /// Expected Amount later.
  final Map<String, dynamic> inputs;

  final double measuredValue; // e.g. 900 (m²) or 120 (kg)
  final String measuredUnit; // e.g. "m²"
  final int expectedAmount; // the official baseline, in TSh

  final bool isSuperseded; // true once a correcting revision exists
  final String? supersededByCalculationId;
  final String? supersedesCalculationId;
  final String? revisionReason;

  final String createdBy;
  final DateTime createdAt;

  const Calculation({
    required this.id,
    required this.taskId,
    required this.workTypeId,
    required this.inputs,
    required this.measuredValue,
    required this.measuredUnit,
    required this.expectedAmount,
    this.isSuperseded = false,
    this.supersededByCalculationId,
    this.supersedesCalculationId,
    this.revisionReason,
    required this.createdBy,
    required this.createdAt,
  });

  Calculation markSuperseded(String byId) => Calculation(
        id: id,
        taskId: taskId,
        workTypeId: workTypeId,
        inputs: inputs,
        measuredValue: measuredValue,
        measuredUnit: measuredUnit,
        expectedAmount: expectedAmount,
        isSuperseded: true,
        supersededByCalculationId: byId,
        supersedesCalculationId: supersedesCalculationId,
        revisionReason: revisionReason,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'workTypeId': workTypeId,
        'inputs': inputs,
        'measuredValue': measuredValue,
        'measuredUnit': measuredUnit,
        'expectedAmount': expectedAmount,
        'isSuperseded': isSuperseded,
        'supersededByCalculationId': supersededByCalculationId,
        'supersedesCalculationId': supersedesCalculationId,
        'revisionReason': revisionReason,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Calculation.fromMap(Map map) => Calculation(
        id: map['id'] as String,
        taskId: map['taskId'] as String,
        workTypeId: map['workTypeId'] as String,
        inputs: Map<String, dynamic>.from(map['inputs'] as Map),
        measuredValue: (map['measuredValue'] as num).toDouble(),
        measuredUnit: map['measuredUnit'] as String,
        expectedAmount: map['expectedAmount'] as int,
        isSuperseded: map['isSuperseded'] as bool? ?? false,
        supersededByCalculationId: map['supersededByCalculationId'] as String?,
        supersedesCalculationId: map['supersedesCalculationId'] as String?,
        revisionReason: map['revisionReason'] as String?,
        createdBy: map['createdBy'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
