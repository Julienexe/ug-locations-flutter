import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'ug_location.dart';
import 'ug_locations_database.dart';

/// Lookup and search API for Uganda's administrative-unit hierarchy
/// (village -> parish -> subcounty -> constituency -> district), backed by
/// a bundled SQLite database.
///
/// Obtain the shared instance with [UgandaLocations.getInstance]:
///
/// ```dart
/// final ug = await UgandaLocations.getInstance();
/// final location = await ug.getLocationByVillage('KASAMBYA I');
/// ```
class UgandaLocations {
  UgandaLocations._(this._db);

  final Database _db;

  static Completer<UgandaLocations>? _instanceCompleter;

  /// Returns the shared [UgandaLocations] instance, opening (and, on first
  /// run, copying) the bundled database if needed.
  ///
  /// Safe to call concurrently from multiple call sites - the database is
  /// only opened once.
  static Future<UgandaLocations> getInstance() {
    final Completer<UgandaLocations>? existing = _instanceCompleter;
    if (existing != null) return existing.future;

    final Completer<UgandaLocations> completer = Completer<UgandaLocations>();
    _instanceCompleter = completer;

    UgLocationsDatabase.open().then((Database db) {
      completer.complete(UgandaLocations._(db));
    }).catchError((Object error, StackTrace stackTrace) {
      _instanceCompleter = null;
      completer.completeError(error, stackTrace);
    });

    return completer.future;
  }

  /// Creates an instance from an already-open [Database].
  ///
  /// Intended for tests that open the bundled `.db` file directly (e.g. via
  /// `sqflite_common_ffi`) without going through the asset-copy path.
  static UgandaLocations fromDatabase(Database db) => UgandaLocations._(db);

  /// Returns all districts, in their source order.
  Future<List<String>> getDistricts() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'districts',
      columns: <String>['name'],
      orderBy: 'id',
    );
    return rows.map((Map<String, Object?> row) => row['name']! as String).toList();
  }

  /// Looks up the full hierarchy for [village] (case-insensitive), or
  /// `null` if no such village exists.
  Future<UgandaLocation?> getLocationByVillage(String village) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'village_lookup',
      where: 'village = ?',
      whereArgs: <String>[village.toUpperCase().trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UgandaLocation.fromMap(rows.first);
  }

  /// Returns all villages in the given parish (case-insensitive), in the
  /// same order as the source data (duplicates, if any, are preserved).
  Future<List<String>> getVillagesInParish(
    String district,
    String subcounty,
    String parish,
  ) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'parish_villages',
      columns: <String>['village'],
      where: 'district = ? AND subcounty = ? AND parish = ?',
      whereArgs: <String>[
        district.toUpperCase().trim(),
        subcounty.toUpperCase().trim(),
        parish.toUpperCase().trim(),
      ],
      orderBy: 'seq ASC',
    );
    return rows.map((Map<String, Object?> row) => row['village']! as String).toList();
  }

  /// Returns all parishes in the given subcounty (case-insensitive), in the
  /// same order as the source data (duplicate parish names, if any, are
  /// preserved - this mirrors the original JS package's behavior).
  Future<List<String>> getParishesInSubcounty(String district, String subcounty) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subcounty_parishes',
      columns: <String>['parish'],
      where: 'district = ? AND subcounty = ?',
      whereArgs: <String>[district.toUpperCase().trim(), subcounty.toUpperCase().trim()],
      orderBy: 'seq ASC',
    );
    return rows.map((Map<String, Object?> row) => row['parish']! as String).toList();
  }

  /// Returns all subcounties in the given district (case-insensitive),
  /// sorted alphabetically.
  Future<List<String>> getSubcountiesInDistrict(String district) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'subcounties',
      columns: <String>['subcounty'],
      where: 'district = ?',
      whereArgs: <String>[district.toUpperCase().trim()],
      orderBy: 'subcounty ASC',
    );
    return rows.map((Map<String, Object?> row) => row['subcounty']! as String).toList();
  }

  /// Searches villages, parishes, subcounties, and districts for [query],
  /// ranking exact and prefix matches first.
  Future<List<UgandaLocation>> search(String query, {int limit = 50}) async {
    final String q = query.toUpperCase().trim();
    final String like = '%$q%';
    final String prefix = '$q%';

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT * FROM village_lookup
      WHERE village LIKE ?
         OR district LIKE ?
         OR subcounty LIKE ?
         OR parish LIKE ?
         OR district = ?
      ORDER BY
        (CASE WHEN village = ? THEN 10 ELSE 0 END) +
        (CASE WHEN district = ? THEN 8 ELSE 0 END) +
        (CASE WHEN subcounty = ? THEN 6 ELSE 0 END) +
        (CASE WHEN village LIKE ? THEN 4 ELSE 0 END) DESC,
        village ASC
      LIMIT ?
      ''',
      <Object?>[like, like, like, like, q, q, q, q, prefix, limit],
    );
    return rows.map(UgandaLocation.fromMap).toList();
  }

  /// Returns a human-readable path for [village], e.g.
  /// `"HOIMA → BUHANIKA → KATEREIGA → KASAMBYA I"`, or `null` if the
  /// village doesn't exist.
  Future<String?> getPath(String village) async {
    final UgandaLocation? loc = await getLocationByVillage(village);
    if (loc == null) return null;
    return '${loc.district} → ${loc.subcounty} → ${loc.parish} → ${loc.village}';
  }

  /// Returns the parent location (parish/subcounty/district) of [village],
  /// or `null` if the village doesn't exist.
  Future<UgandaLocationParent?> getParent(String village) async {
    final UgandaLocation? loc = await getLocationByVillage(village);
    if (loc == null) return null;
    return UgandaLocationParent(
      parish: loc.parish,
      subcounty: loc.subcounty,
      district: loc.district,
    );
  }

  /// Closes the underlying database connection.
  Future<void> close() => _db.close();
}
