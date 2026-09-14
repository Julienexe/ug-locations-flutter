import 'package:flutter/material.dart';

import '../ug_location.dart';
import '../ug_locations_repository.dart';

/// A cascading district -> subcounty -> parish -> village picker backed by
/// [UgandaLocations]. Pass [includeRegionHierarchy]: true to prepend
/// region -> sub-region levels above district.
///
/// By default it opens the shared [UgandaLocations] instance (via
/// [UgandaLocations.getInstance]); pass [ug] to inject a specific instance
/// instead, e.g. in tests.
///
/// ```dart
/// LocationPicker(
///   onSelected: (location) => print(location.village),
/// )
/// ```
class LocationPicker extends StatefulWidget {
  /// Creates a [LocationPicker].
  const LocationPicker({
    super.key,
    required this.onSelected,
    this.ug,
    @Deprecated('Use ug instead') this.locations,
    this.includeRegionHierarchy = false,
    this.initialLocation,
  });

  /// Called with the full hierarchy once the user has selected a village.
  /// Not called when [initialLocation] seeds the picker's dropdowns.
  final ValueChanged<UgandaLocation> onSelected;

  /// The [UgandaLocations] instance to query. Defaults to the shared
  /// singleton from [UgandaLocations.getInstance].
  final UgandaLocations? ug;

  /// Deprecated alternative to [ug] that takes a not-yet-resolved future.
  @Deprecated('Use ug instead')
  final Future<UgandaLocations>? locations;

  /// Whether to prepend Region and Sub-region dropdowns above District,
  /// narrowing the District list to the chosen sub-region. Defaults to
  /// `false`, which keeps the picker to its original four levels (District
  /// -> Subcounty -> Parish -> Village).
  final bool includeRegionHierarchy;

  /// A location to pre-select the dropdowns with, e.g. a previously saved
  /// value when editing an existing record. Each level's options are loaded
  /// so the seeded value is valid to show; [onSelected] is not called for it
  /// since the caller already has it.
  final UgandaLocation? initialLocation;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  UgandaLocations? _ug;

  List<String> _regions = <String>[];
  List<String> _subRegions = <String>[];
  List<String> _districts = <String>[];
  List<String> _subcounties = <String>[];
  List<String> _parishes = <String>[];
  List<String> _villages = <String>[];

