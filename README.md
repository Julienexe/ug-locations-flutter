# ug_locations

**A fast, offline Flutter/Dart library for Uganda's administrative hierarchy forked from [`ug_locations`](https://github.com/NatumanyaGuy/ug-locations).**

Instantly search villages, get complete administrative paths, and traverse Uganda's location hierarchy from village → parish → subcounty → county → district — all offline, backed by a bundled SQLite database.

[![pub package](https://img.shields.io/pub/v/ug_locations.svg)](https://pub.dev/packages/ug_locations)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- 📦 **Fully offline** — bundled SQLite database, no network calls
- 🔍 **Smart search** — substring/prefix matching with relevance ranking
- 🗺️ **Complete hierarchy** — traverse all administrative levels
- 💪 **Dart native** — full null-safety, typed models

## 📦 Installation

```bash
flutter pub add ug_locations
```

## 🚀 Quick Start

```dart
import 'package:ug_locations/ug_locations.dart';

Future<void> main() async {
  final ug = await UgandaLocations.getInstance();

  // Get complete location hierarchy from a village name
  final location = await ug.getLocationByVillage('KASAMBYA I');
  print(location);
  // UgandaLocation(village: KASAMBYA I, parish: KATEREIGA,
  //   subcounty: BUHANIKA, constituency: BUGAHYA COUNTY, district: HOIMA)

  // Get human-readable path
  print(await ug.getPath('KASAMBYA I'));
  // "HOIMA → BUHANIKA → KATEREIGA → KASAMBYA I"
}
```

## ⚙️ Platform setup

- **Android / iOS**: works out of the box.
- **Desktop (Linux/macOS/Windows) or plain `dart test`**: `sqflite` requires the FFI implementation on these platforms. Before calling any `ug_locations` method, initialize it once:

  ```dart
  import 'package:sqflite_common_ffi/sqflite_ffi.dart';

  void main() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    runApp(const MyApp());
  }
  ```

- **Web**: not supported in this release. `sqflite` has no built-in web implementation; if you need web support, see [`sqflite_common_ffi_web`](https://pub.dev/packages/sqflite_common_ffi_web) as a starting point (not tested by this package) or use [`ug_locations`](https://github.com/NatumanyaGuy/ug-locations) the original typescript package that this is based off of.

## 📚 Usage Examples

### Working with Districts

```dart
// Get all districts in Uganda
final districts = await ug.getDistricts();
print(districts.take(5));
// (ABIM, ADJUMANI, AGAGO, ALEBTONG, AMOLATAR)

// List all subcounties in a district
final subcounties = await ug.getSubcountiesInDistrict('HOIMA');
print(subcounties);
// [BOMBO, BUHANIKA, BULINDI TOWN COUNCIL, BURARU, ...]
```

### Traversing the Hierarchy

```dart
// Get all parishes in a subcounty
final parishes = await ug.getParishesInSubcounty('HOIMA', 'BUHANIKA');
print(parishes);
// [KATEREIGA, KIKEREGE, ...]

// Get all villages in a parish
final villages = await ug.getVillagesInParish('HOIMA', 'BUHANIKA', 'KATEREIGA');
print(villages);
// [KASAMBYA I, KATEREIGA I, KATEREIGA II, KASAMBYA II, KISUGA, KIKABURA]

// Get parent location of a village
final parent = await ug.getParent('KASAMBYA I');
print(parent);
// UgandaLocationParent(parish: KATEREIGA, subcounty: BUHANIKA, district: HOIMA)
```

### Searching Locations

```dart
// Search across all administrative levels
final results = await ug.search('KABANDA');
for (final loc in results.take(3)) {
  print('${loc.village} (${loc.district})');
}
// KABANDA (NTUNGAMO)
// KABANDA A (KYANKWANZI)
// KABANDA B (KYANKWANZI)

// Limit search results
final topResults = await ug.search('kaba', limit: 5);
print(topResults.length); // 5

// Search prioritizes exact matches and start-with matches
final kampalaResults = await ug.search('KAMPALA');
// Villages/locations starting with "KAMPALA" appear first
```

### Building Location Forms

```dart
// Example: cascading location selector
Future<void> buildLocationSelector() async {
  final districts = await ug.getDistricts();

  final selectedDistrict = 'KAMPALA';
  final subcounties = await ug.getSubcountiesInDistrict(selectedDistrict);

  final selectedSubcounty = 'CENTRAL DIVISION';
  final parishes = await ug.getParishesInSubcounty(selectedDistrict, selectedSubcounty);

  final selectedParish = 'INDUSTRIAL AREA';
  final villages = await ug.getVillagesInParish(
    selectedDistrict,
    selectedSubcounty,
    selectedParish,
  );
}
```

See `example/lib/main.dart` for a full working Flutter app demonstrating both a search box and a cascading district → subcounty → parish → village selector.

### Validating User Input

```dart
Future<bool> validateLocation(String villageName) async {
  final location = await ug.getLocationByVillage(villageName);
  return location != null;
}

Future<List<UgandaLocation>> getSuggestions(String partial) {
  return ug.search(partial, limit: 10);
}
```

## 📖 API Reference

| Method                                              | Returns                          | Description                                                        |
| ---------------------------------------------------- | --------------------------------- | -------------------------------------------------------------------- |
| `UgandaLocations.getInstance()`                     | `Future<UgandaLocations>`        | Opens (and caches) the shared database instance                    |
| `getDistricts()`                                    | `Future<List<String>>`           | Returns all 145 districts                                          |
| `getLocationByVillage(village)`                     | `Future<UgandaLocation?>`        | Full hierarchy for a village                                       |
| `getPath(village)`                                  | `Future<String?>`                | Formatted path: "District → Subcounty → Parish → Village"          |
| `search(query, {limit = 50})`                       | `Future<List<UgandaLocation>>`   | Search across all levels, ranked by relevance                      |
| `getSubcountiesInDistrict(district)`                | `Future<List<String>>`           | Subcounties in a district                                          |
| `getParishesInSubcounty(district, subcounty)`       | `Future<List<String>>`           | Parishes in a subcounty                                            |
| `getVillagesInParish(district, subcounty, parish)`  | `Future<List<String>>`           | Villages in a parish                                                |
| `getParent(village)`                                | `Future<UgandaLocationParent?>`  | Parent parish/subcounty/district of a village                      |

### Type Definitions

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

## 🗺️ Data Coverage

- **145 Districts**
- **55,000+ unique villages**
- **Complete administrative hierarchy** (Village → Parish → Subcounty → Constituency → District)

## 📊 Data Source

Based on Uganda Electoral Commission Administrative Units - 2022.

**Source Document:** [Uganda Electoral Commission Administrative Units PDF (July 2022)](https://www.ec.or.ug/election/administrative-units-uganda-july-2022)

## 🙏 Acknowledgments

This package is a Dart/Flutter port of the JavaScript/TypeScript [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package by Natumanya Guy, reimplemented from scratch with a SQLite-backed storage layer for Flutter apps. Thanks also to [@gxnsamuel](https://github.com/gxnsamuel/UG-AU-DS-2022) for providing the original JSON extract of the Uganda Electoral Commission Administrative Units PDF that both packages' data is derived from.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT

## 🐛 Issues

Found a bug or have a feature request? Open an issue on the repository.

---

**Made with ❤️ in Uganda** 🇺🇬
