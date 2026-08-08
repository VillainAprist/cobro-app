import 'package:flutter/material.dart';
import '../core/constants/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status; // 'Pendiente', 'Parcial', 'Pagado', 'Vencido'

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData icon;
    String label = status;

    switch (status) {
      case 'Pagado':
        badgeColor = AppTheme.success;
        icon = Icons.check_circle_rounded;
        label = 'PAGADO';
        break;
      case 'Parcial':
        badgeColor = const Color(0xFF06B6D4); // Cyan Vibrante
        icon = Icons.pie_chart_rounded;
        label = 'PARCIAL';
        break;
      case 'Vencido':
        badgeColor = AppTheme.danger;
        icon = Icons.warning_amber_rounded;
        label = 'VENCIDO';
        break;
      case 'Pendiente':
      default:
        badgeColor = AppTheme.warning;
        icon = Icons.schedule_rounded;
        label = 'PENDIENTE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
