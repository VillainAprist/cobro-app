import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';

class ReceiptModal extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptModal({super.key, required this.transaction});

  Future<void> _shareWhatsApp(BuildContext context) async {
    final formattedAmount = AppFormatters.formatCurrency(transaction.amount, transaction.currency);
    final formattedDate = AppFormatters.formatDate(transaction.date);
    final isAbono = transaction.isAbono;

    final typeText = isAbono ? 'COMPROBANTE DE ABONO RECIBIDO' : 'CONSTANCIA DE PRÉSTAMO OTORGADO';
    final remainingFormatted = AppFormatters.formatCurrency(transaction.remainingBalance, transaction.currency);

    final text = Uri.encodeComponent(
      '🧾 *$typeText*\n\n'
      '👤 *Cliente:* ${transaction.debtorName}\n'
      '💵 *Monto:* $formattedAmount\n'
      '📅 *Fecha:* $formattedDate\n'
      '📌 *Nota:* ${transaction.note ?? 'Sin nota'}\n'
      '⚖️ *Saldo Restante Pendiente:* $remainingFormatted\n\n'
      '¡Gracias por preferir nuestro servicio de préstamos!',
    );

    final url = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAbono = transaction.isAbono;
    final color = isAbono ? AppTheme.success : AppTheme.primaryAccent;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CABECERA VAUCHER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              isAbono ? Icons.check_circle_rounded : Icons.payments_rounded,
              color: color,
              size: 44,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            isAbono ? '¡Abono Registrado!' : 'Préstamo Registrado',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAbono ? 'Constancia digital de cobro' : 'Detalle de entrega de préstamo',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // TARJETA TIPO VAUCHER YAPE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _buildReceiptLine('Deudor / Prestatario', transaction.debtorName, isBold: true),
                const Divider(color: Colors.white10, height: 16),
                _buildReceiptLine('Tipo de Operación', isAbono ? 'Cobro (+) Abono' : 'Préstamo (-) Entregado'),
                const SizedBox(height: 8),
                _buildReceiptLine('Monto Transacción', '${isAbono ? '+' : '-'} ${AppFormatters.formatCurrency(transaction.amount, transaction.currency)}', color: color, isBold: true),
                const SizedBox(height: 8),
                _buildReceiptLine('Fecha', AppFormatters.formatDate(transaction.date)),
                if (transaction.note != null) ...[
                  const SizedBox(height: 8),
                  _buildReceiptLine('Nota', transaction.note!),
                ],
                const Divider(color: Colors.white10, height: 16),
                _buildReceiptLine('Saldo Restante Actual', AppFormatters.formatCurrency(transaction.remainingBalance, transaction.currency), color: AppTheme.warning, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // BOTONES DE ACCIÓN
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  label: const Text('Cerrar', style: TextStyle(color: AppTheme.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareWhatsApp(context),
                  icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                  label: const Text('Enviar WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptLine(String label, String val, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color ?? AppTheme.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 14 : 12.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
