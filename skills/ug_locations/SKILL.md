---
name: ug-locations-flutter
description: "Offline Flutter/Dart lookup and fuzzy search over Uganda's administrative-unit hierarchy (village -> parish -> subcounty -> county -> district -> sub-region -> region), backed by a bundled SQLite database. Use when working on the ug_locations package itself, its example app, or any app that consumes it — for API usage, platform setup, cascading location selectors, or debugging duplicate-value dropdown crashes."
metadata:
  version: 0.1.0
---

# ug_locations (Flutter/Dart)

Offline lookup + fuzzy search over Uganda's administrative hierarchy: **village → parish → subcounty → county → district → sub-region → region**. Data is bundled as a read-only SQLite asset (`assets/ug_locations.db`), built from `uganda-locations-full.csv` — a current administrative-units dataset that superseded the package's original 2022 Electoral Commission snapshot.

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
| `getDistricts()` | `Future<List<String>>` | All 146 districts, source order, no duplicates. |
| `getRegions()` | `Future<List<String>>` | All 4 regions, alphabetically sorted. |
| `getSubRegionsInRegion(region)` | `Future<List<String>>` | Alphabetically sorted. |
| `getDistrictsInSubRegion(subRegion)` | `Future<List<String>>` | Source order. |
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
  final String? county, region, subRegion;
}
class UgandaLocationParent {
  final String parish, subcounty, district;
}
```

`region`/`subRegion` are opt-in at the UI layer: `LocationPicker` stays a 4-level District → Subcounty → Parish → Village picker by default; pass `includeRegionHierarchy: true` to prepend Region → Sub-region dropdowns (see `lib/src/widgets/location_picker.dart`).

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

Web works out of the box, no setup required — `sqflite` has no web backend, so on web the package transparently opens the bundled database via a `sqlite3`-wasm backend (`lib/src/web/`) instead of `sqflite`.

## Known gotcha: duplicate values break dropdowns

`getParishesInSubcounty` and `getVillagesInParish` deliberately preserve duplicate entries if the source data ever has them (raw, non-deduped order). Feeding such a list straight into `DropdownMenuItem`s throws:

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
- Regenerating the database is a two-step pipeline: `tool/build_source_json.dart` builds `tool/source_data/data-optimized.json` from `uganda-locations-full.csv` (run first), then `tool/build_database.dart` builds `assets/ug_locations.db` from that JSON.
- The example app (`example/lib/main.dart`) demonstrates both a search box and a cascading district → subcounty → parish → village selector — check it for reference UI patterns.

## Data facts

146 districts, 52,000+ unique villages across 71,000+ administrative records, source: `uganda-locations-full.csv` (a current administrative-units dataset covering region/sub-region/district/county/subcounty/parish/village). Dart/Flutter port of the [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package, SQLite-backed instead of JSON-in-memory.

Static snapshot — no automatic update mechanism; re-running the two-step regeneration pipeline above against a newer CSV is the only way to refresh it.
