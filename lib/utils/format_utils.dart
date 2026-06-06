import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

final _compactCurrencyFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 0,
);

String formatCurrency(double amount, {bool compact = false}) {
  return (compact ? _compactCurrencyFormat : _currencyFormat).format(amount);
}
