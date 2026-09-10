@TestOn('chrome')
library;

// Exercises the sqlite3-wasm web backend end to end (asset loading,
// registering the in-memory VFS, opening the seeded database). Skipped by a
// plain `flutter test` - run explicitly with:
//   flutter test --platform chrome test/web/ug_locations_web_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ug_locations/ug_locations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UgandaLocations ug;

  setUpAll(() async {
    ug = await UgandaLocations.getInstance();
  });

  test('getDistricts returns all 146 districts', () async {
    final districts = await ug.getDistricts();
    expect(districts.length, 146);
    expect(districts, contains('HOIMA'));
  });

  test('getLocationByVillage resolves a known village', () async {
    final loc = await ug.getLocationByVillage('KASAMBYA I');
    expect(loc, isNotNull);
    expect(loc!.district, 'HOIMA');
    expect(loc.subcounty, 'BUHANIKA');
    expect(loc.parish, 'KATEREIGA');
  });

  test('search ranks an exact village match first', () async {
    final results = await ug.search('KASAMBYA I');
    expect(results, isNotEmpty);
    expect(results.first.village, 'KASAMBYA I');
  });
}
