import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception(
        'Local storage is not available on web. Please use the InstaGold mobile app.',
      );
    }
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'gold_family.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS FamilyMembers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        relation TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        asset_type TEXT NOT NULL,
        karat TEXT NOT NULL,
        company_id INTEGER,
        weight_g REAL NOT NULL,
        purchase_price REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        invoice_local_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'EGP',
        target_type TEXT,
        target_karat TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS PurchaseGoals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        company_id INTEGER,
        karat TEXT NOT NULL,
        target_weight_g REAL NOT NULL,
        target_price REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        remaining_amount REAL NOT NULL DEFAULT 0,
        manufacturing_price_g REAL NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'custom',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS GoldPriceCache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carat TEXT NOT NULL,
        buy_price REAL,
        sell_price REAL,
        currency TEXT NOT NULL DEFAULT 'EGP',
        fetched_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS UserSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        locale TEXT NOT NULL DEFAULT 'en',
        theme TEXT NOT NULL DEFAULT 'system',
        notification_interval_hours INTEGER NOT NULL DEFAULT 1,
        default_member_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_members_user ON FamilyMembers (user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assets_member ON Assets (member_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_savings_member ON Savings (member_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_goals_member ON PurchaseGoals (member_id)');

    final now = DateTime.now().toIso8601String();
    for (final name in ['BTC', "L'AZURDE", 'SAM', 'SHEHATA']) {
      await db.insert('Companies', {'name': name, 'type': 'seeded', 'created_at': now});
    }
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE UserSettings ADD COLUMN default_member_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE Assets ADD COLUMN invoice_local_path TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE PurchaseGoals ADD COLUMN manufacturing_price_g REAL NOT NULL DEFAULT 0');
    }
  }

  List<Map<String, dynamic>> toDynamic(List<Map<String, Object?>> rows) {
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic> toDynamicMap(Map<String, Object?> row) {
    return Map<String, dynamic>.from(row);
  }
}
