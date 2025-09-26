import 'dart:io';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../core/db.dart';
import '../core/models.dart';
import 'package:path/path.dart' as p;

class Repository {
  Repository._();
  static final Repository instance = Repository._();

  final _uuid = const Uuid();

  Future<String> createDelivery({required String lorryName, DateTime? date, String? notes}) async {
    final db = await AppDatabase.instance.database;
    final id = _uuid.v4();
    final iso = (date ?? DateTime.now()).toIso8601String();
    await db.insert('deliveries', {
      'id': id,
      'lorry_name': lorryName.trim(),
      'date_iso': iso,
      'notes': notes,
    });
    return id;
  }

  Future<List<Delivery>> getDeliveries() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('deliveries', orderBy: 'date_iso DESC');
    return rows.map((r) => Delivery(
      id: r['id'] as String,
      lorryName: r['lorry_name'] as String,
      date: DateTime.parse(r['date_iso'] as String),
      notes: r['notes'] as String?,
    )).toList();
  }

  Future<void> updateDelivery({required String id, String? lorryName, DateTime? date, String? notes}) async {
    final db = await AppDatabase.instance.database;
    final updates = <String, Object?>{};
    if (lorryName != null) updates['lorry_name'] = lorryName.trim();
    if (date != null) updates['date_iso'] = date.toIso8601String();
    if (notes != null) updates['notes'] = notes;
    if (updates.isNotEmpty) {
      await db.update('deliveries', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  // Future<void> deleteDelivery(String id) async {
  //   final db = await AppDatabase.instance.database;
  //   await db.delete('widths', where: 'group_id IN (SELECT id FROM groups WHERE delivery_id = ?)', whereArgs: [id]);
  //   await db.delete('groups', where: 'delivery_id = ?', whereArgs: [id]);
  //   await db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  // }


// core/repository.dart
Future<void> deleteDelivery(String id) async {
  final db = await AppDatabase.instance.database;
  await db.transaction((txn) async {
    // delete children first (your original logic)
    await txn.delete('widths',
        where: 'group_id IN (SELECT id FROM groups WHERE delivery_id = ?)',
        whereArgs: [id]);
    await txn.delete('groups', where: 'delivery_id = ?', whereArgs: [id]);
    await txn.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  });
}

  Future<String> addGroup({required String deliveryId, required double thickness, required double length}) async {
    final db = await AppDatabase.instance.database;
    final gid = _uuid.v4();
    await db.insert('groups', {
      'id': gid,
      'delivery_id': deliveryId,
      'thickness': thickness,
      'length': length,
    });
    return gid;
  }

  Future<List<WoodGroup>> getGroups(String deliveryId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('groups', where: 'delivery_id = ?', whereArgs: [deliveryId], orderBy: 'thickness, length');
    return rows.map((r) => WoodGroup(
      id: r['id'] as String,
      deliveryId: r['delivery_id'] as String,
      thickness: (r['thickness'] as num).toDouble(),
      length: (r['length'] as num).toDouble(),
    )).toList();
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('widths', where: 'group_id = ?', whereArgs: [groupId]);
    await db.delete('groups', where: 'id = ?', whereArgs: [groupId]);
  }

  Future<void> addWidths(String groupId, List<double> widths) async {
    if (widths.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final w in widths) {
      batch.insert('widths', {'id': _uuid.v4(), 'group_id': groupId, 'width': w});
    }
    await batch.commit(noResult: true);
  }

  Future<List<WoodWidth>> getWidths(String groupId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('widths', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'width');
    return rows.map((r) => WoodWidth(
      id: r['id'] as String,
      groupId: r['group_id'] as String,
      width: (r['width'] as num).toDouble(),
    )).toList();
  }

  Future<void> deleteWidth(String widthId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('widths', where: 'id = ?', whereArgs: [widthId]);
  }

  /// Returns (groupsCount, widthsCount)
  Future<(int, int)> deliveryCounts(String deliveryId) async {
    final db = await AppDatabase.instance.database;
    final groups = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM groups WHERE delivery_id = ?', [deliveryId]
    )) ?? 0;
    final widths = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM widths WHERE group_id IN (SELECT id FROM groups WHERE delivery_id = ?)',
      [deliveryId],
    )) ?? 0;
    return (groups, widths);
  }

  /// Exports one delivery as simple CSV: lorry,date,thickness,length,width
  Future<String> exportDeliveryCsv(String deliveryId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT d.lorry_name AS lorry, d.date_iso AS date_iso,
             g.thickness AS thickness, g.length AS length, w.width AS width
      FROM widths w
      JOIN groups g ON g.id = w.group_id
      JOIN deliveries d ON d.id = g.delivery_id
      WHERE d.id = ?
      ORDER BY g.thickness, g.length, w.width
    ''', [deliveryId]);

    final buffer = StringBuffer();
    buffer.writeln('lorry,date,thickness,length,width');
    for (final r in rows) {
      final lorry = r['lorry'] as String;
      final dateIso = r['date_iso'] as String;
      final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(dateIso).toLocal());
      final t = (r['thickness'] as num).toString();
      final l = (r['length'] as num).toString();
      final w = (r['width'] as num).toString();
      buffer.writeln('$lorry,$date,$t,$l,$w');
    }

    final dir = await getDatabasesPath(); // app DB dir is writable and easy to find
    final path = p.join(dir, 'export_${deliveryId.substring(0,8)}.csv');
    final file = await File(path).writeAsString(buffer.toString());
    return file.path;
  }
}
