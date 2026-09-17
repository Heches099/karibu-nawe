import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Retricted set of badge styles used across the app.
enum BadgeKind {
  paid(StatusColors.paid, Icons.check_circle, 'Paid'),
  partial(StatusColors.partial, Icons.hourglass_top, 'Partial'),
  unpaid(StatusColors.unpaid, Icons.error_outline, 'Unpaid'),
  adjusted(StatusColors.adjusted, Icons.swap_horiz, 'Adjusted'),
  collected(StatusColors.collected, Icons.arrow_downward, 'Collected'),
  collectedByOther(StatusColors.collected, Icons.arrow_downward, 'Collected by other'),
  pending(StatusColors.pending, Icons.schedule, 'Pending'),
  handoverPending(Color(0xFFF9A825), Icons.schedule, 'Handover pending'),
  completed(StatusColors.completed, Icons.check_circle, 'Completed'),
  active(StatusColors.live, Icons.play_circle, 'Active'),
  cancelled(StatusColors.unpaid, Icons.cancel, 'Cancelled'),
  collectedPending(StatusColors.pending, Icons.schedule, 'Pending'),
  live(StatusColors.live, Icons.circle, 'LIVE'),
  offline(StatusColors.offline, Icons.cloud_off, 'OFFLINE'),
  info(StatusColors.info, Icons.info_outline, 'Info');

  final Color color;
  final IconData icon;
  final String defaultLabel;

  const BadgeKind(this.color, this.icon, this.defaultLabel);
}

/// Text + icon + color badge (never color alone).
class StatusBadge extends StatelessWidget {
  final BadgeKind kind;
  final String? label;
  final bool pulse;

  const StatusBadge(this.kind, {super.key, this.label, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final label = this.label ?? kind.defaultLabel;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = kind.color.withValues(alpha: 0.14);
    final fg = dark ? Color.lerp(kind.color, Colors.white, 0.25)! : kind.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            _Pulse(dot: Icons.circle, color: fg, size: 10)
          else
            Icon(kind.icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final IconData dot;
  final Color color;
  final double size;
  const _Pulse({required this.dot, required this.color, required this.size});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_c),
      child: Icon(widget.dot, size: widget.size, color: widget.color),
    );
  }
}