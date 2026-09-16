import 'work_type.dart';

/// The immutable, officially-saved baseline produced by the calculation engine.
class Calculation {
  final String id;
  final String taskId;
  final String workTypeId;
  final Map<String, dynamic> inputs; // exact inputs used (snapshot)
  final Map<String, dynamic> outputs; // computed outputs e.g. {"area": 900, "litres": 0.9}
  final double expectedAmount; // official worker payment baseline - never overwritten
  final double resourceCost; // materials/resources only; never used for worker payment
  final String formulaLabel;
  final String createdBy;
  final DateTime createdAt;

  const Calculation({
    required this.id,
    required this.taskId,
    required this.workTypeId,
    this.inputs = const {},
    this.outputs = const {},
    required this.expectedAmount,
    this.resourceCost = 0,
    required this.formulaLabel,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'workTypeId': workTypeId,
        'inputs': inputs,
        'outputs': outputs,
        'expectedAmount': expectedAmount,
        'resourceCost': resourceCost,
        'formulaLabel': formulaLabel,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Calculation.fromMap(Map<String, dynamic> m) => Calculation(
        id: m['id'] as String,
        taskId: m['taskId'] as String,
        workTypeId: m['workTypeId'] as String,
        inputs: Map<String, dynamic>.from(m['inputs'] as Map? ?? {}),
        outputs: Map<String, dynamic>.from(m['outputs'] as Map? ?? {}),
        expectedAmount: (m['expectedAmount'] as num).toDouble(),
        resourceCost: (m['resourceCost'] as num?)?.toDouble() ?? 0,
        formulaLabel: m['formulaLabel'] as String? ?? '',
        createdBy: m['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  WorkTypeField? fieldByKey(WorkType workType, String key) {
    for (final f in workType.fields) {
      if (f.key == key) return f;
    }
    return null;
  }
}