import 'package:intl/intl.dart';

class AppFormatters {
  static String formatCurrency(double amount, [String symbol = 'S/']) {
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateReadable(DateTime date) {
    return DateFormat('dd MMM, yyyy', 'es').format(date);
  }
}
