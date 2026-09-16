import 'package:flutter_test/flutter_test.dart';
import 'package:farm_fms/core/errors/app_exception.dart';
import 'package:farm_fms/models/work_type.dart';
import 'package:farm_fms/services/calculation/calculation_engine.dart';

void main() {
  final calc = WorkTypeCalculator.standard();

  group('AreaFixedFormula (Kupalilia)', () {
    test('30×30 = 900 m², agreed TSh 4,000', () {
      final r = calc.formulaFor('area_fixed')!.compute({
        'length': 30,
        'width': 30,
        'agreedPayment': 4000,
      });
      expect(r.outputs['area'], 900);
      expect(r.expectedAmount, 4000);
    });
    test('zero length throws', () {
      expect(
        () => calc.formulaFor('area_fixed')!.compute({
          'length': 0, 'width': 30, 'agreedPayment': 4000,
        }),
        throwsA(isA<ValidationException>()),
      );
    });
    test('negative width throws', () {
      expect(
        () => calc.formulaFor('area_fixed')!.compute({
          'length': 30, 'width': -10, 'agreedPayment': 4000,
        }),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('AreaRateFormula (Kupanda)', () {
    test('40×25 = 1000 m² × TSh 10/m² = TSh 10,000', () {
      final r = calc.formulaFor('area_rate')!.compute({
        'length': 40,
        'width': 25,
        'ratePerUnit': 10,
      });
      expect(r.outputs['area'], 1000);
      expect(r.expectedAmount, 10000);
    });
    test('zero rate is allowed (volunteer)', () {
      final r = calc.formulaFor('area_rate')!.compute({
        'length': 10, 'width': 10, 'ratePerUnit': 0,
      });
      expect(r.expectedAmount, 0);
    });
  });

  group('KupigaDawaFormula', () {
    test('30×30=900, chemical cost is separate from worker payment', () {
      final r = calc.formulaFor('kupiga_dawa')!.compute({
        'length': 30,
        'width': 30,
        'coverage': 1000,
        'pricePerLitre': 8000,
        'workerPayment': 4000,
      });
      expect(r.outputs['area'], 900);
      expect(r.outputs['litres'], closeTo(0.9, 0.0001));
      expect(r.resourceCost, closeTo(7200, 0.01));
      expect(r.expectedAmount, 4000);
    });
    test('zero coverage throws', () {
      expect(
        () => calc.formulaFor('kupiga_dawa')!.compute({
          'length': 30, 'width': 30, 'coverage': 0, 'pricePerLitre': 8000,
          'workerPayment': 4000,
        }),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('QuantityPriceFormula (Kuvuna)', () {
    test('2000 kg × TSh 200 = TSh 400,000', () {
      final r = calc.formulaFor('quantity_price')!.compute({
        'harvestedKg': 2000,
        'pricePerKg': 200,
      });
      expect(r.outputs['harvestedKg'], 2000);
      expect(r.expectedAmount, 400000);
    });
  });

  group('QuantityPriceFormula (Mbolea)', () {
    test('10 bags × TSh 20,000 = TSh 200,000', () {
      final r = calc.formulaFor('quantity_price')!.compute({
        'bagsUsed': 10,
        'pricePerBag': 20000,
      });
      expect(r.expectedAmount, 200000);
    });
  });

  group('CustomFormula', () {
    test('quantity 50 × TSh 1000 = TSh 50,000', () {
      final r = calc.formulaFor('custom')!.compute({
        'quantity': 50,
        'pricePerUnit': 1000,
      });
      expect(r.expectedAmount, 50000);
    });
  });

  test('manual area rule calculates full work expected cost', () {
    final workType = WorkType(
      id: 'manual-area',
      name: 'Manual Area Work',
      code: 'manual-area',
      formulaCode: 'area_rate',
      fields: WorkType.customAreaFields,
      createdAt: DateTime(2026),
    );
    final r = calc.computeForWorkType(workType, {
      'length': 30,
      'width': 30,
      'ratePerUnit': 80,
    });
    expect(r.outputs['area'], 900);
    expect(r.expectedAmount, 72000);
  });

  group('computeForWorkType validation', () {
    test('missing required field throws', () {
      final wt = calc.formulaFor('area_fixed')!;
      expect(
        () => wt.compute({'length': 30, 'width': '', 'agreedPayment': 4000}),
        throwsA(isA<ValidationException>()),
      );
    });
    test('non-numeric required field throws', () {
      final wt = calc.formulaFor('area_fixed')!;
      expect(
        () => wt.compute({'length': 'abc', 'width': 30, 'agreedPayment': 4000}),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('WorkTypeCalculator registry', () {
    test('all built-in formulas are present', () {
      expect(calc.formulaFor('area_fixed'), isNotNull);
      expect(calc.formulaFor('area_rate'), isNotNull);
      expect(calc.formulaFor('kupiga_dawa'), isNotNull);
      expect(calc.formulaFor('quantity_price'), isNotNull);
      expect(calc.formulaFor('custom'), isNotNull);
    });
    test('unknown formula code returns null', () {
      expect(calc.formulaFor('nonexistent'), isNull);
    });
  });
}
