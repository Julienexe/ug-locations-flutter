import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ug_locations/ug_locations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late UgandaLocations ug;

  setUpAll(() async {
    final dbPath = p.absolute(p.join(Directory.current.path, 'assets', 'ug_locations.db'));
    final db = await UgLocationsDatabase.openFromPath(dbPath);
    ug = UgandaLocations.fromDatabase(db);
  });

  group('getDistricts', () {
    test('returns all 145 districts including known ones', () async {
      final districts = await ug.getDistricts();
      expect(districts.length, 145);
      expect(districts, contains('HOIMA'));
      expect(districts, contains('KAMPALA'));
    });
  });

  group('getLocationByVillage', () {
    test('resolves a known village to its full hierarchy', () async {
      final loc = await ug.getLocationByVillage('KASAMBYA I');
      expect(loc, isNotNull);
      expect(loc!.district, 'HOIMA');
      expect(loc.subcounty, 'BUHANIKA');
      expect(loc.parish, 'KATEREIGA');
      expect(loc.constituency, 'BUGAHYA COUNTY');
    });

    test('is case-insensitive', () async {
      final loc = await ug.getLocationByVillage('kasambya i');
      expect(loc?.district, 'HOIMA');
    });

    test('returns null for an unknown village', () async {
      final loc = await ug.getLocationByVillage('NOT A REAL VILLAGE');
      expect(loc, isNull);
    });
  });

  group('getPath', () {
    test('formats a human-readable path', () async {
      final path = await ug.getPath('KASAMBYA I');
      expect(path, 'HOIMA → BUHANIKA → KATEREIGA → KASAMBYA I');
    });

    test('returns null for an unknown village', () async {
      expect(await ug.getPath('NOT A REAL VILLAGE'), isNull);
    });
  });

  group('getParent', () {
    test('returns parish/subcounty/district of a village', () async {
      final parent = await ug.getParent('KASAMBYA I');
      expect(parent, isNotNull);
      expect(parent!.parish, 'KATEREIGA');
      expect(parent.subcounty, 'BUHANIKA');
      expect(parent.district, 'HOIMA');
    });
  });

  group('getSubcountiesInDistrict', () {
    test('lists subcounties for a known district, sorted', () async {
      final subcounties = await ug.getSubcountiesInDistrict('HOIMA');
      expect(subcounties, contains('BUHANIKA'));
      expect(subcounties, orderedEquals(List<String>.from(subcounties)..sort()));
    });

    test('returns empty list for unknown district', () async {
      expect(await ug.getSubcountiesInDistrict('NOT A DISTRICT'), isEmpty);
    });
  });

  group('getParishesInSubcounty', () {
    test('lists parishes for a known subcounty', () async {
      final parishes = await ug.getParishesInSubcounty('HOIMA', 'BUHANIKA');
      expect(parishes, contains('KATEREIGA'));
    });

    test('preserves duplicate parish names from source data', () async {
      final parishes = await ug.getParishesInSubcounty('HOIMA', 'KITOBA');
      expect(parishes.where((p) => p == 'KITOBA').length, 2);
    });
  });

  group('getVillagesInParish', () {
    test('lists villages for a known parish', () async {
      final villages = await ug.getVillagesInParish('HOIMA', 'BUHANIKA', 'KATEREIGA');
      expect(villages, contains('KASAMBYA I'));
      expect(villages.length, 6);
    });

    test('returns empty list for unknown parish', () async {
      final villages = await ug.getVillagesInParish('HOIMA', 'BUHANIKA', 'NOT A PARISH');
      expect(villages, isEmpty);
    });
  });

  group('search', () {
    test('finds matches across all administrative levels', () async {
      final results = await ug.search('KABANDA');
      expect(results, isNotEmpty);
      expect(
        results.every(
          (r) =>
              r.village.contains('KABANDA') ||
              r.district.contains('KABANDA') ||
              r.subcounty.contains('KABANDA') ||
              r.parish.contains('KABANDA'),
        ),
        isTrue,
      );
    });

    test('ranks exact village match first', () async {
      final results = await ug.search('KASAMBYA I');
      expect(results.first.village, 'KASAMBYA I');
    });

    test('ranks exact district match highly for a district-only query', () async {
      final results = await ug.search('KAMPALA', limit: 5);
      expect(results, isNotEmpty);
    });

    test('respects the limit option', () async {
      final results = await ug.search('KA', limit: 5);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('is case-insensitive', () async {
      final results = await ug.search('kasambya i');
      expect(results.first.village, 'KASAMBYA I');
    });
  });
}
