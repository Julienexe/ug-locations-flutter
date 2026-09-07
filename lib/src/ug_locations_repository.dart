import 'dart:async';

import 'query_executor.dart';
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

  final QueryExecutor _db;

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

    UgLocationsDatabase.open().then((QueryExecutor db) {
      completer.complete(UgandaLocations._(db));
    }).catchError((Object error, StackTrace stackTrace) {
      _instanceCompleter = null;
      completer.completeError(error, stackTrace);
    });

    return completer.future;
  }

  /// Creates an instance from an already-open [QueryExecutor].
  ///
  /// Intended for tests that open the bundled `.db` file directly (e.g. via
  /// `sqflite_common_ffi`) without going through the asset-copy path.
  static UgandaLocations fromDatabase(QueryExecutor db) => UgandaLocations._(db);

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
  ///
  /// If the substring/prefix pass returns fewer than [limit] results, a
  /// typo-tolerant fallback pass fills the remainder: candidates sharing
  /// [query]'s first letter are scored by Levenshtein distance against
  /// [query], and near-matches (distance scaling with query length) are
  /// appended, closest first. This catches misspellings of a whole name
  /// (e.g. `"KASOMBYA I"` still finding `"KASAMBYA I"`) but, since it keys
  /// off the first letter, does not recover from a typo in the first
  /// character itself.
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
    final List<UgandaLocation> results = rows.map(UgandaLocation.fromMap).toList();

    if (results.length >= limit || q.isEmpty) return results;

    final List<UgandaLocation> fuzzyMatches = await _fuzzySearch(
      q,
      limit: limit - results.length,
      exclude: results.map((UgandaLocation r) => r.village).toSet(),
    );
    return <UgandaLocation>[...results, ...fuzzyMatches];
  }

  /// Typo-tolerant fallback used by [search] once the exact/substring pass
  /// is exhausted. Scans candidates sharing [query]'s first letter and
  /// ranks them by Levenshtein distance, closest first.
  Future<List<UgandaLocation>> _fuzzySearch(
    String query, {
    required int limit,
    required Set<String> exclude,
  }) async {
    final String firstLetterPrefix = '${query[0]}%';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT * FROM village_lookup
      WHERE village LIKE ? OR district LIKE ? OR subcounty LIKE ? OR parish LIKE ?
      LIMIT 2000
      ''',
      <Object?>[firstLetterPrefix, firstLetterPrefix, firstLetterPrefix, firstLetterPrefix],
    );

    final int maxDistance = query.length <= 4 ? 1 : (query.length <= 8 ? 2 : 3);

    final List<MapEntry<UgandaLocation, int>> scored = <MapEntry<UgandaLocation, int>>[];
    for (final Map<String, Object?> row in rows) {
      final UgandaLocation loc = UgandaLocation.fromMap(row);
      if (exclude.contains(loc.village)) continue;
      final int distance = <int>[
        _levenshtein(query, loc.village),
        _levenshtein(query, loc.district),
        _levenshtein(query, loc.subcounty),
        _levenshtein(query, loc.parish),
      ].reduce((int a, int b) => a < b ? a : b);
      if (distance <= maxDistance) {
        scored.add(MapEntry<UgandaLocation, int>(loc, distance));
      }
    }
    scored.sort((MapEntry<UgandaLocation, int> a, MapEntry<UgandaLocation, int> b) {
      return a.value.compareTo(b.value);
    });
    return scored.take(limit).map((MapEntry<UgandaLocation, int> e) => e.key).toList();
  }

  /// Computes the Levenshtein (edit) distance between [a] and [b]: the
  /// minimum number of single-character insertions, deletions, or
  /// substitutions needed to turn one string into the other.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> previousRow = List<int>.generate(b.length + 1, (int i) => i);
    List<int> currentRow = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      currentRow[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final int cost = a[i] == b[j] ? 0 : 1;
        currentRow[j + 1] = <int>[
          currentRow[j] + 1,
          previousRow[j + 1] + 1,
          previousRow[j] + cost,
        ].reduce((int x, int y) => x < y ? x : y);
      }
      final List<int> tmp = previousRow;
      previousRow = currentRow;
      currentRow = tmp;
    }
    return previousRow[b.length];
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
