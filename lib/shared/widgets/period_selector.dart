import 'package:flutter/material.dart';

import '../../core/utils/format.dart';

enum ReportPeriod { today, yesterday, thisWeek, thisMonth, custom, all }

extension ReportPeriodX on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.yesterday:
        return 'Yesterday';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.custom:
        return 'Custom';
      case ReportPeriod.all:
        return 'All';
    }
  }
}

class DateRange {
  final DateTime from;
  final DateTime to;
  const DateRange(this.from, this.to);
}

class PeriodSelector extends StatefulWidget {
  final ReportPeriod initial;
  final ValueChanged<DateRange?> onChanged;
  final bool showAll;

  const PeriodSelector({super.key, this.initial = ReportPeriod.today, required this.onChanged, this.showAll = true});

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late ReportPeriod _period = widget.initial;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customTo = DateTime.now();

  static DateRange? _resolve(ReportPeriod p, DateTime cf, DateTime ct) {
    final now = DateTime.now();
    final today = dateOnly(now);
    switch (p) {
      case ReportPeriod.today:
        return DateRange(today, today);
      case ReportPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return DateRange(y, y);
      case ReportPeriod.thisWeek:
        final weekday = today.weekday;
        final start = today.subtract(Duration(days: weekday - 1));
        return DateRange(start, today);
      case ReportPeriod.thisMonth:
        return DateRange(DateTime(today.year, today.month, 1), today);
      case ReportPeriod.custom:
        return DateRange(dateOnly(cf), dateOnly(ct));
      case ReportPeriod.all:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // initial callback so the dashboard loads with a period
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(_resolve(_period, _customFrom, _customTo));
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final from = await showDatePicker(
      context: context,
      initialDate: _customFrom.isAfter(now) ? now : _customFrom,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'From',
    );
    if (from == null) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _customTo.isAfter(now) ? now : _customTo,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'To',
    );
    if (to == null) return;
    setState(() {
      _customFrom = from;
      _customTo = to.isBefore(from) ? from : to;
    });
    widget.onChanged(_resolve(_period, _customFrom, _customTo));
  }

  @override
  Widget build(BuildContext context) {
    final opts = <ReportPeriod>[
      ReportPeriod.today,
      ReportPeriod.yesterday,
      ReportPeriod.thisWeek,
      ReportPeriod.thisMonth,
      if (widget.showAll || _period == ReportPeriod.all || _period == ReportPeriod.custom) ReportPeriod.custom,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in opts)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: _period == p,
                    onSelected: (_) {
                      setState(() => _period = p);
                      widget.onChanged(_resolve(p, _customFrom, _customTo));
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_period == ReportPeriod.custom)
          OutlinedButton.icon(
            onPressed: _pickCustomDate,
            icon: const Icon(Icons.date_range, size: 18),
            label: Text('${fmtDate(_customFrom)} → ${fmtDate(_customTo)}'),
          ),
        if (widget.showAll)
          TextButton(
            onPressed: () {
              setState(() => _period = ReportPeriod.all);
              widget.onChanged(null);
            },
            child: Text(_period == ReportPeriod.all ? 'Showing ● All time' : 'Show all'),
          ),
      ],
    );
  }
}