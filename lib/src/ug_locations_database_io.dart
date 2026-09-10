import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'query_executor.dart';
import 'sqflite_query_executor.dart';

const String _assetPath = 'packages/ug_locations/assets/ug_locations.db';
const String _dbFileName = 'ug_locations.db';
const String _versionFileName = 'ug_locations.db.version';

// Bump this whenever assets/ug_locations.db's schema changes (new/renamed
// columns or tables). Without it, an app that already copied an older
// ug_locations.db to its support directory on a previous run would keep
// using that stale copy forever - the "if not already present" check below
// would never see it as absent, so a schema-changing package update would
// silently crash with e.g. "no such column: region" instead of picking up
// the new bundled database.
const int _schemaVersion = 2;

/// Copies the bundled database asset to the app's support directory (if not
/// already present, or if the cached copy predates [_schemaVersion]) and
/// opens it read-only via `sqflite`.
Future<QueryExecutor> openDatabase() async {
  final Directory dir = await getApplicationSupportDirectory();
  final String dbPath = p.join(dir.path, _dbFileName);
  final File versionFile = File(p.join(dir.path, _versionFileName));

  final int? cachedVersion = await versionFile.exists()
      ? int.tryParse(await versionFile.readAsString())
      : null;

  if (!await File(dbPath).exists() || cachedVersion != _schemaVersion) {
    final ByteData bytes = await rootBundle.load(_assetPath);
    await File(dbPath).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    await versionFile.writeAsString('$_schemaVersion', flush: true);
  }

  return openDatabaseFromPath(dbPath);
}

/// Opens a database directly from [path] via `sqflite`, bypassing the
/// asset-copy step.
Future<QueryExecutor> openDatabaseFromPath(String path) async {
  final Database db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true),
  );
  return SqfliteQueryExecutor(db);
}
