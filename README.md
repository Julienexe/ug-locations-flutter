# ug_locations

A fast, offline Flutter/Dart library for Uganda's administrative hierarchy, forked from [`ug_locations`](https://github.com/NatumanyaGuy/ug-locations).

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
  //   subcounty: BUHANIKA, constituency: BUGAHYA COUNTY, district: HOIMA)

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

- **Web**: not supported. `sqflite` has no built-in web backend; see [`sqflite_common_ffi_web`](https://pub.dev/packages/sqflite_common_ffi_web) (untested here) or use the original [TypeScript package](https://github.com/NatumanyaGuy/ug-locations) for web.

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

## API Reference

| Method | Returns | Description |
| --- | --- | --- |
| `UgandaLocations.getInstance()` | `Future<UgandaLocations>` | Opens (and caches) the shared database instance |
| `getDistricts()` | `Future<List<String>>` | Returns all 145 districts |
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
  final String? constituency;
  final String district;
}

class UgandaLocationParent {
  final String parish;
  final String subcounty;
  final String district;
}
```

## Data

145 districts, 55,000+ villages, sourced from the [Uganda Electoral Commission Administrative Units PDF (July 2022)](https://www.ec.or.ug/election/administrative-units-uganda-july-2022).

**Data freshness**: this is a static snapshot of the July 2022 list. There is no automatic update mechanism today, so administrative changes since then (new districts, renamed or split units, etc.) are not reflected. If you need current boundaries, cross-check against the Electoral Commission's latest publication.

## Acknowledgments

Dart/Flutter port of the [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package by Natumanya Guy, reimplemented with a SQLite-backed storage layer. JSON data extract courtesy of [@gxnsamuel](https://github.com/gxnsamuel/UG-AU-DS-2022).

## Contributing

Contributions welcome — please open a Pull Request.

## License

MIT