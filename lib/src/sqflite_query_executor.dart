import 'package:sqflite/sqflite.dart';

import 'query_executor.dart';

/// A [QueryExecutor] backed directly by a `sqflite` [Database]. Used on
/// Android/iOS/desktop, where `sqflite`/`sqflite_common_ffi` provide the
/// storage layer.
class SqfliteQueryExecutor implements QueryExecutor {
  /// Wraps an already-open [Database].
  const SqfliteQueryExecutor(this._db);

  final Database _db;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return _db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) {
    return _db.rawQuery(sql, arguments);
  }

  @override
  Future<void> close() => _db.close();
}
