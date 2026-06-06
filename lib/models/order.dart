enum PaymentStatus { unpaid, partial, paid }

class OrderItem {
  final int? id;
  final String customerName;
  final String itemName;
  final String type;
  final double price;
  final double commission;
  final DateTime date;
  final PaymentStatus paymentStatus;
  final DateTime? dueDate;
  final double paidAmount;

  OrderItem({
    this.id,
    required this.customerName,
    required this.itemName,
    this.type = 'Bugasan',
    required this.price,
    required this.commission,
    required this.date,
    this.paymentStatus = PaymentStatus.unpaid,
    this.dueDate,
    this.paidAmount = 0,
  });

  double get balance => price - paidAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'itemName': itemName,
      'type': type,
      'price': price,
      'commission': commission,
      'date': date.toIso8601String(),
      'paymentStatus': paymentStatus.name,
      'dueDate': dueDate?.toIso8601String(),
      'paidAmount': paidAmount,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    PaymentStatus status = PaymentStatus.unpaid;
    if (map['paymentStatus'] != null) {
      status = PaymentStatus.values.firstWhere(
        (e) => e.name == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      );
    }
    return OrderItem(
      id: map['id'],
      customerName: map['customerName'],
      itemName: map['itemName'],
      type: (map['type'] as String?)?.trim().isNotEmpty == true
          ? (map['type'] as String).trim()
          : 'Bugasan',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      commission: (map['commission'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(map['date']),
      paymentStatus: status,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  OrderItem copyWith({
    int? id,
    String? customerName,
    String? itemName,
    String? type,
    double? price,
    double? commission,
    DateTime? date,
    PaymentStatus? paymentStatus,
    DateTime? dueDate,
    double? paidAmount,
  }) {
    return OrderItem(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      itemName: itemName ?? this.itemName,
      type: type ?? this.type,
      price: price ?? this.price,
      commission: commission ?? this.commission,
      date: date ?? this.date,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      dueDate: dueDate ?? this.dueDate,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}
