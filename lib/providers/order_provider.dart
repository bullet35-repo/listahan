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

  /// Returns sales totals for the last [months] months.
  /// The returned list is ordered from oldest to newest.
  List<double> salesSeries({int months = 6}) {
    final now = DateTime.now();
    final series = List<double>.filled(months, 0.0);
    for (final o in _orders) {
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
  List<double> commissionSeries({int months = 6}) {
    final now = DateTime.now();
    final series = List<double>.filled(months, 0.0);
    for (final o in _orders) {
      final diff = (now.year - o.date.year) * 12 + (now.month - o.date.month);
      if (diff >= 0 && diff < months) {
        final idx = months - 1 - diff;
        series[idx] += o.commission;
      }
    }
    return series;
  }
}
