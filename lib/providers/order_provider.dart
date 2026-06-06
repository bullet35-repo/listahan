import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../database/database_helper.dart';

class OrderProvider with ChangeNotifier {
  List<OrderItem> _orders = [];
  bool _isLoading = false;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _searchQuery = '';
  PaymentStatus? _paymentFilter;

  List<OrderItem> get orders => _orders;
  PaymentStatus? get paymentFilter => _paymentFilter;
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
        return cust.contains(_searchQuery) || item.contains(_searchQuery);
      }).toList();
    }
    if (_paymentFilter != null) {
      list = list.where((o) => o.paymentStatus == _paymentFilter).toList();
    }
    list.sort((a, b) => b.date.compareTo(a.date)); // Newest first
    return list;
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders = await _dbHelper.getOrders();
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

  double get totalIncomeThisMonth {
    return filteredOrders.fold(0.0, (sum, item) => sum + item.commission);
  }

  double get totalSalesThisMonth {
    return filteredOrders.fold(0.0, (sum, item) => sum + item.price);
  }

  int get totalOrdersThisMonth {
    return filteredOrders.length;
  }

  List<OrderItem> ordersForMonth(int month, int year) {
    return _orders
        .where((o) => o.date.month == month && o.date.year == year)
        .toList();
  }

  double salesForMonth(int month, int year) {
    return ordersForMonth(month, year).fold(0.0, (s, o) => s + o.price);
  }

  double commissionForMonth(int month, int year) {
    return ordersForMonth(month, year).fold(0.0, (s, o) => s + o.commission);
  }

  List<OrderItem> get unpaidOrders => _orders
      .where((o) => o.paymentStatus != PaymentStatus.paid && o.balance > 0)
      .toList()
    ..sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));

  List<OrderItem> get upcomingOrOverdueOrders {
    final list = _orders
        .where((o) =>
            o.paymentStatus != PaymentStatus.paid &&
            o.balance > 0 &&
            o.dueDate != null)
        .toList();
    list.sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));
    return list;
  }

  double customerBalance(String customerName) {
    return _orders
        .where((o) => o.customerName == customerName)
        .fold(0.0, (sum, o) => sum + o.balance);
  }
}
