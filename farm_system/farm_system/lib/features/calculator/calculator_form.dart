import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/calculation.dart';
import '../../models/work_type.dart';
import '../../services/calculation/calculation_engine.dart';
import '../../services/calculation/calculation_result.dart';
import '../../state/app_state.dart';

/// Renders the correct calculator inputs for the task's Work Type
/// category (spec sections 5–7) and lets the Boss preview the result
/// before committing it as the permanent baseline Calculation.
class CalculatorForm extends StatefulWidget {
  final String taskId;
  final WorkType workType;
  final Calculation? existing;
  const CalculatorForm({super.key, required this.taskId, required this.workType, this.existing});

  @override
  State<CalculatorForm> createState() => _CalculatorFormState();
}

class _CalculatorFormState extends State<CalculatorForm> {
  final _controllers = <String, TextEditingController>{};
  CalculationResult? _preview;
  String? _error;
  final _reasonController = TextEditingController();

  TextEditingController _c(String key, [String initial = '']) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void initState() {
    super.initState();
    final existingInputs = widget.existing?.inputs;
    if (existingInputs != null) {
      for (final entry in existingInputs.entries) {
        _c(entry.key, entry.value.toString());
      }
    }
  }

  Map<String, dynamic> _collectInputs(CalculationCategory category) {
    double? numVal(String key) => double.tryParse(_c(key).text.trim());
    switch (category) {
      case CalculationCategory.areaFixedPayment:
        return {
          'length': numVal('length'),
          'width': numVal('width'),
          'agreedPayment': numVal('agreedPayment')?.toInt(),
        };
      case CalculationCategory.areaWithRate:
        return {
          'length': numVal('length'),
          'width': numVal('width'),
          'ratePerSqm': numVal('ratePerSqm'),
        };
      case CalculationCategory.sprayingChemical:
        return {
          'length': numVal('length'),
          'width': numVal('width'),
          'coveragePerLitre': numVal('coveragePerLitre'),
          'pricePerLitre': numVal('pricePerLitre'),
          'applications': numVal('applications')?.toInt() ?? 1,
        };
      case CalculationCategory.quantityWithRate:
        return {
          'quantity': numVal('quantity'),
          'pricePerUnit': numVal('pricePerUnit'),
          'unit': _c('unit', widget.workType.unitLabel).text.trim(),
        };
      case CalculationCategory.customFormula:
        return {
          'measuredValue': numVal('measuredValue'),
          'measuredUnit': _c('measuredUnit', widget.workType.unitLabel).text.trim(),
          'expectedAmount': numVal('expectedAmount')?.toInt(),
        };
    }
  }

  void _calculatePreview() {
    setState(() {
      _error = null;
      _preview = null;
    });
    try {
      final inputs = _collectInputs(widget.workType.category);
      final result = CalculationEngine.calculate(category: widget.workType.category, inputs: inputs);
      setState(() => _preview = result);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    if (_preview == null) _calculatePreview();
    if (_preview == null) return;
    final app = context.read<AppState>();
    final hasExisting = widget.existing != null;
    if (hasExisting && _reasonController.text.trim().isEmpty) {
      setState(() => _error = 'A reason is required when revising an existing calculation.');
      return;
    }
    await app.saveCalculation(
      taskId: widget.taskId,
      workTypeId: widget.workType.id,
      category: widget.workType.category,
      inputs: _collectInputs(widget.workType.category),
      revisionReason: hasExisting ? _reasonController.text.trim() : null,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculation saved as the official baseline.')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsFor(widget.workType.category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.calculate_outlined),
              const SizedBox(width: 8),
              Text('${widget.workType.name} Calculator',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 4),
            if (widget.existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Revising existing calculation. The current baseline (TSh ${widget.existing!.expectedAmount}) will be preserved in history.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            ...fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _c(f.key, f.initial),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: f.label, suffixText: f.suffix),
                  ),
                )),
            if (widget.existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason for revision *'),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _calculatePreview, child: const Text('PREVIEW')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(widget.existing == null ? 'SAVE AS BASELINE' : 'SAVE REVISION'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('CALCULATION', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              ..._preview!.breakdown.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(line),
                  )),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(CurrencyFormatter.format(_preview!.expectedAmount),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_FieldSpec> _fieldsFor(CalculationCategory category) {
    switch (category) {
      case CalculationCategory.areaFixedPayment:
        return const [
          _FieldSpec('length', 'Length', 'm'),
          _FieldSpec('width', 'Width', 'm'),
          _FieldSpec('agreedPayment', 'Agreed Payment for this area', 'TSh'),
        ];
      case CalculationCategory.areaWithRate:
        return const [
          _FieldSpec('length', 'Length', 'm'),
          _FieldSpec('width', 'Width', 'm'),
          _FieldSpec('ratePerSqm', 'Rate per m²', 'TSh'),
        ];
      case CalculationCategory.sprayingChemical:
        return const [
          _FieldSpec('length', 'Length', 'm'),
          _FieldSpec('width', 'Width', 'm'),
          _FieldSpec('coveragePerLitre', 'Coverage (m² per litre)', 'm²/L'),
          _FieldSpec('pricePerLitre', 'Price per litre', 'TSh'),
          _FieldSpec('applications', 'Number of applications', '', initial: '1'),
        ];
      case CalculationCategory.quantityWithRate:
        return [
          _FieldSpec('quantity', 'Quantity harvested', widget.workType.unitLabel),
          const _FieldSpec('pricePerUnit', 'Price per unit', 'TSh'),
        ];
      case CalculationCategory.customFormula:
        return [
          _FieldSpec('measuredValue', 'Measured value', widget.workType.unitLabel),
          const _FieldSpec('expectedAmount', 'Expected amount', 'TSh'),
        ];
    }
  }
}

class _FieldSpec {
  final String key;
  final String label;
  final String suffix;
  final String initial;
  const _FieldSpec(this.key, this.label, this.suffix, {this.initial = ''});
}
