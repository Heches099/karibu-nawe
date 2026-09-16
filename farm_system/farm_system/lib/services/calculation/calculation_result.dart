/// Pure result object returned by the calculation engine. Contains
/// everything needed to build a permanent Calculation record.
class CalculationResult {
  final Map<String, dynamic> inputs;
  final double measuredValue;
  final String measuredUnit;
  final int expectedAmount;
  final List<String> breakdown; // human-readable lines for the UI/receipt

  const CalculationResult({
    required this.inputs,
    required this.measuredValue,
    required this.measuredUnit,
    required this.expectedAmount,
    required this.breakdown,
  });
}

class CalculationValidationError implements Exception {
  final String message;
  CalculationValidationError(this.message);
  @override
  String toString() => message;
}
