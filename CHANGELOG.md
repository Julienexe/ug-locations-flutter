## 0.1.0

- Initial release: a Dart/Flutter port of the [`ug-locations`](https://github.com/NatumanyaGuy/ug-locations) npm package.
- SQLite-backed storage (bundled `assets/ug_locations.db`), queried via `sqflite`.
- Full API parity with the original JS package: `getDistricts`, `getLocationByVillage`, `getVillagesInParish`, `getParishesInSubcounty`, `getSubcountiesInDistrict`, `search`, `getPath`, `getParent` — all now `Future`-based.
