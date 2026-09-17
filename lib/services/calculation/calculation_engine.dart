import '../../core/errors/app_exception.dart';
import '../../models/work_type.dart';

/// Output of a successful calculation.
class CalculationResult {
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> outputs;
  final double expectedAmount;
  final double resourceCost;
  final String formulaLabel;

  const CalculationResult({
    required this.inputs,
    required this.outputs,
    required this.expectedAmount,
    this.resourceCost = 0,
    required this.formulaLabel,
  });
}

typedef CalculatorInputs = Map<String, dynamic>;

double _asNum(dynamic v, String field) {
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  if (n == null) {
    throw ValidationException('$field must be a valid number.');
  }
  return n;
}

/// Base contract for every work-type calculation formula.
abstract class CalculationFormula {
  const CalculationFormula();

  String get code;
  String get label;
  List<WorkTypeField> get fields;

  /// Computes outputs + expected amount from a map of input values.
  /// Throws [ValidationException] when inputs are invalid.
  CalculationResult compute(CalculatorInputs rawInputs);

  /// Labels for the computed outputs (for display).
  Map<String, String> get outputLabels;
}

/// [Kupalilia] and similar: Length x Width => Area,
/// expected amount is the fixed agreed payment for the whole measured area.
class AreaFixedFormula extends CalculationFormula {
  @override
  String get code => 'area_fixed';
  @override
  String get label => 'Agreed payment for measured area';
  @override
  List<WorkTypeField> get fields => const [
        WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
        WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
        WorkTypeField(key: 'agreedPayment', label: 'Agreed Payment', unit: 'TSh', type: 'money'),
      ];
  @override
  Map<String, String> get outputLabels => {
        'area': 'Measured Area',
        'agreedPayment': 'Agreed Payment',
        'expectedAmount': 'Expected Amount',
      };

  @override
  CalculationResult compute(CalculatorInputs raw) {
    final length = _asNum(raw['length'], 'Length');
    final width = _asNum(raw['width'], 'Width');
    final agreed = _asNum(raw['agreedPayment'], 'Agreed Payment');
    _requirePositive(length, 'Length');
    _requirePositive(width, 'Width');
    _requireNotNegative(agreed, 'Agreed Payment');
    final area = length * width;
    return CalculationResult(
      inputs: Map.of(raw),
      outputs: {'area': area, 'agreedPayment': agreed},
      expectedAmount: agreed,
      formulaLabel: 'Agreed payment for ${_fmt(area)} m²',
    );
  }
}

/// [Kupanda] and similar: area measured then paid at a fixed rate per unit area.
class AreaRateFormula extends CalculationFormula {
  @override
  String get code => 'area_rate';
  @override
  String get label => 'Rate per unit area';
  @override
  List<WorkTypeField> get fields => const [
        WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
        WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
        WorkTypeField(key: 'ratePerUnit', label: 'Rate per m²', unit: 'TSh', type: 'money'),
      ];
  @override
  Map<String, String> get outputLabels => {
        'area': 'Measured Area',
        'ratePerUnit': 'Rate',
        'expectedAmount': 'Expected Amount',
      };

  @override
  CalculationResult compute(CalculatorInputs raw) {
    final length = _asNum(raw['length'], 'Length');
    final width = _asNum(raw['width'], 'Width');
    final rate = _asNum(raw['ratePerUnit'], 'Rate per m²');
    _requirePositive(length, 'Length');
    _requirePositive(width, 'Width');
    _requireNotNegative(rate, 'Rate');
    final area = length * width;
    final expected = area * rate;
    return CalculationResult(
      inputs: Map.of(raw),
      outputs: {'area': area, 'ratePerUnit': rate},
      expectedAmount: expected,
      formulaLabel: '${_fmt(area)} m² × ${_fmtMoney(rate)}/m²',
    );
  }
}

