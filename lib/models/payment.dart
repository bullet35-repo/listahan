class PaymentRecord {
  final int? id;
  final int orderId;
  final double amount;
  final DateTime date;
  final String note;

  const PaymentRecord({
    this.id,
    required this.orderId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id'],
      orderId: map['orderId'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(map['date']),
      note: (map['note'] as String?) ?? '',
    );
  }

  PaymentRecord copyWith({
    int? id,
    int? orderId,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}
