import 'payment_model.dart';

class LoanModel {
  final int? id;
  final String debtorName;
  final double amount;
  final String currency; // 'S/' o '$'
  final DateTime borrowDate;
  final DateTime dueDate;
  final DateTime? paidDate; // Fecha en que se completó el pago
  final String status; // 'Pendiente', 'Parcial', 'Pagado', 'Vencido'
  final String? notes;
  final String? phone;
  final String paymentFrequency; // 'Fecha Única', 'Diario', 'Semanal', 'Quincenal', 'Mensual'
  final double interestValue;
  final String interestType; // 'Porcentaje %' o 'Monto Fijo'
  final List<PaymentModel> payments;

  LoanModel({
    this.id,
    required this.debtorName,
    required this.amount,
    this.currency = 'S/',
    required this.borrowDate,
    required this.dueDate,
    this.paidDate,
    this.status = 'Pendiente',
    this.notes,
    this.phone,
    this.paymentFrequency = 'Fecha Única',
    this.interestValue = 0.0,
    this.interestType = 'Monto Fijo',
    this.payments = const [],
  });

  double get calculatedInterest {
    if (interestValue <= 0) return 0.0;
    if (interestType == 'Porcentaje %') {
      return (amount * interestValue) / 100.0;
    }
    return interestValue;
  }

  double get totalWithInterest => amount + calculatedInterest;

  double get totalPaid {
    return payments.fold(0.0, (sum, p) => sum + p.amount);
  }

  double get remainingBalance {
    final balance = totalWithInterest - totalPaid;
    return balance < 0 ? 0.0 : balance;
  }

  String get dynamicStatus {
    if (status == 'Pagado' || remainingBalance <= 0) return 'Pagado';
    if (totalPaid > 0) return 'Parcial';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (today.isAfter(due)) {
      return 'Vencido';
    }
    return status;
  }

  bool get isPaid => dynamicStatus == 'Pagado';
  bool get isPartial => dynamicStatus == 'Parcial';
  bool get isOverdue => dynamicStatus == 'Vencido';
  bool get isPending => dynamicStatus == 'Pendiente';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'debtorName': debtorName,
      'amount': amount,
      'currency': currency,
      'borrowDate': borrowDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'phone': phone,
      'paymentFrequency': paymentFrequency,
      'interestValue': interestValue,
      'interestType': interestType,
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map, {List<PaymentModel> payments = const []}) {
    return LoanModel(
      id: map['id'] as int?,
      debtorName: map['debtorName'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'S/',
      borrowDate: DateTime.parse(map['borrowDate'] as String),
      dueDate: DateTime.parse(map['dueDate'] as String),
      paidDate: map['paidDate'] != null ? DateTime.parse(map['paidDate'] as String) : null,
      status: map['status'] as String? ?? 'Pendiente',
      notes: map['notes'] as String?,
      phone: map['phone'] as String?,
      paymentFrequency: map['paymentFrequency'] as String? ?? 'Fecha Única',
      interestValue: (map['interestValue'] as num?)?.toDouble() ?? 0.0,
      interestType: map['interestType'] as String? ?? 'Monto Fijo',
      payments: payments,
    );
  }

  Map<String, dynamic> toJson() {
    final map = toMap();
    map['payments'] = payments.map((p) => p.toJson()).toList();
    return map;
  }

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    final paymentsList = (json['payments'] as List<dynamic>?)
            ?.map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];
    return LoanModel.fromMap(json, payments: paymentsList);
  }

  LoanModel copyWith({
    int? id,
    String? debtorName,
    double? amount,
    String? currency,
    DateTime? borrowDate,
    DateTime? dueDate,
    DateTime? paidDate,
    String? status,
    String? notes,
    String? phone,
    String? paymentFrequency,
    double? interestValue,
    String? interestType,
    List<PaymentModel>? payments,
  }) {
    return LoanModel(
      id: id ?? this.id,
      debtorName: debtorName ?? this.debtorName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      borrowDate: borrowDate ?? this.borrowDate,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      phone: phone ?? this.phone,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      interestValue: interestValue ?? this.interestValue,
      interestType: interestType ?? this.interestType,
      payments: payments ?? this.payments,
    );
  }
}
