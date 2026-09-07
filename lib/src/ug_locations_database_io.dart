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

/// Copies the bundled database asset to the app's support directory (if not
/// already present) and opens it read-only via `sqflite`.
Future<QueryExecutor> openDatabase() async {
  final Directory dir = await getApplicationSupportDirectory();
  final String dbPath = p.join(dir.path, _dbFileName);

  if (!await File(dbPath).exists()) {
    final ByteData bytes = await rootBundle.load(_assetPath);
    await File(dbPath).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
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
