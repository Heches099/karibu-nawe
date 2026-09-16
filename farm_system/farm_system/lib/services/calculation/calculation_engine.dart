import '../../core/constants/enums.dart';
import 'calculation_result.dart';

/// The reusable Calculation Engine described in spec section 4.
///
/// Each [CalculationCategory] has one pure function here. Business rule
/// (spec section 5): for area-based flat-payment work, the agreed
/// payment is the TOTAL for the whole measured area — we do NOT multiply
/// area × price. For spraying, we DO multiply required litres × price.
///
/// Adding a brand-new formula later means adding one case + one function
/// here — nothing in the UI, repositories, or models needs to change,
/// because they all just consume a [CalculationResult].
class CalculationEngine {
  CalculationEngine._();

  static CalculationResult calculate({
    required CalculationCategory category,
    required Map<String, dynamic> inputs,
  }) {
    switch (category) {
      case CalculationCategory.areaFixedPayment:
        return _areaFixedPayment(inputs);
      case CalculationCategory.areaWithRate:
        return _areaWithRate(inputs);
      case CalculationCategory.sprayingChemical:
        return _sprayingChemical(inputs);
      case CalculationCategory.quantityWithRate:
        return _quantityWithRate(inputs);
      case CalculationCategory.customFormula:
        return _customFormula(inputs);
    }
  }

  // ---- Kupalilia / Kupanda / Mbolea: area measured, flat agreed payment ----
  static CalculationResult _areaFixedPayment(Map<String, dynamic> inputs) {
    final length = _requireNonNegativeDouble(inputs, 'length');
    final width = _requireNonNegativeDouble(inputs, 'width');
    final agreedPayment = _requireNonNegativeInt(inputs, 'agreedPayment');

    final area = length * width;
    if (area <= 0) {
      throw CalculationValidationError('Measured area must be greater than zero.');
    }

    return CalculationResult(
      inputs: {
        'length': length,
        'width': width,
        'agreedPayment': agreedPayment,
      },
      measuredValue: area,
      measuredUnit: 'm²',
      expectedAmount: agreedPayment,
      breakdown: [
        'Length: ${length.toStringAsFixed(0)} m',
        'Width: ${width.toStringAsFixed(0)} m',
        'Area: ${area.toStringAsFixed(0)} m² (Length × Width)',
        'Agreed Payment for ${area.toStringAsFixed(0)} m²: TSh $agreedPayment',
        'Expected Amount = TSh $agreedPayment (NOT area × payment)',
      ],
    );
  }

  // ---- Area paid per unit rate, e.g. TSh X per m² ----
  static CalculationResult _areaWithRate(Map<String, dynamic> inputs) {
    final length = _requireNonNegativeDouble(inputs, 'length');
    final width = _requireNonNegativeDouble(inputs, 'width');
    final ratePerSqm = _requireNonNegativeDouble(inputs, 'ratePerSqm');

    final area = length * width;
    if (area <= 0) {
      throw CalculationValidationError('Measured area must be greater than zero.');
    }
    final expected = (area * ratePerSqm).round();

    return CalculationResult(
      inputs: {'length': length, 'width': width, 'ratePerSqm': ratePerSqm},
      measuredValue: area,
      measuredUnit: 'm²',
      expectedAmount: expected,
      breakdown: [
        'Area: ${area.toStringAsFixed(0)} m² (Length × Width)',
        'Rate: TSh ${ratePerSqm.toStringAsFixed(0)} per m²',
        'Expected Amount = Area × Rate = TSh $expected',
      ],
    );
  }

