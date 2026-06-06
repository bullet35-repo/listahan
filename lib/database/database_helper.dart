import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';

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
      version: 2,
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
        price REAL,
        commission REAL,
        date TEXT,
        paymentStatus TEXT DEFAULT 'unpaid',
        dueDate TEXT,
        paidAmount REAL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addPaymentColumns(db);
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

  Future<int> deleteOrder(int id) async {
    final db = await database;
    return await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }
}