/// [Kupiga Dawa]: area ÷ coverage per litre = required litres and material
/// cost. Worker payment is entered separately and never derived from litres.
class KupigaDawaFormula extends CalculationFormula {
  @override
  String get code => 'kupiga_dawa';
  @override
  String get label => 'Area ÷ coverage × price per litre';
  @override
  List<WorkTypeField> get fields => const [
        WorkTypeField(key: 'length', label: 'Length', unit: 'm'),
        WorkTypeField(key: 'width', label: 'Width', unit: 'm'),
        WorkTypeField(key: 'coverage', label: 'Coverage', unit: 'm² / L'),
        WorkTypeField(key: 'pricePerLitre', label: 'Price per Litre', unit: 'TSh/L', type: 'money'),
        WorkTypeField(key: 'workerPayment', label: 'Expected Worker Payment', unit: 'TSh', type: 'money'),
      ];
  @override
  Map<String, String> get outputLabels => {
        'area': 'Measured Area',
        'coverage': 'Coverage',
        'litres': 'Required Litres',
        'resourceCost': 'Estimated Chemical Cost',
        'workerPayment': 'Expected Worker Payment',
      };

  @override
  CalculationResult compute(CalculatorInputs raw) {
    final length = _asNum(raw['length'], 'Length');
    final width = _asNum(raw['width'], 'Width');
    final coverage = _asNum(raw['coverage'], 'Coverage');
    final price = _asNum(raw['pricePerLitre'], 'Price per Litre');
    final workerPayment = _asNum(raw['workerPayment'], 'Expected Worker Payment');
    _requirePositive(length, 'Length');
    _requirePositive(width, 'Width');
    _requirePositive(coverage, 'Coverage');
    _requireNotNegative(price, 'Price per Litre');
    _requireNotNegative(workerPayment, 'Expected Worker Payment');
    final area = length * width;
    final litres = area / coverage;
    final resourceCost = litres * price;
    return CalculationResult(
      inputs: Map.of(raw),
      outputs: {
        'area': area,
        'coverage': coverage,
        'litres': litres,
        'resourceCost': resourceCost,
        'workerPayment': workerPayment,
      },
      expectedAmount: workerPayment,
      resourceCost: resourceCost,
      formulaLabel: '${_fmt(area)} m² ÷ ${_fmt(coverage)} m²/L; worker pay ${_fmtMoney(workerPayment)}',
    );
  }
}

/// [Kuvuna]/[Mbolea]/[Custom]: quantity × price per unit.
class QuantityPriceFormula extends CalculationFormula {
  final String quantityKey;
  final String priceKey;

  const QuantityPriceFormula({required this.quantityKey, required this.priceKey});

  @override
  String get code => 'quantity_price';
  @override
  String get label => 'Quantity × Price per Unit';
  @override
  List<WorkTypeField> get fields => [
        WorkTypeField(key: quantityKey, label: _quantityLabel(quantityKey), unit: _quantityUnit(quantityKey)),
        WorkTypeField(key: priceKey, label: _priceLabel(priceKey), unit: 'TSh', type: 'money'),
      ];
  @override
  Map<String, String> get outputLabels => {
        quantityKey: _quantityLabel(quantityKey),
        priceKey: _priceLabel(priceKey),
        'expectedAmount': 'Expected Amount',
      };

  static String _quantityLabel(String key) => switch (key) {
        'harvestedKg' => 'Harvested',
        'bagsUsed' => 'Bags Used',
        'quantity' => 'Quantity',
        _ => 'Quantity',
      };
  static String _quantityUnit(String key) => switch (key) {
        'harvestedKg' => 'kg',
        'bagsUsed' => 'bags',
        _ => '',
      };
  static String _priceLabel(String key) => switch (key) {
        'pricePerKg' => 'Price per kg',
        'pricePerBag' => 'Price per Bag',
        'pricePerUnit' => 'Price per Unit',
        _ => 'Price',
      };

