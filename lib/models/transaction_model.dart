class TransactionModel {
  final String id;
  final String debtorName;
  final double amount;
  final String currency;
  final DateTime date;
  final String type; // 'ABONO' (+) o 'PRESTAMO' (-)
  final String? note;
  final int loanId;
  final double remainingBalance;

  TransactionModel({
    required this.id,
    required this.debtorName,
    required this.amount,
    required this.currency,
    required this.date,
    required this.type,
    this.note,
    required this.loanId,
    required this.remainingBalance,
  });

  bool get isAbono => type == 'ABONO';
}