  String? _region;
  String? _subRegion;
  String? _district;
  String? _subcounty;
  String? _parish;
  String? _village;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final UgandaLocations ug =
        // ignore: deprecated_member_use_from_same_package
        widget.ug ?? await (widget.locations ?? UgandaLocations.getInstance());
    if (widget.includeRegionHierarchy) {
      final List<String> regions = await ug.getRegions();
      if (!mounted) return;
      setState(() {
        _ug = ug;
        _regions = regions;
      });
    } else {
      final List<String> districts = await ug.getDistricts();
      if (!mounted) return;
      setState(() {
        _ug = ug;
        _districts = districts;
      });
    }
    final UgandaLocation? initial = widget.initialLocation;
    if (initial != null) {
      await _seedInitial(ug, initial);
    }
  }

  /// Loads each level's options for [initial] and sets it as the current
  /// selection at every level, without firing [LocationPicker.onSelected].
  Future<void> _seedInitial(UgandaLocations ug, UgandaLocation initial) async {
    String? region;
    String? subRegion;
    List<String> subRegions = _subRegions;
    List<String> districts = _districts;

    if (widget.includeRegionHierarchy && initial.region != null) {
      region = initial.region;
      subRegions = await ug.getSubRegionsInRegion(region!);
      subRegion = initial.subRegion;
      if (subRegion != null) {
        districts = await ug.getDistrictsInSubRegion(subRegion);
      }
    }
    // Fall back to the full district list so the seeded district is always a
    // valid dropdown item, even without region info to scope it by.
    if (!districts.contains(initial.district)) {
      districts = await ug.getDistricts();
    }

    final List<String> subcounties = await ug.getSubcountiesInDistrict(initial.district);
    final List<String> parishes = await ug.getParishesInSubcounty(
      initial.district,
      initial.subcounty,
    );
    final List<String> villages = await ug.getVillagesInParish(
      initial.district,
      initial.subcounty,
      initial.parish,
    );

    if (!mounted) return;
    setState(() {
      _region = region;
      _subRegion = subRegion;
      _subRegions = subRegions;
      _districts = districts;
      _district = initial.district;
      _subcounties = subcounties;
      _subcounty = initial.subcounty;
      _parishes = parishes;
      _parish = initial.parish;
      _villages = villages;
      _village = initial.village;
    });
  }

  Future<void> _onRegionChanged(String? region) async {
    setState(() {
      _region = region;
      _subRegion = null;
      _district = null;
      _subcounty = null;
      _parish = null;
      _village = null;
      _subRegions = <String>[];
      _districts = <String>[];
      _subcounties = <String>[];
      _parishes = <String>[];
      _villages = <String>[];
    });
    final UgandaLocations? ug = _ug;
    if (ug == null || region == null) return;
    final List<String> subRegions = await ug.getSubRegionsInRegion(region);
    if (!mounted) return;
    setState(() => _subRegions = subRegions);
  }

  Future<void> _onSubRegionChanged(String? subRegion) async {
    setState(() {
      _subRegion = subRegion;
      _district = null;
      _subcounty = null;
      _parish = null;
      _village = null;
      _districts = <String>[];
      _subcounties = <String>[];
      _parishes = <String>[];
      _villages = <String>[];
    });
    final UgandaLocations? ug = _ug;
    if (ug == null || subRegion == null) return;
    final List<String> districts = await ug.getDistrictsInSubRegion(subRegion);
    if (!mounted) return;
    setState(() => _districts = districts);
  }

  Future<void> _onDistrictChanged(String? district) async {
    setState(() {
      _district = district;
      _subcounty = null;
      _parish = null;
      _village = null;
      _subcounties = <String>[];
      _parishes = <String>[];
      _villages = <String>[];
    });
    final UgandaLocations? ug = _ug;
    if (ug == null || district == null) return;
    final List<String> subcounties = await ug.getSubcountiesInDistrict(district);
    if (!mounted) return;
    setState(() => _subcounties = subcounties);
  }

  Future<void> _onSubcountyChanged(String? subcounty) async {
    setState(() {
      _subcounty = subcounty;
      _parish = null;
      _village = null;
      _parishes = <String>[];
      _villages = <String>[];
    });
    final UgandaLocations? ug = _ug;
    if (ug == null || subcounty == null || _district == null) return;
    final List<String> parishes = await ug.getParishesInSubcounty(_district!, subcounty);
    if (!mounted) return;
    setState(() => _parishes = parishes);
  }

  Future<void> _onParishChanged(String? parish) async {
    setState(() {
      _parish = parish;
      _village = null;
      _villages = <String>[];
    });
    final UgandaLocations? ug = _ug;
    if (ug == null || parish == null || _district == null || _subcounty == null) return;
    final List<String> villages = await ug.getVillagesInParish(_district!, _subcounty!, parish);
    if (!mounted) return;
    setState(() => _villages = villages);
  }

  Future<void> _onVillageChanged(String? village) async {
    setState(() => _village = village);
    final UgandaLocations? ug = _ug;
    if (ug == null || village == null) return;
    final UgandaLocation? loc = await ug.getLocationByVillage(village);
    if (loc != null) widget.onSelected(loc);
  }

  @override
  Widget build(BuildContext context) {
    if (_ug == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.includeRegionHierarchy) ...<Widget>[
          DropdownButtonFormField<String>(
            initialValue: _region,
            decoration: const InputDecoration(labelText: 'Region'),
            items: <DropdownMenuItem<String>>[
              for (final String r in _regions.toSet()) DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: _onRegionChanged,
          ),
          DropdownButtonFormField<String>(
            initialValue: _subRegion,
            decoration: const InputDecoration(labelText: 'Sub-region'),
            items: <DropdownMenuItem<String>>[
              for (final String s in _subRegions.toSet())
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: _subRegions.isEmpty ? null : _onSubRegionChanged,
          ),
        ],
        DropdownButtonFormField<String>(
          initialValue: _district,
          decoration: const InputDecoration(labelText: 'District'),
          items: <DropdownMenuItem<String>>[
            for (final String d in _districts.toSet()) DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: widget.includeRegionHierarchy && _districts.isEmpty
              ? null
              : _onDistrictChanged,
        ),
        DropdownButtonFormField<String>(
          initialValue: _subcounty,
          decoration: const InputDecoration(labelText: 'Subcounty'),
          items: <DropdownMenuItem<String>>[
            for (final String s in _subcounties.toSet())
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: _subcounties.isEmpty ? null : _onSubcountyChanged,
        ),
        DropdownButtonFormField<String>(
          initialValue: _parish,
          decoration: const InputDecoration(labelText: 'Parish'),
          items: <DropdownMenuItem<String>>[
            for (final String p in _parishes.toSet()) DropdownMenuItem(value: p, child: Text(p)),
          ],
          onChanged: _parishes.isEmpty ? null : _onParishChanged,
        ),
        DropdownButtonFormField<String>(
          initialValue: _village,
          decoration: const InputDecoration(labelText: 'Village'),
          items: <DropdownMenuItem<String>>[
            for (final String v in _villages.toSet()) DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: _villages.isEmpty ? null : _onVillageChanged,
        ),
      ],
    );
  }
}
