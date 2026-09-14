import 'dart:async';

import 'package:flutter/material.dart';

import '../ug_location.dart';
import '../ug_locations_repository.dart';

/// A text field that searches Uganda's administrative-unit hierarchy as the
/// user types (via [UgandaLocations.search]) and lets them pick a matching
/// [UgandaLocation] from a suggestions list.
///
/// By default it opens the shared [UgandaLocations] instance (via
/// [UgandaLocations.getInstance]); pass [ug] to inject a specific instance
/// instead, e.g. in tests.
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
    this.ug,
    @Deprecated('Use ug instead') this.locations,
    this.limit = 3,
    this.decoration,
    this.initialValue,
    this.onTextChanged,
    this.debounceDuration,
  });

  /// Called when the user picks a location from the suggestions list.
  final ValueChanged<UgandaLocation> onSelected;

  /// The [UgandaLocations] instance to search against. Defaults to the
  /// shared singleton from [UgandaLocations.getInstance].
  final UgandaLocations? ug;

  /// Deprecated alternative to [ug] that takes a not-yet-resolved future.
  @Deprecated('Use ug instead')
  final Future<UgandaLocations>? locations;

  /// Maximum number of suggestions to fetch per keystroke.
  final int limit;

  /// Input decoration for the underlying text field. Defaults to a field
  /// labeled "Search location".
  final InputDecoration? decoration;

  /// Text to seed the field with, e.g. a previously saved village when
  /// editing an existing record.
  final TextEditingValue? initialValue;

  /// Called on every text change, including free text that never matches a
  /// suggestion. Use this as a manual fallback when the dataset doesn't
  /// cover the location the user is typing.
  final ValueChanged<String>? onTextChanged;

  /// If set, delays each search by this long after the user stops typing
  /// instead of querying on every keystroke. Defaults to null (no debounce).
  final Duration? debounceDuration;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  UgandaLocations? _ug;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final UgandaLocations ug =
        // ignore: deprecated_member_use_from_same_package
        widget.ug ?? await (widget.locations ?? UgandaLocations.getInstance());
    if (!mounted) return;
    setState(() => _ug = ug);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<Iterable<UgandaLocation>> _search(UgandaLocations ug, String query) {
    final Duration? debounce = widget.debounceDuration;
    if (debounce == null) {
      return ug.search(query, limit: widget.limit);
    }
    _debounceTimer?.cancel();
    final Completer<Iterable<UgandaLocation>> completer = Completer<Iterable<UgandaLocation>>();
    _debounceTimer = Timer(debounce, () {
      completer.complete(ug.search(query, limit: widget.limit));
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<UgandaLocation>(
      initialValue: widget.initialValue,
      displayStringForOption: (UgandaLocation loc) => loc.village,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        final UgandaLocations? ug = _ug;
        if (textEditingValue.text.trim().isEmpty) {
          return const Iterable<UgandaLocation>.empty();
        }
        if (ug == null) {
          return const Iterable<UgandaLocation>.empty();
        }
        return _search(ug, textEditingValue.text);
      },
      onSelected: widget.onSelected,
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration:
                      widget.decoration ?? const InputDecoration(labelText: 'Search location'),
                  onChanged: widget.onTextChanged,
                  onFieldSubmitted: (String value) => onFieldSubmitted(),
                ),
                if (_ug == null) const LinearProgressIndicator(minHeight: 2),
              ],
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
