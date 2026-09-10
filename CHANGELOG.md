## 0.2.0

- Added `LocationPicker` (cascading District → Subcounty → Parish → Village selector) and `LocationSearchField` (autocomplete search field) — ready-made Flutter widgets exported from `package:ug_locations/ug_locations.dart`, so consumers no longer have to hand-roll UI on top of the lookup API. See the example app's "Bundled widgets" tab.
- Added web support: a new `QueryExecutor` abstraction lets the package run on `sqflite` (Android/iOS/desktop, unchanged) or a new `sqlite3`-wasm backend (web), bundling `assets/sqlite3.wasm` and adding `Sqlite3WasmQueryExecutor`/`UgLocationsDatabaseWeb` for that platform.
- Replaced the bundled data source: `assets/ug_locations.db` is now built from a current administrative-units dataset (146 districts, 52,000+ unique villages) instead of the July 2022 Electoral Commission snapshot (145 districts).
- Added `region` and `subRegion` to `UgandaLocation`, plus `getRegions()`, `getSubRegionsInRegion(region)`, and `getDistrictsInSubRegion(subRegion)` on `UgandaLocations`.
- `LocationPicker` gained an opt-in `includeRegionHierarchy` parameter (defaults to `false`) that prepends Region and Sub-region dropdowns above District.
- **Breaking**: renamed `UgandaLocation.constituency` to `UgandaLocation.county`, now sourced from the new dataset's `county` column instead of an electoral constituency name.
- Added `tool/build_source_json.dart`, which builds `tool/source_data/data-optimized.json` from `uganda-locations-full.csv` — the new first step in regenerating the bundled database.
- Fixed: on Android/iOS/desktop, an app that had already run against an older `ug_locations` version would keep using its previously-cached copy of `ug_locations.db` forever (it was only ever copied "if not already present"), so this schema change would crash existing installs with `no such column: region`. Cached copies are now invalidated by a schema-version marker and re-copied automatically on the next app restart.

## 0.1.1

- Update README documentation.

## 0.1.0

- Initial release: a Dart/Flutter port of the [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package.
- SQLite-backed storage (bundled `assets/ug_locations.db`), queried via `sqflite`.
- Full API parity with the original JS package: `getDistricts`, `getLocationByVillage`, `getVillagesInParish`, `getParishesInSubcounty`, `getSubcountiesInDistrict`, `search`, `getPath`, `getParent` — all now `Future`-based.
