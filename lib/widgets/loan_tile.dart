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

  void _showLoanDetailsModal(BuildContext context) {
    final status = loan.dynamicStatus;
    final isPaid = status == 'Pagado';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isPaid
                                ? AppTheme.success.withValues(alpha: 0.2)
                                : AppTheme.primaryAccent.withValues(alpha: 0.2),
                            child: Text(
                              loan.debtorName.isNotEmpty ? loan.debtorName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: isPaid ? AppTheme.success : AppTheme.primaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (loan.phone != null && loan.phone!.isNotEmpty)
                                  Text(
                                    'Tel: ${loan.phone}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fecha de Préstamo:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          Text(AppFormatters.formatDate(loan.borrowDate), style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fecha Límite de Cobro:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          Text(AppFormatters.formatDate(loan.dueDate), style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                      ),
                      if (isPaid && loan.paidDate != null) ...[
                        const Divider(color: Colors.white10, height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.success, size: 14),
                                SizedBox(width: 4),
                                Text('Fecha en que se Pagó:', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Text(
                              AppFormatters.formatDate(loan.paidDate!),
                              style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Desglose Financiero:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Monto Inicial Prestado', AppFormatters.formatCurrency(loan.amount, loan.currency)),
                      if (loan.calculatedInterest > 0)
                        _buildDetailRow('Interés / Ganancia', '+ ${AppFormatters.formatCurrency(loan.calculatedInterest, loan.currency)}', color: AppTheme.warning),
                      const Divider(color: Colors.white10, height: 12),
                      _buildDetailRow('Total a Cobrar', AppFormatters.formatCurrency(loan.totalWithInterest, loan.currency), isBold: true),
                      _buildDetailRow('Total Abonado Hasta Ahora', AppFormatters.formatCurrency(loan.totalPaid, loan.currency), color: AppTheme.success),
                      _buildDetailRow('Saldo Restante Pendiente', AppFormatters.formatCurrency(loan.remainingBalance, loan.currency), color: isPaid ? AppTheme.success : AppTheme.warning, isBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Historial de Fechas de Abono:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text('${loan.payments.length} abono(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 6),

                if (loan.payments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('No se han registrado abonos parciales aún.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
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
                            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available, color: AppTheme.success, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Abonado el ${AppFormatters.formatDate(p.date)}',
                                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  if (p.note != null && p.note!.isNotEmpty)
                                    Text('Nota: ${p.note}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                                ],
                              ),
                              Text(
                                '+ ${AppFormatters.formatCurrency(p.amount, loan.currency)}',
                                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBgLight),
                    child: const Text('Cerrar Detalles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppTheme.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 13 : 12,
            ),
          ),
        ],
      ),
    );
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
                            fontSize: 17,
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
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total Deuda', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5)),
                            Text(
                              AppFormatters.formatCurrency(loan.totalWithInterest, loan.currency),
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Abonado', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5)),
                            Text(
                              AppFormatters.formatCurrency(loan.totalPaid, loan.currency),
                              style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Saldo Restante', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5)),
                            Text(
                              AppFormatters.formatCurrency(loan.remainingBalance, loan.currency),
                              style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 10),

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
                  const SizedBox(height: 10),

                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nota del abono (Opcional)',
                      hintText: 'Ej: Pago adelantado quincena',
                      prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
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

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('🎉 ¡Abono de ${AppFormatters.formatCurrency(val, loan.currency)} registrado!'),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        onPaymentAdded();
                      },
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('Guardar Abono', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
    final dateStr = AppFormatters.formatDate(loan.dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? AppTheme.success.withValues(alpha: 0.3)
              : (isPartial
                  ? const Color(0xFF06B6D4).withValues(alpha: 0.35)
                  : (loan.isOverdue
                      ? AppTheme.danger.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.07))),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showLoanDetailsModal(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // AVATAR INICIAL
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isPaid
                      ? AppTheme.success.withValues(alpha: 0.18)
                      : AppTheme.primaryAccent.withValues(alpha: 0.18),
                  child: Text(
                    loan.debtorName.isNotEmpty ? loan.debtorName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isPaid ? AppTheme.success : AppTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // NOMBRE DEUDOR (LINEA PROPIA PARA QUE NUNCA SE RECORTE) + FECHA EN SUB-TITULO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.debtorName.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 11,
                            color: loan.isOverdue && !isPaid ? AppTheme.danger : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: loan.isOverdue && !isPaid ? AppTheme.danger : AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (loan.paymentFrequency != 'Fecha Única') ...[
                            const Text(' • ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Text(
                              loan.paymentFrequency.split(' ').first,
                              style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // MONTO Y ACCIONES RÁPIDAS
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppFormatters.formatCurrency(
                            isPartial ? loan.remainingBalance : loan.totalWithInterest,
                            loan.currency,
                          ),
                          style: TextStyle(
                            color: isPaid
                                ? AppTheme.success
                                : (isPartial ? AppTheme.warning : AppTheme.textPrimary),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: isPaid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // BOTONES DE ACCIÓN RÁPIDA COMPACTOS
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loan.phone != null && loan.phone!.isNotEmpty)
                          InkWell(
                            onTap: () => _openWhatsApp(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.success, size: 16),
                            ),
                          ),
                        if (!isPaid)
                          InkWell(
                            onTap: () => _showAddPaymentModal(context),
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                              ),
                              child: const Text('Abonar', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        InkWell(
                          onTap: onTogglePaid,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid ? AppTheme.cardBgLight : AppTheme.success,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPaid ? 'Desmarcar' : 'Cobrado',
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
