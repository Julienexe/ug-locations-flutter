import 'dart:convert';

/// A single administrative location record: a village and its full
/// hierarchy up to district.
class UgandaLocation {
  /// Creates a location record from its individual hierarchy fields.
  const UgandaLocation({
    required this.village,
    required this.parish,
    required this.subcounty,
    this.county,
    required this.district,
    this.region,
    this.subRegion,
  });

  /// Builds a [UgandaLocation] from a `village`/`parish`/`subcounty`/
  /// `county`/`district`/`region`/`sub_region`-keyed map, e.g. a raw SQLite
  /// row.
  factory UgandaLocation.fromMap(Map<String, Object?> map) {
    return UgandaLocation(
      village: map['village'] as String,
      parish: map['parish'] as String,
      subcounty: map['subcounty'] as String,
      county: map['county'] as String?,
      district: map['district'] as String,
      region: map['region'] as String?,
      subRegion: map['sub_region'] as String?,
    );
  }

  /// Builds a [UgandaLocation] from a JSON string previously produced by
  /// [toJson].
  factory UgandaLocation.fromJson(String json) =>
      UgandaLocation.fromMap(jsonDecode(json) as Map<String, Object?>);

  /// The village name.
  final String village;

  /// The parish the village belongs to.
  final String parish;

  /// The subcounty the parish belongs to.
  final String subcounty;

  /// The county covering this location, if known. `null` for locations
  /// inside a city division, which aren't organized into counties.
  final String? county;

  /// The district the subcounty belongs to.
  final String district;

  /// The region the district belongs to (Central, Eastern, Northern, or
  /// Western), if known.
  final String? region;

  /// The sub-region the district belongs to, if known.
  final String? subRegion;

  /// Converts this location to a `village`/`parish`/`subcounty`/`county`/
  /// `district`/`region`/`subRegion`-keyed map, suitable for [fromMap] or
  /// storage (e.g. Firestore, `SharedPreferences`).
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'village': village,
      'parish': parish,
      'subcounty': subcounty,
      'county': county,
      'district': district,
      'region': region,
      'sub_region': subRegion,
    };
  }

  /// Encodes this location as a JSON string. Round-trips with [fromJson].
  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) {
    return other is UgandaLocation &&
        other.village == village &&
        other.parish == parish &&
        other.subcounty == subcounty &&
        other.county == county &&
        other.district == district &&
        other.region == region &&
        other.subRegion == subRegion;
  }

  @override
  int get hashCode =>
      Object.hash(village, parish, subcounty, county, district, region, subRegion);

  @override
  String toString() {
    return 'UgandaLocation(village: $village, parish: $parish, '
        'subcounty: $subcounty, county: $county, district: $district, '
        'region: $region, subRegion: $subRegion)';
  }
}

/// The parent administrative units of a village (everything but the village
/// name itself).
class UgandaLocationParent {
  /// Creates a parent record from its individual hierarchy fields.
  const UgandaLocationParent({
    required this.parish,
    required this.subcounty,
    required this.district,
  });

  /// Builds a [UgandaLocationParent] from a `parish`/`subcounty`/
  /// `district`-keyed map.
  factory UgandaLocationParent.fromMap(Map<String, Object?> map) {
    return UgandaLocationParent(
      parish: map['parish'] as String,
      subcounty: map['subcounty'] as String,
      district: map['district'] as String,
    );
  }

  /// Builds a [UgandaLocationParent] from a JSON string previously produced
  /// by [toJson].
  factory UgandaLocationParent.fromJson(String json) =>
      UgandaLocationParent.fromMap(jsonDecode(json) as Map<String, Object?>);

  /// The parish the village belongs to.
  final String parish;

  /// The subcounty the parish belongs to.
  final String subcounty;

  /// The district the subcounty belongs to.
  final String district;

  /// Converts this record to a `parish`/`subcounty`/`district`-keyed map,
  /// suitable for [fromMap] or storage (e.g. Firestore, `SharedPreferences`).
  Map<String, Object?> toMap() {
    return <String, Object?>{'parish': parish, 'subcounty': subcounty, 'district': district};
  }

  /// Encodes this record as a JSON string. Round-trips with [fromJson].
  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) {
    return other is UgandaLocationParent &&
        other.parish == parish &&
        other.subcounty == subcounty &&
        other.district == district;
  }

  @override
  int get hashCode => Object.hash(parish, subcounty, district);

  @override
  String toString() {
    return 'UgandaLocationParent(parish: $parish, subcounty: $subcounty, district: $district)';
  }
}
