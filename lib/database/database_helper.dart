import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';
import '../models/payment.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (kIsWeb) {
      path = 'botoys_listahan.db';
    } else {
      path = join(await getDatabasesPath(), 'botoys_listahan.db');
    }
    final db = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureMigration(db);
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT,
        itemName TEXT,
        type TEXT DEFAULT 'Bugasan',
        price REAL,
        commission REAL,
        date TEXT,
        paymentStatus TEXT DEFAULT 'unpaid',
        dueDate TEXT,
        paidAmount REAL DEFAULT 0
      )
    ''');
    await _createPaymentsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addPaymentColumns(db);
    }
    if (oldVersion < 3) {
      await _addTypeColumn(db);
    }
    if (oldVersion < 4) {
      await _createPaymentsTable(db);
      await _backfillPayments(db);
    }
  }

  Future<void> _createPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT DEFAULT '',
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _backfillPayments(Database db) async {
    final rows = await db.query(
      'orders',
      columns: ['id', 'paidAmount', 'date'],
      where: 'paidAmount > 0',
    );
    for (final row in rows) {
      final orderId = row['id'];
      final paidAmount = (row['paidAmount'] as num?)?.toDouble() ?? 0;
      final date = row['date'] as String?;
      if (orderId == null || paidAmount <= 0 || date == null) continue;
      final existing =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM payments WHERE orderId = ?',
              [orderId],
            ),
          ) ??
          0;
      if (existing == 0) {
        await db.insert('payments', {
          'orderId': orderId,
          'amount': paidAmount,
          'date': date,
          'note': 'Opening payment',
        });
      }
    }
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    final columns = <String>{};
    for (final row in result) {
      final name = row['name'] ?? row['NAME'];
      if (name != null) columns.add((name as String).toLowerCase());
    }
    return columns;
  }

  Future<void> _ensureMigration(Database db) async {
    try {
      final columns = await _getTableColumns(db, 'orders');
      if (!columns.contains('paymentstatus')) {
        await db.execute(
          "ALTER TABLE orders ADD COLUMN paymentStatus TEXT DEFAULT 'unpaid'",
        );
      }
      if (!columns.contains('duedate')) {
        await db.execute('ALTER TABLE orders ADD COLUMN dueDate TEXT');
      }
      if (!columns.contains('paidamount')) {
        await db.execute(
          'ALTER TABLE orders ADD COLUMN paidAmount REAL DEFAULT 0',
        );
      }
      if (!columns.contains('type')) {
        await db.execute(
          "ALTER TABLE orders ADD COLUMN type TEXT DEFAULT 'Bugasan'",
        );
      }
      await _createPaymentsTable(db);
      await _backfillPayments(db);
    } catch (e) {
      if (kDebugMode) debugPrint('Migration: $e');
    }
  }

  Future<void> _addPaymentColumns(Database db) async {
    final columns = await _getTableColumns(db, 'orders');
    if (!columns.contains('paymentstatus')) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN paymentStatus TEXT DEFAULT 'unpaid'",
      );
    }
    if (!columns.contains('duedate')) {
      await db.execute('ALTER TABLE orders ADD COLUMN dueDate TEXT');
    }
    if (!columns.contains('paidamount')) {
      await db.execute(
        'ALTER TABLE orders ADD COLUMN paidAmount REAL DEFAULT 0',
      );
    }
  }

  Future<void> _addTypeColumn(Database db) async {
    final columns = await _getTableColumns(db, 'orders');
    if (!columns.contains('type')) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN type TEXT DEFAULT 'Bugasan'",
      );
    }
  }

  Future<int> insertOrder(OrderItem order) async {
    final db = await database;
    return await db.insert(
      'orders',
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OrderItem>> getOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return OrderItem.fromMap(maps[i]);
    });
  }

  Future<int> updateOrder(OrderItem order) async {
    final db = await database;
    return await db.update(
      'orders',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> updateOrderType(String oldType, String newType) async {
    final db = await database;
    return await db.update(
      'orders',
      {'type': newType},
      where: 'type = ?',
      whereArgs: [oldType],
    );
  }

  Future<int> insertPayment(PaymentRecord payment) async {
    final db = await database;
    return await db.insert('payments', payment.toMap());
  }

  Future<int> updatePayment(PaymentRecord payment) async {
    final db = await database;
    return await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<List<PaymentRecord>> getPayments() async {
    final db = await database;
    final maps = await db.query('payments', orderBy: 'date DESC');
    return maps.map(PaymentRecord.fromMap).toList();
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceBackup({
    required List<OrderItem> orders,
    required List<PaymentRecord> payments,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('orders');
      for (final order in orders) {
        await txn.insert(
          'orders',
          order.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final payment in payments) {
        await txn.insert(
          'payments',
          payment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> mergeBackup({
    required List<OrderItem> orders,
    required List<PaymentRecord> payments,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final idMap = <int, int>{};
      final existingRows = await txn.query('orders');
      final existingKeys = existingRows
          .map((row) => _entryDuplicateKey(OrderItem.fromMap(row)))
          .toSet();
      for (final order in orders) {
        final key = _entryDuplicateKey(order);
        if (existingKeys.contains(key)) continue;

        final map = order.toMap()..remove('id');
        final newId = await txn.insert('orders', map);
        existingKeys.add(key);
        final oldId = order.id;
        if (oldId != null) idMap[oldId] = newId;
      }

      for (final payment in payments) {
        final mappedOrderId = idMap[payment.orderId];
        if (mappedOrderId == null) continue;
        final map = payment.toMap()
          ..remove('id')
          ..['orderId'] = mappedOrderId;
        await txn.insert('payments', map);
      }
    });
  }

  String _entryDuplicateKey(OrderItem order) {
    return [
      order.customerName.trim().toLowerCase(),
      order.itemName.trim().toLowerCase(),
      order.type.trim().toLowerCase(),
      order.price.toStringAsFixed(2),
      order.commission.toStringAsFixed(2),
      order.date.toIso8601String(),
    ].join('|');
  }

  Future<int> deleteOrder(int id) async {
    final db = await database;
    await db.delete('payments', where: 'orderId = ?', whereArgs: [id]);
    return await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }
}
