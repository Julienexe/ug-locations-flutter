import 'query_executor.dart';
import 'ug_locations_database_io.dart'
    if (dart.library.js_interop) 'web/ug_locations_database_web.dart'
    as impl;

/// Handles locating and opening the bundled `ug_locations.db` SQLite asset.
///
/// The actual implementation differs by platform: Android/iOS/desktop copy
/// the asset to disk and open it via `sqflite`; web loads the asset's bytes
/// directly into an in-memory `sqlite3` wasm database. Both are hidden
/// behind [QueryExecutor], so callers don't need to know which one is in
/// use.
class UgLocationsDatabase {
  UgLocationsDatabase._();

  /// Opens the bundled database asset, doing whatever platform-specific
  /// setup is needed first (see the class doc).
  ///
  /// Requires a `databaseFactory` to already be configured on
  /// Android/iOS/desktop - this is the default on Android/iOS via `sqflite`.
  /// On desktop or in plain `dart test` runs, call `sqfliteFfiInit()` and
  /// set `databaseFactory = databaseFactoryFfi` (from `sqflite_common_ffi`)
  /// before calling this. Not applicable on web.
  static Future<QueryExecutor> open() => impl.openDatabase();

  /// Opens a database directly from [path], bypassing the asset-copy step.
  ///
  /// Intended for tests that want to point straight at
  /// `assets/ug_locations.db` on disk. Not supported on web, since there is
  /// no on-disk path to open - use [open] instead.
  static Future<QueryExecutor> openFromPath(String path) => impl.openDatabaseFromPath(path);
}
