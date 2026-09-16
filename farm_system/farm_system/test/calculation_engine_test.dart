import 'package:flutter_test/flutter_test.dart';
import 'package:farm_system/core/constants/enums.dart';
import 'package:farm_system/services/calculation/calculation_engine.dart';
import 'package:farm_system/services/calculation/calculation_result.dart';

/// Pure unit tests for the Calculation Engine — no Flutter widgets, no
/// Hive, no I/O. This is what "business logic must be independently
/// testable" (spec section 28) means in practice. Run with:
///   flutter test test/calculation_engine_test.dart
void main() {
  group('Kupalilia — area fixed payment (spec section 5)', () {
    test('900 m² with an agreed TSh 4,000 payment => Expected = TSh 4,000', () {
      final result = CalculationEngine.calculate(
        category: CalculationCategory.areaFixedPayment,
        inputs: {'length': 30, 'width': 30, 'agreedPayment': 4000},
      );
      expect(result.measuredValue, 900);
      expect(result.measuredUnit, 'm²');
      expect(result.expectedAmount, 4000); // NOT 900 * 4000
    });

    test('rejects zero area', () {
      expect(
        () => CalculationEngine.calculate(
          category: CalculationCategory.areaFixedPayment,
          inputs: {'length': 0, 'width': 30, 'agreedPayment': 4000},
        ),
        throwsA(isA<CalculationValidationError>()),
      );
    });

    test('rejects negative length', () {
      expect(
        () => CalculationEngine.calculate(
          category: CalculationCategory.areaFixedPayment,
          inputs: {'length': -5, 'width': 30, 'agreedPayment': 4000},
        ),
        throwsA(isA<CalculationValidationError>()),
      );
    });
  });

  group('Kupiga Dawa — spraying (spec section 6)', () {
    test('900 m² / 1000 m² per litre / TSh 8000 per litre => TSh 7,200', () {
      final result = CalculationEngine.calculate(
        category: CalculationCategory.sprayingChemical,
        inputs: {
          'length': 30,
          'width': 30,
          'coveragePerLitre': 1000,
          'pricePerLitre': 8000,
          'applications': 1,
        },
      );
      expect(result.measuredValue, 900);
      expect(result.expectedAmount, 7200);
    });

    test('two applications doubles the required litres and cost', () {
      final result = CalculationEngine.calculate(
        category: CalculationCategory.sprayingChemical,
        inputs: {
          'length': 30,
          'width': 30,
          'coveragePerLitre': 1000,
          'pricePerLitre': 8000,
          'applications': 2,
        },
      );
      expect(result.expectedAmount, 14400);
    });
  });

  group('Kuvuna — quantity with rate', () {
    test('120 kg at TSh 500/kg => TSh 60,000', () {
      final result = CalculationEngine.calculate(
        category: CalculationCategory.quantityWithRate,
        inputs: {'quantity': 120, 'pricePerUnit': 500, 'unit': 'kg'},
      );
      expect(result.expectedAmount, 60000);
    });
  });
}
