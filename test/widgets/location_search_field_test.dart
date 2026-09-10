import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ug_locations/ug_locations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // See location_picker_test.dart: the isolate-based databaseFactoryFfi
    // deadlocks the flutter_tester widget-test harness's frame pump.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late UgandaLocations ug;

  setUpAll(() async {
    final dbPath = p.absolute(p.join(Directory.current.path, 'assets', 'ug_locations.db'));
    final db = await UgLocationsDatabase.openFromPath(dbPath);
    ug = UgandaLocations.fromDatabase(db);
  });

  testWidgets('shows suggestions while typing and reports the selected location', (tester) async {
    UgandaLocation? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationSearchField(
            locations: Future.value(ug),
            onSelected: (loc) => selected = loc,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'KASAMBYA I');
    await tester.pumpAndSettle();

    expect(find.text('KASAMBYA I'), findsWidgets);

    // Scope the subtitle check to the tile titled exactly "KASAMBYA I" -
    // "KASAMBYA II" is also in KATEREIGA/BUHANIKA/HOIMA and matches the
    // same query (it's a text-prefix match), so a bare subtitle-text finder
    // would find two identical matches.
    final kasambyaITile = find.byWidgetPredicate(
      (widget) => widget is ListTile && (widget.title as Text).data == 'KASAMBYA I',
    );
    expect(kasambyaITile, findsOneWidget);
    final tile = tester.widget<ListTile>(kasambyaITile);
    expect((tile.subtitle as Text).data, 'KATEREIGA → BUHANIKA → HOIMA');

    // Submitting the field selects the top-ranked (highlighted) suggestion.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.village, 'KASAMBYA I');
    expect(selected!.district, 'HOIMA');
  });
}
