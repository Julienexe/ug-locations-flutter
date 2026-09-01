/// A single administrative location record: a village and its full
/// hierarchy up to district.
class UgandaLocation {
  const UgandaLocation({
    required this.village,
    required this.parish,
    required this.subcounty,
    this.constituency,
    required this.district,
  });

  factory UgandaLocation.fromMap(Map<String, Object?> map) {
    return UgandaLocation(
      village: map['village'] as String,
      parish: map['parish'] as String,
      subcounty: map['subcounty'] as String,
      constituency: map['constituency'] as String?,
      district: map['district'] as String,
    );
  }

  final String village;
  final String parish;
  final String subcounty;
  final String? constituency;
  final String district;

  @override
  bool operator ==(Object other) {
    return other is UgandaLocation &&
        other.village == village &&
        other.parish == parish &&
        other.subcounty == subcounty &&
        other.constituency == constituency &&
        other.district == district;
  }

  @override
  int get hashCode => Object.hash(village, parish, subcounty, constituency, district);

  @override
  String toString() {
    return 'UgandaLocation(village: $village, parish: $parish, '
        'subcounty: $subcounty, constituency: $constituency, district: $district)';
  }
}

/// The parent administrative units of a village (everything but the village
/// name itself).
class UgandaLocationParent {
  const UgandaLocationParent({
    required this.parish,
    required this.subcounty,
    required this.district,
  });

  final String parish;
  final String subcounty;
  final String district;

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
