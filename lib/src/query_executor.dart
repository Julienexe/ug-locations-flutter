/// The subset of SQLite query operations [UgandaLocations] needs, abstracted
/// so the repository works the same way regardless of which backend actually
/// opened the database (`sqflite` on Android/iOS/desktop, `sqlite3` wasm on
/// web).
abstract class QueryExecutor {
  /// Runs a structured `SELECT` against [table], mirroring `sqflite`'s
  /// `Database.query` signature. [where] and [orderBy] are raw SQL
  /// fragments (with `?` placeholders in [where], bound from [whereArgs]).
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  });

  /// Runs a raw SQL query with `?`-bound [arguments].
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]);

  /// Closes the underlying database connection.
  Future<void> close();
}
