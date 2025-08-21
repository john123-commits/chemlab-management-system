import 'package:intl/intl.dart';

class DateHelper {
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTimeWithTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  static int daysUntil(DateTime date) {
    return date.difference(DateTime.now()).inDays;
  }
}

class NumberHelper {
  static String formatQuantity(double quantity) {
    return quantity
        .toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2);
  }
}
