import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart' show Uint8Buffer;

import '../query_executor.dart';
import 'sqlite3_wasm_query_executor.dart';

const String _dbAssetKey = 'packages/ug_locations/assets/ug_locations.db';

// Package assets are served by Flutter web under `assets/packages/<pkg>/...`
// (relative to the app's base href) - shipping the wasm binary as a package
// asset like this avoids requiring consumers to manually copy a file into
// their own `web/` directory (unlike `sqflite_common_ffi_web`'s setup step).
const String _wasmAssetUrl = 'assets/packages/ug_locations/assets/sqlite3.wasm';

const String _dbVfsPath = '/ug_locations.db';

/// Loads the bundled database asset's bytes directly into an in-memory
/// `sqlite3` wasm database. There is no persistence between page loads - the
/// data is static reference data, so re-loading it each session is fine.
Future<QueryExecutor> openDatabase() async {
  final ByteData dbBytes = await rootBundle.load(_dbAssetKey);
  final WasmSqlite3 sqlite3 = await WasmSqlite3.loadFromUrlString(_wasmAssetUrl);

  final InMemoryFileSystem fs = InMemoryFileSystem();
  fs.fileData[_dbVfsPath] = Uint8Buffer()
    ..addAll(dbBytes.buffer.asUint8List(dbBytes.offsetInBytes, dbBytes.lengthInBytes));
  sqlite3.registerVirtualFileSystem(fs, makeDefault: true);

  final CommonDatabase db = sqlite3.open(_dbVfsPath, mode: OpenMode.readOnly);
  return Sqlite3WasmQueryExecutor(db);
}

/// Not supported on web: there is no on-disk path to bypass, since the
/// database is loaded directly into an in-memory virtual filesystem. Use
/// [openDatabase] instead.
Future<QueryExecutor> openDatabaseFromPath(String path) {
  throw UnsupportedError('UgLocationsDatabase.openFromPath is not supported on web.');
}
