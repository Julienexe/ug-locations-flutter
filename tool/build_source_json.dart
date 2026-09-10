// Converts uganda-locations-full.csv into tool/source_data/data-optimized.json,
// the intermediate format tool/build_database.dart consumes to build
// assets/ug_locations.db.
//
// Run with: dart run tool/build_source_json.dart
//
// Dedup semantics (must match what tool/build_database.dart expects - see
// the comment at the top of that file):
//   - byVillage:   one entry per village name; first occurrence in the CSV
//                  wins when the same village name recurs elsewhere.
//   - byParish:    canonical (deduped) village list per district/subcounty/
//                  parish key, merging every row that shares that key
//                  regardless of where it appears in the file.
//   - bySubcounty: raw parish list per district/subcounty, one entry per
//                  contiguous run of rows sharing a parish name - so the
//                  same parish name can appear as two separate entries if it
//                  recurs non-contiguously within a subcounty.
//
// All text fields are uppercased on the way in: the CSV is title-case, but
// every lookup in lib/src/ug_locations_repository.dart uppercases its query
// input, so the stored data must be uppercase to match.
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

void main() {
  final File sourceFile = File('uganda-locations-full.csv');
  stdout.writeln('Reading ${sourceFile.path}...');
  final String raw = sourceFile.readAsStringSync();
  final List<List<dynamic>> rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(raw);

  final List<String> header = rows.first.map((dynamic h) => h.toString()).toList();
  final int idxRegion = header.indexOf('region');
  final int idxSubRegion = header.indexOf('sub_region');
  final int idxDistrict = header.indexOf('district');
  final int idxCounty = header.indexOf('county');
  final int idxSubcounty = header.indexOf('subcounty');
  final int idxParish = header.indexOf('parish');
  final int idxVillage = header.indexOf('village');

  final List<String> districts = <String>[];
  final Set<String> seenDistricts = <String>{};
  final Map<String, Map<String, Object?>> byVillage = <String, Map<String, Object?>>{};
  final Map<String, List<String>> parishVillages = <String, List<String>>{};
  final Map<String, Map<String, String>> parishMeta = <String, Map<String, String>>{};
  final Map<String, Map<String, Object?>> bySubcounty = <String, Map<String, Object?>>{};

  String? lastSubcountyKey;
  String? lastParish;
  List<String>? currentRun;
  int skipped = 0;

  for (final List<dynamic> row in rows.skip(1)) {
    if (row.length < header.length) {
      skipped++;
      continue;
    }
    String cell(int i) => row[i].toString().trim().toUpperCase();

    final String region = cell(idxRegion);
    final String subRegion = cell(idxSubRegion);
    final String district = cell(idxDistrict);
    final String rawCounty = cell(idxCounty);
    final String? county = rawCounty.isEmpty ? null : rawCounty;
    final String subcounty = cell(idxSubcounty);
    final String parish = cell(idxParish);
    final String village = cell(idxVillage);

    if (seenDistricts.add(district)) districts.add(district);

    byVillage.putIfAbsent(
      village,
      () => <String, Object?>{
        'village': village,
        'parish': parish,
        'subcounty': subcounty,
        'county': county,
        'district': district,
        'region': region,
        'subRegion': subRegion,
      },
    );

    final String parishKey = '$district||$subcounty||$parish';
    final List<String> canonicalVillages = parishVillages.putIfAbsent(
      parishKey,
      () => <String>[],
    );
    if (!canonicalVillages.contains(village)) canonicalVillages.add(village);
    parishMeta[parishKey] = <String, String>{
      'district': district,
      'subcounty': subcounty,
      'parish': parish,
    };

    final String subcountyKey = '$district||$subcounty';
    final Map<String, Object?> subcountyEntry = bySubcounty.putIfAbsent(
      subcountyKey,
      () => <String, Object?>{
        'district': district,
        'subcounty': subcounty,
        'county': county,
        'region': region,
        'subRegion': subRegion,
        'data': <Map<String, Object?>>[],
      },
    );
    final List<Map<String, Object?>> data =
        subcountyEntry['data']! as List<Map<String, Object?>>;

    if (subcountyKey != lastSubcountyKey || parish != lastParish) {
      currentRun = <String>[];
      data.add(<String, Object?>{'parish': parish, 'villages': currentRun});
    }
    currentRun!.add(village);
    lastSubcountyKey = subcountyKey;
    lastParish = parish;
  }

  final Map<String, Object?> byParish = <String, Object?>{
    for (final MapEntry<String, Map<String, String>> entry in parishMeta.entries)
      entry.key: <String, Object?>{...entry.value, 'villages': parishVillages[entry.key]},
  };

  final Map<String, Object?> output = <String, Object?>{
    'districts': districts,
    'byVillage': byVillage,
    'byParish': byParish,
    'bySubcounty': bySubcounty,
  };

  final File outFile = File('tool/source_data/data-optimized.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(json.encode(output));

  stdout.writeln('districts: ${districts.length}');
  stdout.writeln('villages (collapsed): ${byVillage.length}');
  stdout.writeln('parishes (canonical): ${byParish.length}');
  stdout.writeln('subcounties: ${bySubcounty.length}');
  if (skipped > 0) stdout.writeln('skipped malformed rows: $skipped');
  stdout.writeln('Wrote ${outFile.path}');
}
