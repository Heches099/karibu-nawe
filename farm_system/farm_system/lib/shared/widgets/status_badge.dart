import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';

/// A status is always shown as text + icon + color together — never
/// color alone (spec section 29), so the app stays usable for anyone
/// with color-vision differences and reads clearly in black & white
/// printouts too.
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.icon, required this.color});

  factory StatusBadge.payment(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return const StatusBadge(label: 'Paid', icon: Icons.check_circle, color: AppTheme.success);
      case PaymentStatus.partial:
        return const StatusBadge(label: 'Partial', icon: Icons.adjust, color: AppTheme.warning);
      case PaymentStatus.unpaid:
        return const StatusBadge(label: 'Unpaid', icon: Icons.error_outline, color: AppTheme.danger);
    }
  }

  factory StatusBadge.collection(CollectionStatus status) {
    switch (status) {
      case CollectionStatus.collected:
        return const StatusBadge(label: 'Collected', icon: Icons.south, color: AppTheme.info);
      case CollectionStatus.handedOver:
        return const StatusBadge(label: 'Handed Over', icon: Icons.check_circle, color: AppTheme.success);
    }
  }

  factory StatusBadge.handover(HandoverStatus status) {
    switch (status) {
      case HandoverStatus.pending:
        return const StatusBadge(label: 'Pending', icon: Icons.hourglass_bottom, color: AppTheme.warning);
      case HandoverStatus.completed:
        return const StatusBadge(label: 'Completed', icon: Icons.check_circle, color: AppTheme.success);
    }
  }

  factory StatusBadge.adjusted() =>
      const StatusBadge(label: 'Adjusted', icon: Icons.swap_vert, color: AppTheme.warning);

  factory StatusBadge.task(TaskStatus status) {
    switch (status) {
      case TaskStatus.active:
        return const StatusBadge(label: 'Active', icon: Icons.play_circle_outline, color: AppTheme.info);
      case TaskStatus.completed:
        return const StatusBadge(label: 'Completed', icon: Icons.check_circle, color: AppTheme.success);
      case TaskStatus.cancelled:
        return const StatusBadge(label: 'Cancelled', icon: Icons.cancel_outlined, color: AppTheme.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
