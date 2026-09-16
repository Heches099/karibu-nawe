import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Formatters {
  Formatters._();

  /// Allows digits + optional decimal point, no leading minus.
  static final TextInputFormatter nonNegativeDecimal = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d*'),
  );

  static final TextInputFormatter digitsOnly = FilteringTextInputFormatter.digitsOnly;

  static double? parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleaned);
  }
}

class Validators {
  Validators._();

  static String? required(String? v) =>
      v == null || v.trim().isEmpty ? 'This field is required.' : null;

  static String? positiveNumber(String? v) {
    final n = Formatters.parseAmount(v ?? '');
    if (n == null) return 'Enter a valid number.';
    if (n <= 0) return 'Must be greater than zero.';
    return null;
  }

  static String? nonNegativeNumber(String? v) {
    final n = Formatters.parseAmount(v ?? '');
    if (n == null) return 'Enter a valid number.';
    if (n < 0) return 'Cannot be negative.';
    return null;
  }

  static String? money(String? v) {
    final n = Formatters.parseAmount(v ?? '');
    if (n == null) return 'Enter a valid amount.';
    if (n <= 0) return 'Amount must be greater than zero.';
    return null;
  }

  static String? moneyOrZero(String? v) {
    final n = Formatters.parseAmount(v ?? '');
    if (n == null) return 'Enter a valid amount.';
    if (n < 0) return 'Amount cannot be negative.';
    return null;
  }
}

/// Number field with thousands separator suffix and unit label.
class NumericField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final bool money;
  final String? Function(String?)? validator;
  final String? hint;
  final VoidCallback? onChanged;

  const NumericField({
    super.key,
    required this.controller,
    required this.label,
    this.unit = '',
    this.money = false,
    this.validator,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [Formatters.nonNegativeDecimal],
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        hintText: money ? 'e.g. 4,000' : hint,
        suffixText: unit,
      ),
      validator: validator ?? (money ? Validators.money : Validators.positiveNumber),
    );
  }
}

/// Displays an error message without requiring Scaffold/SnackBar context confusion.
void showError(BuildContext context, Object e) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text('${e is String ? e : e}')),
        ],
      ),
      backgroundColor: const Color(0xFFC62828),
    ),
  );
}

void showSuccess(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: const Color(0xFF2E7D32),
  ));
}

/// Generic confirmation dialog.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = const Color(0xFFC62828),
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Wide modal sheet wrapper - full screen on phones, centered card on desktop.
Future<T?> showAppSheet<T>(BuildContext context, Widget child, {String? title, bool scrollable = true}) {
  final isWide = MediaQuery.of(context).size.width >= 840;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final content = Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      );
      return isWide
          ? Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: content,
                ),
              ),
            )
          : SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.92,
              child: content,
            );
    },
  );
}