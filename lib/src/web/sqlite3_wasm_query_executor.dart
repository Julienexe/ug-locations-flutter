import 'package:sqlite3/common.dart';

import '../query_executor.dart';

/// A [QueryExecutor] backed by a `package:sqlite3` wasm [CommonDatabase].
/// Used on web, where `sqflite` has no backend of its own.
class Sqlite3WasmQueryExecutor implements QueryExecutor {
  /// Wraps an already-open [CommonDatabase].
  const Sqlite3WasmQueryExecutor(this._db);

  final CommonDatabase _db;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    final StringBuffer sql = StringBuffer('SELECT ${columns?.join(', ') ?? '*'} FROM $table');
    if (where != null) sql.write(' WHERE $where');
    if (orderBy != null) sql.write(' ORDER BY $orderBy');
    if (limit != null) sql.write(' LIMIT $limit');
    return rawQuery(sql.toString(), whereArgs);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final ResultSet result = _db.select(sql, arguments ?? const <Object?>[]);
    return <Map<String, Object?>>[for (final Row row in result) Map<String, Object?>.of(row)];
  }

  @override
  Future<void> close() async => _db.close();
}
