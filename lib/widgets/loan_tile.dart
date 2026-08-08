import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_theme.dart';
import '../core/services/database_helper.dart';
import '../core/utils/formatters.dart';
import '../models/loan_model.dart';
import '../models/payment_model.dart';
import 'status_badge.dart';

class LoanTile extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback onTogglePaid;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback onPaymentAdded;

  const LoanTile({
    super.key,
    required this.loan,
    required this.onTogglePaid,
    required this.onDelete,
    this.onEdit,
    required this.onPaymentAdded,
  });

  Future<void> _openWhatsApp(BuildContext context) async {
    if (loan.phone == null || loan.phone!.trim().isEmpty) return;
    final cleanPhone = loan.phone!.replaceAll(RegExp(r'\D'), '');
    final remainingFormatted = AppFormatters.formatCurrency(loan.remainingBalance, loan.currency);
    final dateFormatted = AppFormatters.formatDate(loan.dueDate);
    final message = Uri.encodeComponent(
      'Hola ${loan.debtorName}, te escribo para recordarte el cobro del saldo pendiente por $remainingFormatted con fecha de vencimiento $dateFormatted. ¡Gracias!',
    );

    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  void _showAddPaymentModal(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Registrar Abono - ${loan.debtorName}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Resumen de Saldo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total Deuda', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Text(
                              AppFormatters.formatCurrency(loan.totalWithInterest, loan.currency),
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Abonado', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Text(
                              AppFormatters.formatCurrency(loan.totalPaid, loan.currency),
                              style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Saldo Restante', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Text(
                              AppFormatters.formatCurrency(loan.remainingBalance, loan.currency),
                              style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Monto a abonar
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Monto a Abonar (${loan.currency}) *',
                      hintText: 'Ej: 100.00',
                      prefixIcon: const Icon(Icons.payments_outlined, color: AppTheme.success),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fecha del abono
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() => paymentDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha en que hizo el abono',
                        prefixIcon: Icon(Icons.calendar_month_outlined, color: AppTheme.primaryAccent),
                      ),
                      child: Text(
                        AppFormatters.formatDate(paymentDate),
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nota opcional
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nota del abono (Opcional)',
                      hintText: 'Ej: Pago adelantado quincena',
                      prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón Guardar Abono
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final val = double.tryParse(amountController.text);
                        if (val == null || val <= 0) return;

                        final payment = PaymentModel(
                          loanId: loan.id!,
                          amount: val,
                          date: paymentDate,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );

                        await DatabaseHelper.instance.insertPayment(payment);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        onPaymentAdded();
                      },
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('Guardar Abono', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // HISTORIAL DE ABONOS REALIZADOS
                  if (loan.payments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Historial de Abonos:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: loan.payments.length,
                        itemBuilder: (ctx, i) {
                          final p = loan.payments[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppFormatters.formatDate(p.date), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                    if (p.note != null) Text(p.note!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '+ ${AppFormatters.formatCurrency(p.amount, loan.currency)}',
                                      style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 16),
                                      onPressed: () async {
                                        if (p.id != null) {
                                          await DatabaseHelper.instance.deletePayment(p.id!);
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                          onPaymentAdded();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = loan.dynamicStatus;
    final isPaid = status == 'Pagado';
    final isPartial = status == 'Parcial';

    final progress = loan.totalWithInterest > 0
        ? (loan.totalPaid / loan.totalWithInterest).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isPaid
                ? AppTheme.success.withValues(alpha: 0.05)
                : (loan.isOverdue
                    ? AppTheme.danger.withValues(alpha: 0.1)
                    : Colors.black12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isPaid
              ? AppTheme.success.withValues(alpha: 0.35)
              : (isPartial
                  ? const Color(0xFF06B6D4).withValues(alpha: 0.45)
                  : (loan.isOverdue
                      ? AppTheme.danger.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.08))),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: isPaid
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : AppTheme.primaryAccent.withValues(alpha: 0.2),
                  child: Text(
                    loan.debtorName.isNotEmpty ? loan.debtorName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isPaid ? AppTheme.success : AppTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.debtorName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Prestado: ${AppFormatters.formatDate(loan.borrowDate)}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      if (loan.paymentFrequency != 'Fecha Única') ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            loan.paymentFrequency.split(' ').first,
                            style: const TextStyle(
                              color: AppTheme.warning,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: status),
              ],
            ),

            // BARRA DE PROGRESO DE PAGOS PARCIALES
            if (isPartial) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Abonado: ${AppFormatters.formatCurrency(loan.totalPaid, loan.currency)}',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% cubierto',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],

            const Divider(color: Colors.white10, height: 24),

            // MONTO Y FECHAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPartial ? 'Saldo Restante' : 'Monto a Cobrar',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppFormatters.formatCurrency(
                            isPartial ? loan.remainingBalance : loan.totalWithInterest,
                            loan.currency,
                          ),
                          style: TextStyle(
                            color: isPaid
                                ? AppTheme.success
                                : (isPartial ? AppTheme.warning : AppTheme.textPrimary),
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            decoration: isPaid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (loan.calculatedInterest > 0)
                        Text(
                          '+ ${AppFormatters.formatCurrency(loan.calculatedInterest, loan.currency)} interés',
                          style: const TextStyle(color: AppTheme.warning, fontSize: 10.5, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_outlined, size: 13, color: AppTheme.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'Fecha de Cobro',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.formatDate(loan.dueDate),
                      style: TextStyle(
                        color: loan.isOverdue && !isPaid
                            ? AppTheme.danger
                            : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // TELÉFONO & BOTÓN WHATSAPP
            if (loan.phone != null && loan.phone!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android_outlined, size: 15, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loan.phone!,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _openWhatsApp(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.success, size: 14),
                            SizedBox(width: 4),
                            Text('WhatsApp', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (loan.notes != null && loan.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nota: ${loan.notes}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // BOTONES DE ACCIÓN RÁPIDA (CON WRAP ANTI-OVERFLOW)
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                  tooltip: 'Eliminar préstamo',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                    tooltip: 'Editar préstamo',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),

                // BOTÓN ABONAR
                if (!isPaid)
                  OutlinedButton.icon(
                    onPressed: () => _showAddPaymentModal(context),
                    icon: const Icon(Icons.payments_outlined, size: 15, color: Color(0xFF06B6D4)),
                    label: const Text('Abonar', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF06B6D4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                ElevatedButton.icon(
                  onPressed: onTogglePaid,
                  icon: Icon(
                    isPaid ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(isPaid ? 'Desmarcar' : 'Cobrado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid ? AppTheme.cardBgLight : AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
