import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Handles locating, copying, and opening the bundled `ug_locations.db`
/// SQLite asset.
///
/// The database ships as a Flutter asset, which cannot be queried in place -
/// it must first be copied to a writable location on disk.
class UgLocationsDatabase {
  UgLocationsDatabase._();

  static const String _assetPath = 'packages/ug_locations/assets/ug_locations.db';
  static const String _dbFileName = 'ug_locations.db';

  /// Copies the bundled database asset to the app's support directory (if
  /// not already present) and opens it read-only.
  ///
  /// Requires a [databaseFactory] to already be configured - this is the
  /// default on Android/iOS via `sqflite`. On desktop or in plain `dart
  /// test` runs, call `sqfliteFfiInit()` and set
  /// `databaseFactory = databaseFactoryFfi` (from `sqflite_common_ffi`)
  /// before calling this.
  static Future<Database> open() async {
    final Directory dir = await getApplicationSupportDirectory();
    final String dbPath = p.join(dir.path, _dbFileName);

    if (!await File(dbPath).exists()) {
      final ByteData bytes = await rootBundle.load(_assetPath);
      await File(dbPath).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    return openFromPath(dbPath);
  }

  /// Opens a database directly from [path], bypassing the asset-copy step.
  ///
  /// Intended for tests that want to point straight at
  /// `assets/ug_locations.db` on disk.
  static Future<Database> openFromPath(String path) {
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }
}