  // ---- Kupiga Dawa: area + coverage + price per litre ----
  static CalculationResult _sprayingChemical(Map<String, dynamic> inputs) {
    final length = _requireNonNegativeDouble(inputs, 'length');
    final width = _requireNonNegativeDouble(inputs, 'width');
    final coveragePerLitre =
        _requireNonNegativeDouble(inputs, 'coveragePerLitre'); // m² per litre
    final pricePerLitre = _requireNonNegativeDouble(inputs, 'pricePerLitre');
    final applications =
        (inputs['applications'] as num?)?.toInt() ?? 1;

    if (coveragePerLitre <= 0) {
      throw CalculationValidationError('Coverage per litre must be greater than zero.');
    }
    if (applications < 1) {
      throw CalculationValidationError('Number of applications must be at least 1.');
    }

    final area = length * width;
    if (area <= 0) {
      throw CalculationValidationError('Measured area must be greater than zero.');
    }

    final requiredLitres = (area / coveragePerLitre) * applications;
    final expected = (requiredLitres * pricePerLitre).round();

    return CalculationResult(
      inputs: {
        'length': length,
        'width': width,
        'coveragePerLitre': coveragePerLitre,
        'pricePerLitre': pricePerLitre,
        'applications': applications,
      },
      measuredValue: area,
      measuredUnit: 'm²',
      expectedAmount: expected,
      breakdown: [
        'Area: ${area.toStringAsFixed(0)} m² (Length × Width)',
        'Coverage: 1 litre / ${coveragePerLitre.toStringAsFixed(0)} m²',
        if (applications > 1) 'Applications: $applications',
        'Chemical Required: ${requiredLitres.toStringAsFixed(2)} litres '
            '(Area ÷ Coverage${applications > 1 ? ' × Applications' : ''})',
        'Price per litre: TSh ${pricePerLitre.toStringAsFixed(0)}',
        'Expected Amount = Required Litres × Price per Litre = TSh $expected',
      ],
    );
  }

  // ---- Kuvuna: quantity harvested × price per unit ----
  static CalculationResult _quantityWithRate(Map<String, dynamic> inputs) {
    final quantity = _requireNonNegativeDouble(inputs, 'quantity');
    final pricePerUnit = _requireNonNegativeDouble(inputs, 'pricePerUnit');
    final unit = (inputs['unit'] as String?) ?? 'kg';

    if (quantity <= 0) {
      throw CalculationValidationError('Quantity must be greater than zero.');
    }
    final expected = (quantity * pricePerUnit).round();

    return CalculationResult(
      inputs: {'quantity': quantity, 'pricePerUnit': pricePerUnit, 'unit': unit},
      measuredValue: quantity,
      measuredUnit: unit,
      expectedAmount: expected,
      breakdown: [
        'Quantity: ${quantity.toStringAsFixed(1)} $unit',
        'Price per $unit: TSh ${pricePerUnit.toStringAsFixed(0)}',
        'Expected Amount = Quantity × Price = TSh $expected',
      ],
    );
  }

  // ---- Custom: manager states measurement + amount directly ----
  static CalculationResult _customFormula(Map<String, dynamic> inputs) {
    final measuredValue = _requireNonNegativeDouble(inputs, 'measuredValue');
    final measuredUnit = (inputs['measuredUnit'] as String?) ?? 'unit';
    final expectedAmount = _requireNonNegativeInt(inputs, 'expectedAmount');

    return CalculationResult(
      inputs: {
        'measuredValue': measuredValue,
        'measuredUnit': measuredUnit,
        'expectedAmount': expectedAmount,
      },
      measuredValue: measuredValue,
      measuredUnit: measuredUnit,
      expectedAmount: expectedAmount,
      breakdown: [
        'Measured: ${measuredValue.toStringAsFixed(2)} $measuredUnit',
        'Expected Amount (entered directly): TSh $expectedAmount',
      ],
    );
  }

  // ---------------------------------------------------------------------
  static double _requireNonNegativeDouble(Map<String, dynamic> inputs, String key) {
    final raw = inputs[key];
    if (raw == null) {
      throw CalculationValidationError('$key is required.');
    }
    final value = (raw as num).toDouble();
    if (value < 0) {
      throw CalculationValidationError('$key cannot be negative.');
    }
    return value;
  }

  static int _requireNonNegativeInt(Map<String, dynamic> inputs, String key) {
    final raw = inputs[key];
    if (raw == null) {
      throw CalculationValidationError('$key is required.');
    }
    final value = (raw as num).toInt();
    if (value < 0) {
      throw CalculationValidationError('$key cannot be negative.');
    }
    return value;
  }
}
