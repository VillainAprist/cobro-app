import 'package:flutter/material.dart';
import '../core/constants/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/loan_model.dart';

class LoanFormScreen extends StatefulWidget {
  final LoanModel? initialLoan;

  const LoanFormScreen({super.key, this.initialLoan});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _debtorController;
  late TextEditingController _amountController;
  late TextEditingController _phoneController;
  late TextEditingController _interestController;
  late TextEditingController _notesController;

  String _currency = 'S/';
  DateTime _borrowDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  String _status = 'Pendiente';
  String _paymentFrequency = 'Fecha Única';
  String _interestType = 'Monto Fijo';

  final List<String> _frequencyOptions = [
    'Fecha Única',
    'Diario (Cada 1 día)',
    'Semanal (Cada 7 días)',
    'Quincenal (Cada 15 días)',
    'Mensual (Cada 1 mes)',
  ];

  @override
  void initState() {
    super.initState();
    final loan = widget.initialLoan;
    _debtorController = TextEditingController(text: loan?.debtorName ?? '');
    _amountController = TextEditingController(
      text: loan != null ? loan.amount.toStringAsFixed(2) : '',
    );
    _phoneController = TextEditingController(text: loan?.phone ?? '');
    _interestController = TextEditingController(
      text: loan != null && loan.interestValue > 0 ? loan.interestValue.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: loan?.notes ?? '');

    if (loan != null) {
      _currency = loan.currency;
      _borrowDate = loan.borrowDate;
      _dueDate = loan.dueDate;
      _status = loan.status;
      _interestType = loan.interestType;
      _paymentFrequency = _frequencyOptions.contains(loan.paymentFrequency)
          ? loan.paymentFrequency
          : 'Fecha Única';
    }
  }

  @override
  void dispose() {
    _debtorController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isBorrowDate) async {
    final initial = isBorrowDate ? _borrowDate : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryAccent,
              surface: AppTheme.cardBg,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isBorrowDate) {
          _borrowDate = picked;
          _recalculateDueDate();
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _recalculateDueDate() {
    switch (_paymentFrequency) {
      case 'Diario (Cada 1 día)':
        _dueDate = _borrowDate.add(const Duration(days: 1));
        break;
      case 'Semanal (Cada 7 días)':
        _dueDate = _borrowDate.add(const Duration(days: 7));
        break;
      case 'Quincenal (Cada 15 días)':
        _dueDate = _borrowDate.add(const Duration(days: 15));
        break;
      case 'Mensual (Cada 1 mes)':
        _dueDate = DateTime(_borrowDate.year, _borrowDate.month + 1, _borrowDate.day);
        break;
      case 'Fecha Única':
      default:
        if (_dueDate.isBefore(_borrowDate)) {
          _dueDate = _borrowDate.add(const Duration(days: 15));
        }
        break;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final interest = double.tryParse(_interestController.text) ?? 0.0;

      final loan = LoanModel(
        id: widget.initialLoan?.id,
        debtorName: _debtorController.text.trim(),
        amount: amount,
        currency: _currency,
        borrowDate: _borrowDate,
        dueDate: _dueDate,
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        paymentFrequency: _paymentFrequency,
        interestValue: interest,
        interestType: _interestType,
        payments: widget.initialLoan?.payments ?? [],
      );

      Navigator.of(context).pop(loan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialLoan != null;

    final baseAmount = double.tryParse(_amountController.text) ?? 0.0;
    final interestVal = double.tryParse(_interestController.text) ?? 0.0;
    double calcInterest = 0.0;
    if (interestVal > 0) {
      calcInterest = _interestType == 'Porcentaje %'
          ? (baseAmount * interestVal) / 100.0
          : interestVal;
    }
    final totalPreview = baseAmount + calcInterest;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Editar Préstamo' : 'Registrar Nuevo Préstamo',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Nombre del Deudor
              TextFormField(
                controller: _debtorController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombre del Prestatario / Deudor *',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryAccent),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre de la persona';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Teléfono / WhatsApp (Opcional)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Teléfono / WhatsApp (Opcional)',
                  hintText: 'Ej: 987654321',
                  prefixIcon: Icon(Icons.phone_android_outlined, color: AppTheme.success),
                ),
              ),
              const SizedBox(height: 16),

              // Monto y Moneda
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Monto Prestado *',
                        prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryAccent),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el monto';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      dropdownColor: AppTheme.cardBg,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Moneda',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'S/', child: Text('Soles (S/)')),
                        DropdownMenuItem(value: '\$', child: Text('Dólares (\$)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _currency = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Intereses (Opcional)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _interestController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Interés / Ganancia (Opcional)',
                        prefixIcon: Icon(Icons.percent_rounded, color: AppTheme.warning),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _interestType,
                      dropdownColor: AppTheme.cardBg,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Monto Fijo', child: Text('Fijo (Monto)')),
                        DropdownMenuItem(value: 'Porcentaje %', child: Text('Porcentaje %')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _interestType = val);
                      },
                    ),
                  ),
                ],
              ),
              if (calcInterest > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBgLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a Cobrar (Capital + Interés):',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      Text(
                        AppFormatters.formatCurrency(totalPreview, _currency),
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Frecuencia de Cobro
              DropdownButtonFormField<String>(
                initialValue: _paymentFrequency,
                dropdownColor: AppTheme.cardBg,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Frecuencia de Cobro',
                  prefixIcon: Icon(Icons.repeat_rounded, color: AppTheme.warning),
                ),
                items: _frequencyOptions.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _paymentFrequency = val;
                      _recalculateDueDate();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Fechas (Préstamo y Cobro)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha Préstamo',
                          prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryAccent, size: 20),
                        ),
                        child: Text(
                          AppFormatters.formatDate(_borrowDate),
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de Cobro',
                          prefixIcon: Icon(Icons.event, color: AppTheme.warning, size: 20),
                        ),
                        child: Text(
                          AppFormatters.formatDate(_dueDate),
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notas opcionales
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notas adicionales (Opcional)',
                  prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    isEditing ? 'Actualizar Préstamo' : 'Guardar Préstamo',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
