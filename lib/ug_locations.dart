/// Offline lookup and fuzzy search over Uganda's administrative-unit
/// hierarchy (village -> parish -> subcounty -> constituency -> district),
/// backed by a bundled SQLite database.
library;

export 'src/ug_location.dart' show UgandaLocation, UgandaLocationParent;
export 'src/ug_locations_database.dart' show UgLocationsDatabase;
export 'src/ug_locations_repository.dart' show UgandaLocations;
