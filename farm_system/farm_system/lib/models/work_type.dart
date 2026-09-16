import '../core/constants/enums.dart';

/// Describes how a work type is measured and calculated. This is DATA,
/// not code — the actual formula logic lives in the CalculationEngine,
/// keyed by [category]. That separation is what lets the Boss add a new
/// work type (e.g. "Kuchimba Mashimo") from a settings screen later
/// without an app update, as long as its category already exists.
class WorkType {
  final String id;
  final WorkTypeId typeId;
  final String name;
  final CalculationCategory category;
  final String unitLabel; // e.g. "m²", "kg", "litres"
  final bool isBuiltIn;

  const WorkType({
    required this.id,
    required this.typeId,
    required this.name,
    required this.category,
    required this.unitLabel,
    this.isBuiltIn = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'typeId': typeId.name,
        'name': name,
        'category': category.name,
        'unitLabel': unitLabel,
        'isBuiltIn': isBuiltIn,
      };

  factory WorkType.fromMap(Map map) => WorkType(
        id: map['id'] as String,
        typeId: WorkTypeId.values.byName(map['typeId'] as String),
        name: map['name'] as String,
        category: CalculationCategory.values.byName(map['category'] as String),
        unitLabel: map['unitLabel'] as String,
        isBuiltIn: map['isBuiltIn'] as bool? ?? true,
      );

  /// The built-in catalogue described in the spec. Seeded once on first run.
  static List<WorkType> builtIns() => [
        const WorkType(
          id: 'wt_kupalilia',
          typeId: WorkTypeId.kupalilia,
          name: 'Kupalilia',
          category: CalculationCategory.areaFixedPayment,
          unitLabel: 'm²',
        ),
        const WorkType(
          id: 'wt_kupiga_dawa',
          typeId: WorkTypeId.kupigaDawa,
          name: 'Kupiga Dawa',
          category: CalculationCategory.sprayingChemical,
          unitLabel: 'm²',
        ),
        const WorkType(
          id: 'wt_kupanda',
          typeId: WorkTypeId.kupanda,
          name: 'Kupanda',
          category: CalculationCategory.areaFixedPayment,
          unitLabel: 'm²',
        ),
        const WorkType(
          id: 'wt_kuvuna',
          typeId: WorkTypeId.kuvuna,
          name: 'Kuvuna',
          category: CalculationCategory.quantityWithRate,
          unitLabel: 'kg',
        ),
        const WorkType(
          id: 'wt_mbolea',
          typeId: WorkTypeId.mbolea,
          name: 'Mbolea',
          category: CalculationCategory.areaFixedPayment,
          unitLabel: 'm²',
        ),
        const WorkType(
          id: 'wt_custom',
          typeId: WorkTypeId.custom,
          name: 'Other / Custom',
          category: CalculationCategory.customFormula,
          unitLabel: 'unit',
          isBuiltIn: false,
        ),
      ];
}
