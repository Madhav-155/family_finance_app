import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../core/time/ist_time.dart';
import '../shared/data/finance_repository.dart';
import '../shared/domain/finance_models.dart';

class AppDatabase implements FinanceRepository {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _storage = FlutterSecureStorage();
  static const _passwordKey = 'finance_database_password';
  static const householdId = 'primary-household';
  static const localUserId = 'local-owner';
  static const syncedTables = ['expenses', 'income', 'emis', 'budgets'];

  Database? _database;
  @override
  String deviceId = '';

  Future<Database> get database async {
    if (_database != null) return _database!;
    await initialize();
    return _database!;
  }

  Future<void> initialize() async {
    if (_database != null) return;
    var password = await _storage.read(key: _passwordKey);
    password ??= base64UrlEncode(
      List<int>.generate(48, (_) => Random.secure().nextInt(256)),
    );
    await _storage.write(key: _passwordKey, value: password);
    deviceId = await _storage.read(key: 'device_id') ?? _randomId();
    await _storage.write(key: 'device_id', value: deviceId);

    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'family_finance.db'),
      password: password,
      version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> _createSchema(Database db, int version) async {
    const metadata = '''
      id TEXT PRIMARY KEY,
      household_id TEXT NOT NULL,
      created_by TEXT NOT NULL,
      device_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 1,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_state TEXT NOT NULL DEFAULT 'pending'
    ''';
    await db.execute('''
      CREATE TABLE households (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, owner_id TEXT NOT NULL,
        created_at TEXT NOT NULL, spreadsheet_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY, email TEXT, display_name TEXT NOT NULL,
        photo_url TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE memberships (
        id TEXT PRIMARY KEY, household_id TEXT NOT NULL, user_id TEXT NOT NULL,
        role TEXT NOT NULL, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY, household_id TEXT NOT NULL, name TEXT NOT NULL,
        icon TEXT NOT NULL, color INTEGER NOT NULL, type TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        $metadata,
        amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
        category TEXT NOT NULL, paid_by TEXT NOT NULL,
        payment_mode TEXT NOT NULL, date TEXT NOT NULL, notes TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE income (
        $metadata,
        source TEXT NOT NULL, amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
        received_date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE emis (
        $metadata,
        loan_name TEXT NOT NULL, amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
        due_date TEXT NOT NULL, status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        $metadata,
        category TEXT NOT NULL, limit_minor INTEGER NOT NULL CHECK(limit_minor >= 0),
        month TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE loans (
        $metadata, person TEXT NOT NULL, type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL, balance_minor INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE investments (
        $metadata, type TEXT NOT NULL, amount_minor INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY, entity_id TEXT, type TEXT NOT NULL,
        scheduled_at TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT UNIQUE NOT NULL,
        table_name TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL,
        queued_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT, synced_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, table_name TEXT NOT NULL,
        entity_id TEXT NOT NULL, winning_json TEXT NOT NULL,
        losing_json TEXT NOT NULL, resolved_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_expenses_date ON expenses(household_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_income_date ON income(household_id, received_date)',
    );
    await db.insert('households', {
      'id': householdId,
      'name': 'My Family',
      'owner_id': localUserId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await db.insert('users', {
      'id': localUserId,
      'display_name': 'Family Owner',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await db.insert('memberships', {
      'id': 'membership-owner',
      'household_id': householdId,
      'user_id': localUserId,
      'role': 'owner',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    const defaults = [
      ('food', 'Food', 'utensils', 0xFFFF7043),
      ('travel', 'Travel', 'bus', 0xFF42A5F5),
      ('bills', 'Bills', 'receipt', 0xFFFFB300),
      ('health', 'Health', 'heart', 0xFFEF5350),
      ('shopping', 'Shopping', 'bag', 0xFFAB47BC),
      ('other', 'Other', 'circle', 0xFF78909C),
    ];
    for (final category in defaults) {
      await db.insert('categories', {
        'id': category.$1,
        'household_id': householdId,
        'name': category.$2,
        'icon': category.$3,
        'color': category.$4,
        'type': 'expense',
      });
    }
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion >= 3) return;
    for (final entry in {
      'expenses': 'date',
      'income': 'received_date',
      'emis': 'due_date',
    }.entries) {
      final rows = await db.query(entry.key, columns: ['id', entry.value]);
      for (final row in rows) {
        final stored = row[entry.value] as String?;
        if (stored == null || !stored.contains('T')) continue;
        final parsed = DateTime.tryParse(stored);
        if (parsed == null) continue;
        await db.update(
          entry.key,
          {
            entry.value: formatDateOnly(
              IstTime.dateOnlyFromStoredInstant(parsed),
            ),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  Map<String, Object?> metadata(String id, DateTime now) => {
    'id': id,
    'household_id': householdId,
    'created_by': localUserId,
    'device_id': deviceId,
    'created_at': now.toUtc().toIso8601String(),
    'updated_at': now.toUtc().toIso8601String(),
    'revision': 1,
    'is_deleted': 0,
    'sync_state': 'pending',
  };

  @override
  Future<FinanceSnapshot> loadSnapshot() async {
    final db = await database;
    final results = await Future.wait([
      db.query('expenses', orderBy: 'date DESC'),
      db.query('income', orderBy: 'received_date DESC'),
      db.query('emis', orderBy: 'due_date ASC'),
      db.query('budgets', orderBy: 'month DESC'),
    ]);
    return FinanceSnapshot(
      expenses: results[0].map(Expense.fromMap).toList(),
      income: results[1].map(IncomeEntry.fromMap).toList(),
      emis: results[2].map(Emi.fromMap).toList(),
      budgets: results[3].map(Budget.fromMap).toList(),
    );
  }

  @override
  Future<void> insertEntity(String table, JsonMap values) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _queue(txn, table, values['id']! as String, 'upsert');
    });
  }

  @override
  Future<void> updateEntity(
    String table,
    SyncEntity entity,
    JsonMap values,
  ) async {
    if (!syncedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Unsupported finance table');
    }
    final db = await database;
    await db.transaction((txn) async {
      final updated = <String, Object?>{
        ...values,
        'id': entity.id,
        'household_id': entity.householdId,
        'created_by': entity.createdBy,
        'device_id': deviceId,
        'created_at': entity.createdAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'revision': entity.revision + 1,
        'is_deleted': 0,
        'sync_state': 'pending',
      };
      await txn.update(table, updated, where: 'id = ?', whereArgs: [entity.id]);
      await _queue(txn, table, entity.id, 'upsert');
    });
  }

  @override
  Future<void> markEmiPaid(Emi emi) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'emis',
        {
          'status': 'paid',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'revision': emi.revision + 1,
          'sync_state': 'pending',
        },
        where: 'id = ?',
        whereArgs: [emi.id],
      );
      await _queue(txn, 'emis', emi.id, 'upsert');
    });
  }

  @override
  Future<void> deleteEntity(String table, SyncEntity entity) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        table,
        {
          'is_deleted': 1,
          'revision': entity.revision + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'sync_state': 'pending',
        },
        where: 'id = ?',
        whereArgs: [entity.id],
      );
      await _queue(txn, table, entity.id, 'delete');
    });
  }

  Future<void> _queue(
    DatabaseExecutor db,
    String table,
    String entityId,
    String operation,
  ) async {
    await db.insert('sync_log', {
      'operation_id': _randomId(),
      'table_name': table,
      'entity_id': entityId,
      'operation': operation,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, List<JsonMap>>> exportData() async {
    final db = await database;
    final result = <String, List<JsonMap>>{};
    for (final table in [
      'households',
      'users',
      'memberships',
      'categories',
      ...syncedTables,
    ]) {
      result[table] = (await db.query(table)).cast<JsonMap>();
    }
    return result;
  }

  Future<void> restoreData(Map<String, dynamic> data) async {
    const restoreOrder = [
      'households',
      'users',
      'memberships',
      'categories',
      ...syncedTables,
    ];
    final validated = <String, List<Map<String, dynamic>>>{};
    for (final table in restoreOrder) {
      final value = data[table];
      if (value is! List) {
        throw const FormatException('Backup is missing required finance data.');
      }
      validated[table] = value
          .map(
            (row) => row is Map
                ? Map<String, dynamic>.from(row)
                : throw const FormatException(
                    'Backup contains an invalid database row.',
                  ),
          )
          .toList();
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final table in restoreOrder.reversed) {
        await txn.delete(table);
      }
      for (final table in restoreOrder) {
        for (final row in validated[table]!) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> mergeRemoteRows(
    String table,
    List<String> headers,
    List<List<Object?>> rows,
  ) async {
    if (!syncedTables.contains(table) || headers.isEmpty) return;
    final db = await database;
    final integerColumns = (await db.rawQuery('PRAGMA table_info($table)'))
        .where((column) => (column['type'] as String).contains('INTEGER'))
        .map((column) => column['name'] as String)
        .toSet();
    await db.transaction((txn) async {
      for (final cells in rows) {
        final remote = <String, Object?>{};
        for (var i = 0; i < headers.length; i++) {
          final value = i < cells.length ? cells[i] : null;
          remote[headers[i]] = integerColumns.contains(headers[i])
              ? int.tryParse('$value') ?? 0
              : '$value';
        }
        final id = remote['id'] as String?;
        if (id == null || id.isEmpty) continue;
        final localRows = await txn.query(
          table,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (localRows.isEmpty) {
          await txn.insert(table, remote);
          continue;
        }
        final local = localRows.single;
        if (_remoteWins(remote, local)) {
          await txn.insert('conflicts', {
            'table_name': table,
            'entity_id': id,
            'winning_json': jsonEncode(remote),
            'losing_json': jsonEncode(local),
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
          });
          remote['sync_state'] = 'synced';
          await txn.update(table, remote, where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  bool _remoteWins(JsonMap remote, JsonMap local) {
    final remoteRevision = remote['revision'] as int? ?? 0;
    final localRevision = local['revision'] as int? ?? 0;
    if (remoteRevision != localRevision) return remoteRevision > localRevision;
    final remoteTime =
        DateTime.tryParse('${remote['updated_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final localTime =
        DateTime.tryParse('${local['updated_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (remoteTime != localTime) return remoteTime.isAfter(localTime);
    return '${remote['device_id']}'.compareTo('${local['device_id']}') > 0;
  }

  Future<void> markSynced() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in syncedTables) {
        await txn.update(table, {'sync_state': 'synced'});
      }
      await txn.update('sync_log', {
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      }, where: 'synced_at IS NULL');
    });
  }
}
