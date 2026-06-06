import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../database/database_helper.dart';

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
  List<String> _customTypes = [];
  List<String> _deletedDefaultTypes = [];
  bool _isLoading = false;
  bool _typesLoaded = false;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _searchQuery = '';
  PaymentStatus? _paymentFilter;
  String? _typeFilter;

  List<OrderItem> get orders => _orders;
  PaymentStatus? get paymentFilter => _paymentFilter;
  String? get typeFilter => _typeFilter;
  String get searchQuery => _searchQuery;
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
    var list = _orders
        .where(
          (o) => o.date.year == _selectedYear && o.date.month == _selectedMonth,
        )
        .toList();
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

      // Seed sample data in debug mode when database is empty to demo charts
      if (_orders.isEmpty && kDebugMode) {
        final now = DateTime.now();
        final samples = [
          OrderItem(
            customerName: 'Alice',
            itemName: 'Shirt',
            price: 500,
            commission: 50,
            date: now.subtract(const Duration(days: 40)),
            paymentStatus: PaymentStatus.paid,
            paidAmount: 500,
          ),
          OrderItem(
            customerName: 'Bob',
            itemName: 'Pants',
            price: 1200,
            commission: 120,
            date: now.subtract(const Duration(days: 25)),
            paymentStatus: PaymentStatus.partial,
            paidAmount: 600,
          ),
          OrderItem(
            customerName: 'Cathy',
            itemName: 'Shoes',
            price: 850,
            commission: 85,
            date: now.subtract(const Duration(days: 10)),
            paymentStatus: PaymentStatus.unpaid,
            paidAmount: 0,
          ),
          OrderItem(
            customerName: 'Dave',
            itemName: 'Hat',
            price: 300,
            commission: 30,
            date: now.subtract(const Duration(days: 3)),
            paymentStatus: PaymentStatus.paid,
            paidAmount: 300,
          ),
        ];
        for (final s in samples) {
          await _dbHelper.insertOrder(s);
        }
        _orders = await _dbHelper.getOrders();
      }
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
    await _dbHelper.insertOrder(order);
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
    return ordersForMonth(_selectedMonth, _selectedYear, type: _typeFilter);
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
