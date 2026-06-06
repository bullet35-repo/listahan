import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';

enum EntryDateFilter { today, week, month }

class BackupPreview {
  final int entries;
  final int payments;
  final int types;

  const BackupPreview({
    required this.entries,
    required this.payments,
    required this.types,
  });
}

class BackupData {
  final List<OrderItem> orders;
  final List<PaymentRecord> payments;

  const BackupData({required this.orders, required this.payments});
}

class OrderProvider with ChangeNotifier {
  static const String _customTypesKey = 'custom_order_types';
  static const String _deletedDefaultTypesKey = 'deleted_default_order_types';

  static const List<String> defaultTypes = [
    'Bugasan',
    'Listasan',
    'Grocery',
    'Ulam',
    'Load',
    'Others',
  ];

  List<OrderItem> _orders = [];
  List<PaymentRecord> _payments = [];
  List<String> _customTypes = [];
  List<String> _deletedDefaultTypes = [];
  bool _isLoading = false;
  bool _typesLoaded = false;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _searchQuery = '';
  PaymentStatus? _paymentFilter;
  String? _typeFilter;
  EntryDateFilter _dateFilter = EntryDateFilter.month;

  List<OrderItem> get orders => _orders;
  List<PaymentRecord> get payments => _payments;
  PaymentStatus? get paymentFilter => _paymentFilter;
  String? get typeFilter => _typeFilter;
  String get searchQuery => _searchQuery;
  EntryDateFilter get dateFilter => _dateFilter;
  bool get isLoading => _isLoading;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  void setMonthYear(int month, int year) {
    _selectedMonth = month;
    _selectedYear = year;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void setPaymentFilter(PaymentStatus? filter) {
    _paymentFilter = filter;
    notifyListeners();
  }

  void setTypeFilter(String? filter) {
    _typeFilter = filter;
    notifyListeners();
  }

  void setDateFilter(EntryDateFilter filter) {
    _dateFilter = filter;
    notifyListeners();
  }

  bool _matchesDateFilter(OrderItem order) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case EntryDateFilter.today:
        return order.date.year == now.year &&
            order.date.month == now.month &&
            order.date.day == now.day;
      case EntryDateFilter.week:
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfWeek = startOfToday.subtract(
          Duration(days: startOfToday.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return !order.date.isBefore(startOfWeek) &&
            order.date.isBefore(endOfWeek);
      case EntryDateFilter.month:
        return order.date.year == _selectedYear &&
            order.date.month == _selectedMonth;
    }
  }

  List<String> get orderTypes {
    final visibleDefaultTypes = defaultTypes.where(
      (type) => !_deletedDefaultTypes.any(
        (deletedType) => deletedType.toLowerCase() == type.toLowerCase(),
      ),
    );
    final types = <String>{...visibleDefaultTypes, ..._customTypes};
    for (final order in _orders) {
      final type = order.type.trim();
      if (type.isNotEmpty) types.add(type);
    }
    return types.toList()..sort((a, b) => a.compareTo(b));
  }

  bool isDefaultType(String type) {
    return defaultTypes.any((t) => t.toLowerCase() == type.toLowerCase());
  }

  int orderCountForType(String type) {
    return _orders.where((order) => order.type == type).length;
  }

  List<PaymentRecord> paymentsForOrder(int orderId) {
    return _payments.where((payment) => payment.orderId == orderId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double paidTotalForOrder(int orderId) {
    return paymentsForOrder(
      orderId,
    ).fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double balanceForOrder(OrderItem order) {
    final orderId = order.id;
    final paid = orderId == null
        ? order.paidAmount
        : paidTotalForOrder(orderId);
    return (order.price - paid).clamp(0, order.price).toDouble();
  }

  Future<void> _saveCustomTypes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customTypesKey, _customTypes);
    await prefs.setStringList(_deletedDefaultTypesKey, _deletedDefaultTypes);
  }

  Future<void> _loadCustomTypes() async {
    if (_typesLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _customTypes = prefs.getStringList(_customTypesKey) ?? [];
    _deletedDefaultTypes = prefs.getStringList(_deletedDefaultTypesKey) ?? [];
    _typesLoaded = true;
  }

  Future<void> addOrderType(String rawType) async {
    final type = rawType.trim();
    if (type.isEmpty) return;

    final exists = orderTypes.any((t) => t.toLowerCase() == type.toLowerCase());
    _deletedDefaultTypes = _deletedDefaultTypes
        .where((deletedType) => deletedType.toLowerCase() != type.toLowerCase())
        .toList();
    if (!exists) {
      _customTypes = [..._customTypes, type]..sort((a, b) => a.compareTo(b));
    }
    await _saveCustomTypes();

    _typeFilter = orderTypes.firstWhere(
      (t) => t.toLowerCase() == type.toLowerCase(),
      orElse: () => type,
    );
    notifyListeners();
  }

  Future<void> renameOrderType(String oldType, String rawNewType) async {
    final newType = rawNewType.trim();
    if (oldType == newType || newType.isEmpty) return;

    final oldLower = oldType.toLowerCase();
    final newLower = newType.toLowerCase();
    final duplicate = orderTypes.any(
      (type) =>
          type.toLowerCase() == newLower && type.toLowerCase() != oldLower,
    );
    if (duplicate) return;

    final oldWasCustom = _customTypes.any((t) => t.toLowerCase() == oldLower);
    final oldWasDefault = isDefaultType(oldType);
    _customTypes = _customTypes
        .where((t) => t.toLowerCase() != oldLower)
        .toList();
    if (oldWasDefault) {
      _deletedDefaultTypes = {..._deletedDefaultTypes, oldType}.toList();
    }
    _deletedDefaultTypes = _deletedDefaultTypes
        .where((deletedType) => deletedType.toLowerCase() != newLower)
        .toList();
    if (!isDefaultType(newType) &&
        (oldWasCustom || oldWasDefault || orderCountForType(oldType) > 0)) {
      _customTypes = [..._customTypes, newType]..sort((a, b) => a.compareTo(b));
    }
    await _saveCustomTypes();

    await _dbHelper.updateOrderType(oldType, newType);
    _orders = _orders
        .map(
          (order) =>
              order.type == oldType ? order.copyWith(type: newType) : order,
        )
        .toList();
    if (_typeFilter == oldType) _typeFilter = newType;
    notifyListeners();
  }

  Future<void> deleteOrderType(String type) async {
    final remainingTypes = orderTypes.where((orderType) => orderType != type);
    if (remainingTypes.isEmpty) return;

    _customTypes = _customTypes
        .where((customType) => customType.toLowerCase() != type.toLowerCase())
        .toList();
    if (isDefaultType(type)) {
      _deletedDefaultTypes = {..._deletedDefaultTypes, type}.toList();
    }
    await _saveCustomTypes();

    if (orderCountForType(type) > 0) {
      final fallbackType = remainingTypes.first;
      await _dbHelper.updateOrderType(type, fallbackType);
      _orders = _orders
          .map(
            (order) =>
                order.type == type ? order.copyWith(type: fallbackType) : order,
          )
          .toList();
    }
    if (_typeFilter == type) _typeFilter = null;
    notifyListeners();
  }

  List<OrderItem> get filteredOrders {
    var list = _orders.where(_matchesDateFilter).toList();
    if (_searchQuery.isNotEmpty) {
      list = list.where((o) {
        final cust = o.customerName.toLowerCase();
        final item = o.itemName.toLowerCase();
        final type = o.type.toLowerCase();
        return cust.contains(_searchQuery) ||
            item.contains(_searchQuery) ||
            type.contains(_searchQuery);
      }).toList();
    }
    if (_paymentFilter != null) {
      list = list.where((o) => o.paymentStatus == _paymentFilter).toList();
    }
    if (_typeFilter != null) {
      list = list.where((o) => o.type == _typeFilter).toList();
    }
    list.sort((a, b) => b.date.compareTo(a.date)); // Newest first
    return list;
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCustomTypes();
      _orders = await _dbHelper.getOrders();
      _payments = await _dbHelper.getPayments();
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching orders: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOrder(OrderItem order) async {
    final id = await _dbHelper.insertOrder(order);
    if (order.paidAmount > 0) {
      await _dbHelper.insertPayment(
        PaymentRecord(
          orderId: id,
          amount: order.paidAmount,
          date: order.date,
          note: 'Initial payment',
        ),
      );
    }
    await fetchOrders();
  }

  Future<void> updateOrder(OrderItem order) async {
    await _dbHelper.updateOrder(order);
    await fetchOrders();
  }

  Future<void> deleteOrder(int id) async {
    await _dbHelper.deleteOrder(id);
    await fetchOrders();
  }

  BackupData parseBackupJson(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final orderRows = (decoded['orders'] as List? ?? [])
        .whereType<Map>()
        .map((row) => OrderItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    final paymentRows = (decoded['payments'] as List? ?? [])
        .whereType<Map>()
        .map((row) => PaymentRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    return BackupData(orders: orderRows, payments: paymentRows);
  }

  BackupPreview previewBackupJson(String rawJson) {
    final backup = parseBackupJson(rawJson);
    return BackupPreview(
      entries: backup.orders.length,
      payments: backup.payments.length,
      types: backup.orders.map((order) => order.type).toSet().length,
    );
  }

  Future<void> restoreBackupJson(String rawJson) async {
    final backup = parseBackupJson(rawJson);
    await _dbHelper.replaceBackup(
      orders: backup.orders,
      payments: backup.payments,
    );
    await fetchOrders();
  }

  Future<void> addPayment({
    required OrderItem order,
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    final orderId = order.id;
    if (orderId == null || amount <= 0) return;
    final balance = balanceForOrder(order);
    if (amount > balance) {
      throw ArgumentError('Payment cannot exceed remaining balance.');
    }
    await _dbHelper.insertPayment(
      PaymentRecord(
        orderId: orderId,
        amount: amount,
        date: date ?? DateTime.now(),
        note: note,
      ),
    );
    await _syncOrderPayment(order);
    await fetchOrders();
  }

  Future<void> updatePayment({
    required PaymentRecord payment,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    if (payment.id == null || amount <= 0) return;
    final order = _orders.firstWhere((order) => order.id == payment.orderId);
    final paidWithoutThis = paidTotalForOrder(order.id!) - payment.amount;
    final maxAmount = (order.price - paidWithoutThis).clamp(0, order.price);
    if (amount > maxAmount) {
      throw ArgumentError('Payment cannot exceed remaining balance.');
    }
    await _dbHelper.updatePayment(
      payment.copyWith(amount: amount, date: date, note: note),
    );
    await _syncOrderPayment(order);
    await fetchOrders();
  }

  Future<void> deletePayment(PaymentRecord payment) async {
    await _dbHelper.deletePayment(payment.id!);
    final order = _orders.firstWhere((order) => order.id == payment.orderId);
    await _syncOrderPayment(order);
    await fetchOrders();
  }

  Future<void> _syncOrderPayment(OrderItem order) async {
    final orderId = order.id;
    if (orderId == null) return;
    final freshPayments = await _dbHelper.getPayments();
    final paid = freshPayments
        .where((payment) => payment.orderId == orderId)
        .fold(0.0, (sum, payment) => sum + payment.amount);
    final status = paid <= 0
        ? PaymentStatus.unpaid
        : paid >= order.price
        ? PaymentStatus.paid
        : PaymentStatus.partial;
    await _dbHelper.updateOrder(
      order.copyWith(
        paidAmount: paid.clamp(0, order.price),
        paymentStatus: status,
      ),
    );
  }

  List<OrderItem> ordersForMonth(int month, int year, {String? type}) {
    return _orders
        .where(
          (o) =>
              o.date.month == month &&
              o.date.year == year &&
              (type == null || o.type == type),
        )
        .toList();
  }

  List<OrderItem> get summaryOrdersThisMonth {
    return _orders
        .where(_matchesDateFilter)
        .where((order) => _typeFilter == null || order.type == _typeFilter)
        .toList();
  }

  double get totalIncomeThisMonth {
    return summaryOrdersThisMonth.fold(
      0.0,
      (sum, item) => sum + item.commission,
    );
  }

  double get totalSalesThisMonth {
    return summaryOrdersThisMonth.fold(0.0, (sum, item) => sum + item.price);
  }

  int get totalOrdersThisMonth {
    return summaryOrdersThisMonth.length;
  }

  double salesForMonth(int month, int year, {String? type}) {
    return ordersForMonth(
      month,
      year,
      type: type,
    ).fold(0.0, (s, o) => s + o.price);
  }

  double commissionForMonth(int month, int year, {String? type}) {
    return ordersForMonth(
      month,
      year,
      type: type,
    ).fold(0.0, (s, o) => s + o.commission);
  }

  List<OrderItem> get unpaidOrders =>
      _orders
          .where((o) => o.paymentStatus != PaymentStatus.paid && o.balance > 0)
          .toList()
        ..sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));

  List<OrderItem> get upcomingOrOverdueOrders {
    final list = _orders
        .where(
          (o) =>
              o.paymentStatus != PaymentStatus.paid &&
              o.balance > 0 &&
              o.dueDate != null,
        )
        .toList();
    list.sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));
    return list;
  }

  double customerBalance(String customerName) {
    return _orders
        .where((o) => o.customerName == customerName)
        .fold(0.0, (sum, o) => sum + o.balance);
  }

  /// Returns sales totals for the last [months] months.
  /// The returned list is ordered from oldest to newest.
  List<double> salesSeries({int months = 6, String? type}) {
    final now = DateTime.now();
    final series = List<double>.filled(months, 0.0);
    for (final o in _orders) {
      if (type != null && o.type != type) continue;
      final diff = (now.year - o.date.year) * 12 + (now.month - o.date.month);
      if (diff >= 0 && diff < months) {
        final idx = months - 1 - diff; // oldest -> index 0
        series[idx] += o.price;
      }
    }
    return series;
  }

  /// Returns commission totals for the last [months] months.
  /// The returned list is ordered from oldest to newest.
  List<double> commissionSeries({int months = 6, String? type}) {
    final now = DateTime.now();
    final series = List<double>.filled(months, 0.0);
    for (final o in _orders) {
      if (type != null && o.type != type) continue;
      final diff = (now.year - o.date.year) * 12 + (now.month - o.date.month);
      if (diff >= 0 && diff < months) {
        final idx = months - 1 - diff;
        series[idx] += o.commission;
      }
    }
    return series;
  }
}
