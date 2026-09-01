// Converts tool/source_data/data-optimized.json into assets/ug_locations.db.
//
// Run with: dart run tool/build_database.dart
//
// The source JSON has four top-level keys, each with different dedup
// semantics that the query layer must replicate exactly:
//   - districts:    string[], source order preserved.
//   - byVillage:    Record<string, Location> - a COLLAPSED view (one entry
//                    per village name; duplicate names across parishes are
//                    resolved to a single winner). This is what
//                    getLocationByVillage/getPath/getParent/search use.
//   - byParish:     Record<"DIST||SUB||PARISH", {villages: string[]}> - the
//                    CANONICAL (deduped) village list per parish key. This is
//                    what getVillagesInParish uses.
//   - bySubcounty:  Record<"DIST||SUB", {data: [{parish, villages}], ...}> -
//                    the RAW parish list per subcounty, which can contain
//                    duplicate parish names in their original order. This is
//                    what getParishesInSubcounty uses, unmodified.
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final File sourceFile = File('tool/source_data/data-optimized.json');
  stdout.writeln('Reading ${sourceFile.path}...');
  final Map<String, Object?> data =
      json.decode(sourceFile.readAsStringSync()) as Map<String, Object?>;

  final File dbFile = File('assets/ug_locations.db');
  if (dbFile.existsSync()) dbFile.deleteSync();
  dbFile.parent.createSync(recursive: true);

  final Database db = sqlite3.open(dbFile.path);
  db.execute('''
    CREATE TABLE districts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    );

    CREATE TABLE subcounties (
      district TEXT NOT NULL,
      subcounty TEXT NOT NULL,
      constituency TEXT,
      PRIMARY KEY (district, subcounty)
    );
    CREATE INDEX idx_subcounties_district ON subcounties(district);

    CREATE TABLE subcounty_parishes (
      district TEXT NOT NULL,
      subcounty TEXT NOT NULL,
      parish TEXT NOT NULL,
      seq INTEGER NOT NULL
    );
    CREATE INDEX idx_subcounty_parishes_lookup ON subcounty_parishes(district, subcounty, seq);

    CREATE TABLE parish_villages (
      district TEXT NOT NULL,
      subcounty TEXT NOT NULL,
      parish TEXT NOT NULL,
      village TEXT NOT NULL,
      seq INTEGER NOT NULL
    );
    CREATE INDEX idx_parish_villages_lookup ON parish_villages(district, subcounty, parish, seq);

    CREATE TABLE village_lookup (
      village TEXT PRIMARY KEY,
      parish TEXT NOT NULL,
      subcounty TEXT NOT NULL,
      constituency TEXT,
      district TEXT NOT NULL
    );
    CREATE INDEX idx_village_lookup_district ON village_lookup(district);
    CREATE INDEX idx_village_lookup_subcounty ON village_lookup(subcounty);
    CREATE INDEX idx_village_lookup_parish ON village_lookup(parish);
  ''');

  db.execute('BEGIN;');
  try {
    _insertDistricts(db, data['districts']! as List<Object?>);
    _insertSubcountiesAndParishes(db, data['bySubcounty']! as Map<String, Object?>);
    _insertParishVillages(db, data['byParish']! as Map<String, Object?>);
    _insertVillageLookup(db, data['byVillage']! as Map<String, Object?>);
    db.execute('COMMIT;');
  } catch (_) {
    db.execute('ROLLBACK;');
    rethrow;
  }

  stdout.writeln('Optimizing database...');
  db.execute('ANALYZE;');
  db.execute('VACUUM;');

  _printCounts(db);

  db.close();
  stdout.writeln('Wrote ${dbFile.path}');
}

void _insertDistricts(Database db, List<Object?> districts) {
  final PreparedStatement stmt = db.prepare('INSERT INTO districts (name) VALUES (?);');
  for (final Object? name in districts) {
    stmt.execute(<Object?>[name]);
  }
  stmt.close();
}

void _insertSubcountiesAndParishes(Database db, Map<String, Object?> bySubcounty) {
  final PreparedStatement subcountyStmt = db.prepare(
    'INSERT INTO subcounties (district, subcounty, constituency) VALUES (?, ?, ?);',
  );
  final PreparedStatement parishStmt = db.prepare(
    'INSERT INTO subcounty_parishes (district, subcounty, parish, seq) VALUES (?, ?, ?, ?);',
  );

  for (final Object? entry in bySubcounty.values) {
    final Map<String, Object?> sc = entry! as Map<String, Object?>;
    final String district = sc['district']! as String;
    final String subcounty = sc['subcounty']! as String;
    final String? constituency = sc['constituency'] as String?;

    subcountyStmt.execute(<Object?>[district, subcounty, constituency]);

    final List<Object?> parishData = sc['data']! as List<Object?>;
    for (int i = 0; i < parishData.length; i++) {
      final Map<String, Object?> parish = parishData[i]! as Map<String, Object?>;
      parishStmt.execute(<Object?>[district, subcounty, parish['parish'], i]);
    }
  }

  subcountyStmt.close();
  parishStmt.close();
}

void _insertParishVillages(Database db, Map<String, Object?> byParish) {
  final PreparedStatement stmt = db.prepare(
    'INSERT INTO parish_villages (district, subcounty, parish, village, seq) VALUES (?, ?, ?, ?, ?);',
  );

  for (final Object? entry in byParish.values) {
    final Map<String, Object?> p = entry! as Map<String, Object?>;
    final String district = p['district']! as String;
    final String subcounty = p['subcounty']! as String;
    final String parish = p['parish']! as String;
    final List<Object?> villages = p['villages']! as List<Object?>;

    for (int i = 0; i < villages.length; i++) {
      stmt.execute(<Object?>[district, subcounty, parish, villages[i], i]);
    }
  }

  stmt.close();
}

void _insertVillageLookup(Database db, Map<String, Object?> byVillage) {
  final PreparedStatement stmt = db.prepare(
    'INSERT INTO village_lookup (village, parish, subcounty, constituency, district) '
    'VALUES (?, ?, ?, ?, ?);',
  );

  for (final Object? entry in byVillage.values) {
    final Map<String, Object?> v = entry! as Map<String, Object?>;
    stmt.execute(<Object?>[
      v['village'],
      v['parish'],
      v['subcounty'],
      v['constituency'],
      v['district'],
    ]);
  }

  stmt.close();
}

void _printCounts(Database db) {
  for (final String table in <String>[
    'districts',
    'subcounties',
    'subcounty_parishes',
    'parish_villages',
    'village_lookup',
  ]) {
    final ResultSet result = db.select('SELECT COUNT(*) AS c FROM $table;');
    stdout.writeln('$table: ${result.first['c']}');
  }
}
