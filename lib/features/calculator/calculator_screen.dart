import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/calculation/calculation_engine.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';

class CalculatorScreen extends StatelessWidget {
  final Task task;
  const CalculatorScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wt = store.workTypeById(task.workTypeId);
    if (wt == null) {
      return const Center(child: Text('Work type not found.'));
    }
    final calc = store.calculationFor(task.id);
    final formula = store.calculator.formulaFor(wt.formulaCode);

    if (calc == null) {
      return _CalculatorForm(wt: wt, task: task, formulaLabel: formula?.label ?? '');
    }
    return _SavedCalculation(wt: wt, calc: calc, actor: calc.createdBy);
  }
}

class _CalculatorForm extends StatefulWidget {
  final WorkType wt;
  final Task task;
  final String formulaLabel;
  const _CalculatorForm({required this.wt, required this.task, required this.formulaLabel});

  @override
  State<_CalculatorForm> createState() => _CalculatorFormState();
}

class _CalculatorFormState extends State<_CalculatorForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  CalculationResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fields = {};
    for (final f in widget.wt.fields) {
      _fields[f.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recompute() {
    if (_form.currentState == null || !_form.currentState!.validate()) {
      return;
    }
    final raw = <String, dynamic>{};
    for (final f in widget.wt.fields) {
      raw[f.key] = _fields[f.key]!.text.trim();
    }
    try {
      final store = context.read<AppStore>();
      final result = store.calculator.computeForWorkType(widget.wt, raw);
      setState(() {
        _result = result;
        _error = null;
      });
    } on Exception catch (e) {
      setState(() {
        _result = null;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final formula = store.calculator.formulaFor(widget.wt.formulaCode);
    final outputLabels = formula?.outputLabels ?? {};

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Calculation for ${widget.wt.name}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        if (widget.formulaLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Formula: ${widget.formulaLabel}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              for (final f in widget.wt.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: f.type == 'text'
                      ? TextFormField(
                          controller: _fields[f.key]!,
                          decoration: InputDecoration(labelText: f.label, suffixText: f.unit),
                        )
                      : NumericField(
                          controller: _fields[f.key]!,
                          label: f.label,
                          unit: f.unit,
                          money: f.type == 'money',
                          onChanged: _recompute,
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828))),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _result == null ? Theme.of(context).colorScheme.surfaceContainerLow : const Color(0xFF2E7D32).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _result == null ? Theme.of(context).colorScheme.outlineVariant : const Color(0xFF2E7D32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('RESULT', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 8),
              if (_result == null)
                const Text('Fill the fields above to see the live calculation.')
              else ...[
                for (final e in _result!.outputs.entries)
                  if (e.key != 'unitLabel' && e.value is num)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(outputLabels[e.key] ?? e.key),
                        Text(
                          _display(e.key, e.value as num),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Worker Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                    MoneyText(_result!.expectedAmount, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                if (_result!.resourceCost > 0) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Material Cost'),
                      MoneyText(_result!.resourceCost, compact: true),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _result == null
              ? null
              : () async {
                  try {
                    await store.saveCalculation(task: widget.task, workType: widget.wt, inputs: _result!.inputs);
                    if (mounted) {
                      showSuccess(context, 'Calculation saved as the official baseline. Expected: ${fmtMoney(_result!.expectedAmount.round())}');
                      Navigator.of(context).pop(true);
                    }
                  } catch (e) {
                    if (mounted) showError(context, e);
                  }
                },
          icon: const Icon(Icons.save_outlined),
          label: const Text('SAVE CALCULATION AS BASELINE'),
        ),
      ],
    );
  }

  String _display(String key, num v) {
    switch (key) {
      case 'area':
        return fmtArea(v);
      case 'litres':
        return fmtLitres(v);
      case 'agreedPayment':
      case 'ratePerUnit':
      case 'pricePerLitre':
      case 'pricePerKg':
      case 'pricePerBag':
      case 'pricePerUnit':
      case 'resourceCost':
      case 'workerPayment':
        return fmtMoney(v);
      default:
        return fmtNumber(v);
    }
  }
}

class _SavedCalculation extends StatelessWidget {
  final WorkType wt;
  final Calculation calc;
  final String actor;
  const _SavedCalculation({required this.wt, required this.calc, required this.actor});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SAVED BASELINE — this is the original calculation for this task. It is preserved and never overwritten.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _calcRow(context, 'Work Type', wt.name),
        for (final e in calc.inputs.entries)
          if (e.value is num)
            _calcRow(context, _inputLabel(e.key), _displayValue(e.key, e.value as num)),
        const Divider(),
        for (final e in calc.outputs.entries)
          if (e.value is num) _calcRow(context, _outputLabel(e.key), _displayValue(e.key, e.value as num)),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected Worker Payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              MoneyText(calc.expectedAmount, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        if (calc.resourceCost > 0)
          _calcRow(context, 'Estimated Material Cost', fmtMoney(calc.resourceCost.round())),
        const SizedBox(height: 6),
        Text('Formula: ${calc.formulaLabel}', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text('Recorded ${fmtDateTime(calc.createdAt)} by $actor', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _calcRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _inputLabel(String key) {
    for (final f in wt.fields) {
      if (f.key == key) return f.label;
    }
    return key;
  }

  String _outputLabel(String key) {
    final field = wt.fields.where((f) => f.key == key).firstOrNull;
    return field?.label ?? key;
  }

  String _displayValue(String key, num v) {
    switch (key) {
      case 'area':
        return fmtArea(v);
      case 'litres':
        return fmtLitres(v);
      case 'agreedPayment':
      case 'ratePerUnit':
      case 'pricePerLitre':
      case 'pricePerKg':
      case 'pricePerBag':
      case 'pricePerUnit':
      case 'resourceCost':
      case 'workerPayment':
        return fmtMoney(v);
      default:
        return fmtNumber(v);
    }
  }
}