import 'package:flutter/material.dart';

import '../ug_location.dart';
import '../ug_locations_repository.dart';

/// A text field that searches Uganda's administrative-unit hierarchy as the
/// user types (via [UgandaLocations.search]) and lets them pick a matching
/// [UgandaLocation] from a suggestions list.
///
/// By default it opens the shared [UgandaLocations] instance (via
/// [UgandaLocations.getInstance]); pass [locations] to inject a specific
/// instance instead, e.g. in tests.
///
/// ```dart
/// LocationSearchField(
///   onSelected: (location) => print(location.village),
/// )
/// ```
class LocationSearchField extends StatefulWidget {
  /// Creates a [LocationSearchField].
  const LocationSearchField({
    super.key,
    required this.onSelected,
    this.locations,
    this.limit = 3,
    this.decoration,
  });

  /// Called when the user picks a location from the suggestions list.
  final ValueChanged<UgandaLocation> onSelected;

  /// The [UgandaLocations] instance to search against. Defaults to the
  /// shared singleton from [UgandaLocations.getInstance].
  final Future<UgandaLocations>? locations;

  /// Maximum number of suggestions to fetch per keystroke.
  final int limit;

  /// Input decoration for the underlying text field. Defaults to a field
  /// labeled "Search location".
  final InputDecoration? decoration;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  UgandaLocations? _ug;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final UgandaLocations ug = await (widget.locations ?? UgandaLocations.getInstance());
    if (!mounted) return;
    setState(() => _ug = ug);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<UgandaLocation>(
      displayStringForOption: (UgandaLocation loc) => loc.village,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        final UgandaLocations? ug = _ug;
        if (ug == null || textEditingValue.text.trim().isEmpty) {
          return const Iterable<UgandaLocation>.empty();
        }
        return ug.search(textEditingValue.text, limit: widget.limit);
      },
      onSelected: widget.onSelected,
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration:
                  widget.decoration ?? const InputDecoration(labelText: 'Search location'),
              onFieldSubmitted: (String value) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<UgandaLocation> onSelectedOption,
            Iterable<UgandaLocation> options,
          ) {
            final List<UgandaLocation> optionsList = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final UgandaLocation loc in optionsList)
                        ListTile(
                          title: Text(loc.village),
                          subtitle: Text('${loc.parish} → ${loc.subcounty} → ${loc.district}'),
                          onTap: () => onSelectedOption(loc),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }
}
