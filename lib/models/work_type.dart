/// Describes an input field shown on the calculator for a particular [WorkType].
class WorkTypeField {
  final String key;
  final String label;
  final String unit;
  final String type; // 'number' or 'money'
  final bool required;
  final String? helpText;

  const WorkTypeField({
    required this.key,
    required this.label,
    this.unit = '',
    this.type = 'number',
    this.required = true,
    this.helpText,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'unit': unit,
        'type': type,
        'required': required,
        'helpText': helpText,
      };

  factory WorkTypeField.fromMap(Map<String, dynamic> m) => WorkTypeField(
        key: m['key'] as String,
        label: m['label'] as String,
        unit: m['unit'] as String? ?? '',
        type: m['type'] as String? ?? 'number',
        required: m['required'] as bool? ?? true,
        helpText: m['helpText'] as String?,
      );
}

class WorkType {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String formulaCode;
  final List<WorkTypeField> fields;
  final int sortOrder;
  final bool isBuiltIn;
  final bool isActive;
  final DateTime createdAt;

  const WorkType({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.formulaCode,
    this.fields = const [],
    this.sortOrder = 0,
    this.isBuiltIn = true,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'formulaCode': formulaCode,
        'fields': fields.map((f) => f.toMap()).toList(),
        'sortOrder': sortOrder,
        'isBuiltIn': isBuiltIn,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkType.fromMap(Map<String, dynamic> m) => WorkType(
        id: m['id'] as String,
        name: m['name'] as String,
        code: m['code'] as String,
        description: m['description'] as String?,
        formulaCode: m['formulaCode'] as String,
        fields: (m['fields'] as List<dynamic>?)
                ?.map((f) => WorkTypeField.fromMap(f as Map<String, dynamic>))
                .toList() ??
            const [],
        sortOrder: m['sortOrder'] as int? ?? 0,
        isBuiltIn: m['isBuiltIn'] as bool? ?? true,
        isActive: m['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  WorkType copyWith({
    String? name,
    String? code,
    String? description,
    String? formulaCode,
    List<WorkTypeField>? fields,
    int? sortOrder,
    bool? isActive,
  }) =>
      WorkType(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        description: description ?? this.description,
        formulaCode: formulaCode ?? this.formulaCode,
        fields: fields ?? this.fields,
        sortOrder: sortOrder ?? this.sortOrder,
        isBuiltIn: isBuiltIn,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  static const List<WorkTypeField> kupalaFields = [
    WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
    WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
    WorkTypeField(key: 'agreedPayment', label: 'Agreed Payment', unit: 'TSh', type: 'money'),
  ];

  static const List<WorkTypeField> kupigaDawaFields = [
    WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
    WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
    WorkTypeField(key: 'coverage', label: 'Coverage', unit: 'm² / L'),
    WorkTypeField(key: 'pricePerLitre', label: 'Price per Litre', unit: 'TSh/L', type: 'money'),
    WorkTypeField(key: 'workerPayment', label: 'Expected Worker Payment', unit: 'TSh', type: 'money'),
  ];

  static const List<WorkTypeField> kupandaFields = [
    WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
    WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
    WorkTypeField(key: 'ratePerUnit', label: 'Rate per m²', unit: 'TSh', type: 'money'),
  ];

  static const List<WorkTypeField> kuvunaFields = [
    WorkTypeField(key: 'harvestedKg', label: 'Harvested', unit: 'kg'),
    WorkTypeField(key: 'pricePerKg', label: 'Price per kg', unit: 'TSh/kg', type: 'money'),
  ];

  static const List<WorkTypeField> kutoamajaniFields = [
    WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
    WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
    WorkTypeField(key: 'bagsUsed', label: 'Bags Used', unit: 'bags'),
    WorkTypeField(key: 'pricePerBag', label: 'Price per Bag', unit: 'TSh/bag', type: 'money'),
  ];

  static const List<WorkTypeField> mboleaFields = [
    WorkTypeField(key: 'bagsUsed', label: 'Bags Used', unit: 'bags'),
    WorkTypeField(key: 'pricePerBag', label: 'Price per Bag', unit: 'TSh/bag', type: 'money'),
  ];

  static const List<WorkTypeField> customFields = [
    WorkTypeField(key: 'quantity', label: 'Quantity', unit: ''),
    WorkTypeField(key: 'unitLabel', label: 'Unit Label', type: 'text', required: false),
    WorkTypeField(key: 'pricePerUnit', label: 'Price per Unit', unit: 'TSh', type: 'money'),
  ];

  static const List<WorkTypeField> customAreaFields = [
    WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
    WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
    WorkTypeField(key: 'ratePerUnit', label: 'Full Work Expected Cost per m²', unit: 'TSh', type: 'money'),
  ];
  
}