  @override
  CalculationResult compute(CalculatorInputs raw) {
    final activeQuantityKey = raw.containsKey(quantityKey)
        ? quantityKey
        : raw.keys.firstWhere((key) => key != priceKey && !key.toLowerCase().contains('price'));
    final activePriceKey = raw.containsKey(priceKey)
        ? priceKey
        : raw.keys.firstWhere((key) => key.toLowerCase().contains('price'));
    final qty = _asNum(raw[activeQuantityKey], _quantityLabel(activeQuantityKey));
    final price = _asNum(raw[activePriceKey], _priceLabel(activePriceKey));
    _requireNotNegative(qty, _quantityLabel(activeQuantityKey));
    _requireNotNegative(price, _priceLabel(activePriceKey));
    final expected = qty * price;
    return CalculationResult(
      inputs: Map.of(raw),
      outputs: {activeQuantityKey: qty, activePriceKey: price},
      expectedAmount: expected,
      formulaLabel: '${_fmt(qty)} × ${_fmtMoney(price)}',
    );
  }
}

/// Custom work type: quantity and price per unit chosen by the manager.
class CustomFormula extends CalculationFormula {
  @override
  String get code => 'custom';
  @override
  String get label => 'Custom quantity × price';
  @override
  List<WorkTypeField> get fields => const [
        WorkTypeField(key: 'quantity', label: 'Quantity', unit: ''),
        WorkTypeField(key: 'pricePerUnit', label: 'Price per Unit', unit: 'TSh', type: 'money'),
      ];
  @override
  Map<String, String> get outputLabels => {
        'quantity': 'Quantity',
        'pricePerUnit': 'Price per Unit',
        'expectedAmount': 'Expected Amount',
      };

  @override
  CalculationResult compute(CalculatorInputs raw) {
    final qty = _asNum(raw['quantity'], 'Quantity');
    final price = _asNum(raw['pricePerUnit'], 'Price per Unit');
    _requireNotNegative(qty, 'Quantity');
    _requireNotNegative(price, 'Price per Unit');
    final expected = qty * price;
    return CalculationResult(
      inputs: Map.of(raw),
      outputs: {'quantity': qty, 'pricePerUnit': price, 'unitLabel': raw['unitLabel'] ?? ''},
      expectedAmount: expected,
      formulaLabel: '${_fmt(qty)} × ${_fmtMoney(price)}',
    );
  }
}

void _requirePositive(double v, String label) {
  if (v <= 0) {
    throw ValidationException('$label cannot be negative or zero.');
  }
}

void _requireNotNegative(double v, String label) {
  if (v < 0) {
    throw ValidationException('$label cannot be negative.');
  }
}

String _fmt(num v) => v.floor() == v ? v.round().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
String _fmtMoney(num v) => 'TSh ${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

/// Registry mapping a work type's formula code to a concrete formula.
class WorkTypeCalculator {
  final List<CalculationFormula> _formulas;

  WorkTypeCalculator(this._formulas);

  factory WorkTypeCalculator.standard() => WorkTypeCalculator([
        AreaFixedFormula(),
        AreaRateFormula(),
        KupigaDawaFormula(),
        const QuantityPriceFormula(quantityKey: 'harvestedKg', priceKey: 'pricePerKg'),
        const QuantityPriceFormula(quantityKey: 'bagsUsed', priceKey: 'pricePerBag'),
        CustomFormula(),
      ]);

  CalculationFormula? formulaFor(String formulaCode) {
    for (final f in _formulas) {
      if (f.code == formulaCode) return f;
    }
    return null;
  }

  /// Builds the default input map for a work type (all fields empty).
  CalculatorInputs emptyInputsFor(WorkType workType) {
    final out = <String, dynamic>{};
    for (final f in workType.fields) {
      out[f.key] = '';
    }
    return out;
  }

  /// Computes for a stored [WorkType] using its configured inputs.
  CalculationResult computeForWorkType(WorkType workType, CalculatorInputs raw) {
    final formula = formulaFor(workType.formulaCode);
    if (formula == null) {
      throw ValidationException('Formula "${workType.formulaCode}" is not registered.');
    }
    // Validate that every numeric/required field can be read as a number.
    for (final f in workType.fields) {
      final v = raw[f.key];
      if (v == null || '$v'.trim().isEmpty) {
        if (f.required) {
          throw ValidationException('${f.label} is required.');
        }
        continue;
      }
      if (f.type != 'text' && double.tryParse('$v'.trim().replaceAll(',', '')) == null) {
        throw ValidationException('${f.label} must be a valid number.');
      }
    }
    return formula.compute(raw);
  }
}