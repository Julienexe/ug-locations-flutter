---
name: ug-locations-flutter
description: "Offline Flutter/Dart lookup and fuzzy search over Uganda's administrative-unit hierarchy (village -> parish -> subcounty -> constituency -> district), backed by a bundled SQLite database. Use when working on the ug_locations package itself, its example app, or any app that consumes it — for API usage, platform setup, cascading location selectors, or debugging duplicate-value dropdown crashes."
metadata:
  version: 0.1.0
---

# ug_locations (Flutter/Dart)

Offline lookup + fuzzy search over Uganda's administrative hierarchy: **village → parish → subcounty → constituency → district**. Data is bundled as a read-only SQLite asset (`assets/ug_locations.db`), sourced from the Uganda Electoral Commission's 2022 Administrative Units.

## When to Use

- Building or debugging code that imports `package:ug_locations/ug_locations.dart`.
- Adding a Uganda district/subcounty/parish/village picker or cascading selector.
- Implementing search/autocomplete/validation over Uganda location names.
- Working in this repo: the library (`lib/`), the example app (`example/`), or `tool/build_database.dart` (regenerates `assets/ug_locations.db` from `tool/source_data/data-optimized.json`).
- Debugging a `DropdownButtonFormField`/`DropdownButton` assertion failure ("exactly one item with value X") in an app that populates items from this package — see **Known gotcha** below.

## Core API

Entry point: `UgandaLocations.getInstance()` — opens (and caches) the shared DB connection.

| Method | Returns | Notes |
|---|---|---|
| `getDistricts()` | `Future<List<String>>` | All 145 districts, source order, no duplicates. |
| `getSubcountiesInDistrict(district)` | `Future<List<String>>` | Alphabetically sorted. |
| `getParishesInSubcounty(district, subcounty)` | `Future<List<String>>` | Source order — **duplicate names are preserved on purpose** (mirrors the original data / JS package). |
| `getVillagesInParish(district, subcounty, parish)` | `Future<List<String>>` | Source order, duplicates preserved. |
| `getLocationByVillage(village)` | `Future<UgandaLocation?>` | Case-insensitive, trims input. `null` if not found. |
| `getParent(village)` | `Future<UgandaLocationParent?>` | parish/subcounty/district only. |
| `getPath(village)` | `Future<String?>` | `"DISTRICT → SUBCOUNTY → PARISH → VILLAGE"`. |
| `search(query, {limit = 50})` | `Future<List<UgandaLocation>>` | Substring/prefix match across all levels, ranked (exact village > exact district > exact subcounty > prefix match), then alphabetical. |

All district/subcounty/parish/village arguments are matched case-insensitively (values are uppercased + trimmed internally) — but returned strings are already uppercase, so pass through what earlier calls returned.

Types (`lib/src/ug_location.dart`):
```dart
class UgandaLocation {
  final String village, parish, subcounty, district;
  final String? constituency;
}
class UgandaLocationParent {
  final String parish, subcounty, district;
}
```

## Platform setup (required outside Android/iOS)

`sqflite` needs the FFI backend on desktop and in plain `dart test`/`flutter test` runs. Call this once before any `ug_locations` method:

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}
```

Web is **not supported** (no bundled `sqflite` web backend).

## Known gotcha: duplicate values break dropdowns

`getParishesInSubcounty` and `getVillagesInParish` deliberately preserve duplicate entries when the source data has them (e.g. district ARUA / subcounty ARIVU lists the parish "ARIVU" twice). Feeding such a list straight into `DropdownMenuItem`s throws:

```
'items == null || items.isEmpty || ... items.where((item) => item.value == value).length == 1'
```

Fix at the UI layer, not the library — dedupe when building dropdown items (order-preserving):

```dart
items: [
  for (final p in _parishes.toSet())
    DropdownMenuItem(value: p, child: Text(p)),
],
```

Don't dedupe the underlying state list itself if you also display a count (e.g. village totals) — only dedupe the list handed to the dropdown widget.

## Testing / working in this repo

- Tests (`test/ug_locations_test.dart`) open the DB directly via `UgLocationsDatabase.openFromPath('assets/ug_locations.db')` + `UgandaLocations.fromDatabase(db)`, bypassing the asset-copy path — use this pattern for new tests.
- `setUpAll` must call `sqfliteFfiInit()` / set `databaseFactory = databaseFactoryFfi` first.
- To inspect the bundled DB ad hoc (no `sqlite3` CLI available in this environment), write a small Dart script using `sqflite_common_ffi` and run it with `dart run` from within `example/` (it has the FFI dependency); pass an **absolute** path to the `.db` file.
- Regenerating the database: `tool/build_database.dart` builds `assets/ug_locations.db` from `tool/source_data/data-optimized.json`.
- The example app (`example/lib/main.dart`) demonstrates both a search box and a cascading district → subcounty → parish → village selector — check it for reference UI patterns.

## Data facts

145 districts, 55,000+ villages, source: Uganda Electoral Commission Administrative Units (July 2022). Dart/Flutter port of the [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package, SQLite-backed instead of JSON-in-memory.
