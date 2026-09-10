# ug_locations

A fast, offline Flutter/Dart library for Uganda's administrative hierarchy, forked from [`ug_locations`](https://github.com/NatumanyaGuy/ug-locations), with data sourced from the [`uganda`](https://github.com/kakandemanwell/uganda) npm package by [kakandemanwell](https://github.com/kakandemanwell) (browsable at [uganda-omega.vercel.app](https://uganda-omega.vercel.app/)).

Search villages, get complete administrative paths, and traverse village → parish → subcounty → county → district — fully offline via a bundled SQLite database.

[![pub package](https://img.shields.io/pub/v/ug_locations.svg)](https://pub.dev/packages/ug_locations)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- Fully offline — bundled SQLite database, no network calls
- Smart search — substring/prefix matching with relevance ranking
- Complete hierarchy traversal across all administrative levels
- Full null-safety, typed models

## Installation

```bash
flutter pub add ug_locations
```

## Quick Start

```dart
import 'package:ug_locations/ug_locations.dart';

Future<void> main() async {
  final ug = await UgandaLocations.getInstance();

  final location = await ug.getLocationByVillage('KASAMBYA I');
  // UgandaLocation(village: KASAMBYA I, parish: KATEREIGA,
  //   subcounty: BUHANIKA, county: BUGAHYA COUNTY, district: HOIMA,
  //   region: WESTERN, subRegion: BUNYORO)

  print(await ug.getPath('KASAMBYA I'));
  // "HOIMA → BUHANIKA → KATEREIGA → KASAMBYA I"
}
```

## Platform setup

- **Android / iOS**: works out of the box.
- **Desktop (Linux/macOS/Windows) or `dart test`**: `sqflite` needs the FFI implementation. Initialize once before calling any method:

  ```dart
  import 'package:sqflite_common_ffi/sqflite_ffi.dart';

  void main() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    runApp(const MyApp());
  }
  ```

- **Web**: works out of the box — no setup needed. `sqflite` has no built-in web backend, so on web the package transparently switches to a `sqlite3`-wasm backend instead, loading the bundled database into an in-memory filesystem on each page load.

## Usage

```dart
// Districts and hierarchy traversal
final districts = await ug.getDistricts();
final subcounties = await ug.getSubcountiesInDistrict('HOIMA');
final parishes = await ug.getParishesInSubcounty('HOIMA', 'BUHANIKA');
final villages = await ug.getVillagesInParish('HOIMA', 'BUHANIKA', 'KATEREIGA');
final parent = await ug.getParent('KASAMBYA I');
// UgandaLocationParent(parish: KATEREIGA, subcounty: BUHANIKA, district: HOIMA)

// Search — ranked, exact/prefix matches first
final results = await ug.search('KABANDA', limit: 5);
for (final loc in results) {
  print('${loc.village} (${loc.district})');
}
```

Common patterns this API supports: cascading district → subcounty → parish → village selectors, and village-name input validation via `getLocationByVillage(name) != null`. See `example/lib/main.dart` for a full working Flutter app with both.

### Region and sub-region (optional)

Every `UgandaLocation` also carries `region` and `subRegion`, and three lookup methods let you drive a region-first cascade if you want one:

```dart
final regions = await ug.getRegions(); // WESTERN, CENTRAL, EASTERN, NORTHERN
final subRegions = await ug.getSubRegionsInRegion('WESTERN'); // BUNYORO, ANKOLE, ...
final districts = await ug.getDistrictsInSubRegion('BUNYORO'); // HOIMA, ...
```

`LocationPicker` stays a 4-level District → Subcounty → Parish → Village picker by default; pass `includeRegionHierarchy: true` to prepend Region and Sub-region dropdowns:

```dart
LocationPicker(
  includeRegionHierarchy: true,
  onSelected: (location) => print(location.village),
)
```

## API Reference

| Method | Returns | Description |
| --- | --- | --- |
| `UgandaLocations.getInstance()` | `Future<UgandaLocations>` | Opens (and caches) the shared database instance |
| `getDistricts()` | `Future<List<String>>` | Returns all 146 districts |
| `getRegions()` | `Future<List<String>>` | Returns all 4 regions |
| `getSubRegionsInRegion(region)` | `Future<List<String>>` | Sub-regions in a region |
| `getDistrictsInSubRegion(subRegion)` | `Future<List<String>>` | Districts in a sub-region |
| `getLocationByVillage(village)` | `Future<UgandaLocation?>` | Full hierarchy for a village |
| `getPath(village)` | `Future<String?>` | Formatted path: "District → Subcounty → Parish → Village" |
| `search(query, {limit = 50})` | `Future<List<UgandaLocation>>` | Search across all levels, ranked by relevance |
| `getSubcountiesInDistrict(district)` | `Future<List<String>>` | Subcounties in a district |
| `getParishesInSubcounty(district, subcounty)` | `Future<List<String>>` | Parishes in a subcounty |
| `getVillagesInParish(district, subcounty, parish)` | `Future<List<String>>` | Villages in a parish |
| `getParent(village)` | `Future<UgandaLocationParent?>` | Parent parish/subcounty/district of a village |

### Types

```dart
class UgandaLocation {
  final String village;
  final String parish;
  final String subcounty;
  final String? county;
  final String district;
  final String? region;
  final String? subRegion;
}

class UgandaLocationParent {
  final String parish;
  final String subcounty;
  final String district;
}
```

## Data

146 districts, 52,000+ unique villages across 71,000+ administrative records, covering the full village → parish → subcounty → county → district → sub-region → region hierarchy. Sourced from the [`uganda`](https://github.com/kakandemanwell/uganda) npm package's dataset (also browsable at [uganda-omega.vercel.app](https://uganda-omega.vercel.app/)).

**Data freshness**: this replaces the package's original static snapshot of the July 2022 Electoral Commission list (145 districts, no region/sub-region data). Regenerating the bundled database from a newer source is a two-step, manual process — see `skills/ug_locations/SKILL.md` — there is still no automatic update mechanism. If you need data fresher than what's bundled here, check whether [`uganda`](https://github.com/kakandemanwell/uganda)/[uganda-omega.vercel.app](https://uganda-omega.vercel.app/) has since published an update.

## Acknowledgments

- Dart/Flutter port of the [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package by Natumanya Guy, reimplemented with a SQLite-backed storage layer.
- Administrative-unit data from the [`uganda`](https://github.com/kakandemanwell/uganda) npm package by [kakandemanwell](https://github.com/kakandemanwell) ([uganda-omega.vercel.app](https://uganda-omega.vercel.app/)) — also a good source to check for more current data than what's bundled here.


## Contributing

Contributions welcome — please open a Pull Request.

## License

MIT