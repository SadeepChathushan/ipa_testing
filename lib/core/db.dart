import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'wood_logger.db';
  static const _dbVersion = 1;

  Database? _db;

  // core/db.dart  (your AppDatabase)
Future<Database> get database async {
  if (_db != null) return _db!;
  final Directory docs = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docs.path, _dbName);
  _db = await openDatabase(
    dbPath,
    version: _dbVersion,
    // ✅ Ensure ON DELETE CASCADE etc. actually work
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
  return _db!;
}


  Future<void> _onCreate(Database db, int version) async {
    // deliveries
    await db.execute('''
      CREATE TABLE deliveries(
        id TEXT PRIMARY KEY,
        lorry_name TEXT NOT NULL,
        date_iso TEXT NOT NULL,
        notes TEXT
      );
    ''');
    // groups
    await db.execute('''
      CREATE TABLE groups(
        id TEXT PRIMARY KEY,
        delivery_id TEXT NOT NULL,
        thickness REAL NOT NULL,
        length REAL NOT NULL,
        FOREIGN KEY(delivery_id) REFERENCES deliveries(id) ON DELETE CASCADE
      );
    ''');
    // widths
    await db.execute('''
      CREATE TABLE widths(
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        width REAL NOT NULL,
        FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE
      );
    ''');

    // helpful indices
    await db.execute('CREATE INDEX idx_groups_delivery ON groups(delivery_id);');
    await db.execute('CREATE INDEX idx_widths_group ON widths(group_id);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
  }
}
