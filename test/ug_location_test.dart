import 'package:flutter_test/flutter_test.dart';
import 'package:ug_locations/ug_locations.dart';

void main() {
  group('UgandaLocation serialization', () {
    const loc = UgandaLocation(
      village: 'KASAMBYA I',
      parish: 'KATEREIGA',
      subcounty: 'BUHANIKA',
      county: 'BUGAHYA COUNTY',
      district: 'HOIMA',
      region: 'WESTERN',
      subRegion: 'BUNYORO',
    );

    test('toMap/fromMap round-trips', () {
      expect(UgandaLocation.fromMap(loc.toMap()), loc);
    });

    test('toJson/fromJson round-trips', () {
      expect(UgandaLocation.fromJson(loc.toJson()), loc);
    });

    test('round-trips null county/region/subRegion', () {
      const noExtras = UgandaLocation(
        village: 'KASAMBYA I',
        parish: 'KATEREIGA',
        subcounty: 'BUHANIKA',
        district: 'HOIMA',
      );
      expect(UgandaLocation.fromJson(noExtras.toJson()), noExtras);
    });
  });

  group('UgandaLocationParent serialization', () {
    const parent = UgandaLocationParent(
      parish: 'KATEREIGA',
      subcounty: 'BUHANIKA',
      district: 'HOIMA',
    );

    test('toMap/fromMap round-trips', () {
      expect(UgandaLocationParent.fromMap(parent.toMap()), parent);
    });

    test('toJson/fromJson round-trips', () {
      expect(UgandaLocationParent.fromJson(parent.toJson()), parent);
    });
  });
}
