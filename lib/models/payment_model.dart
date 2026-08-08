class PaymentModel {
  final int? id;
  final int loanId;
  final double amount;
  final DateTime date;
  final String? note;

  PaymentModel({
    this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'loanId': loanId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int?,
      loanId: map['loanId'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel.fromMap(json);
}
