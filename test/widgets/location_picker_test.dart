import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ug_locations/ug_locations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // The isolate-based databaseFactoryFfi deadlocks the flutter_tester
    // widget-test harness's frame pump (its background isolate's messages
    // never get serviced between tester.pump() calls); the synchronous
    // no-isolate factory avoids that entirely and is fine for read-only
    // test queries.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late UgandaLocations ug;

  setUpAll(() async {
    final dbPath = p.absolute(p.join(Directory.current.path, 'assets', 'ug_locations.db'));
    final db = await UgLocationsDatabase.openFromPath(dbPath);
    ug = UgandaLocations.fromDatabase(db);
  });

  // The widget shows an indefinite CircularProgressIndicator while loading,
  // which makes pumpAndSettle time out (it never sees zero pending frames).
  // Pump in fixed steps instead, up to a generous ceiling, until the given
  // finder resolves.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsOneWidget);
  }

  // Drives the cascade by invoking each DropdownButtonFormField's onChanged
  // directly, rather than tapping through the real dropdown overlay (which
  // is flaky/slow to settle in a widget test with 145 districts). This
  // still exercises the widget's own state-management logic end to end.
  Future<void> selectDropdownValue(WidgetTester tester, String label, String value) async {
    final finder = find.widgetWithText(DropdownButtonFormField<String>, label);
    final widget = tester.widget<DropdownButtonFormField<String>>(finder);
    widget.onChanged!(value);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('cascades district -> subcounty -> parish -> village and reports selection', (
    tester,
  ) async {
    UgandaLocation? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPicker(
            locations: Future.value(ug),
            onSelected: (loc) => selected = loc,
          ),
        ),
      ),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.widgetWithText(DropdownButtonFormField<String>, 'District'));

    await selectDropdownValue(tester, 'District', 'HOIMA');
    await selectDropdownValue(tester, 'Subcounty', 'BUHANIKA');
    await selectDropdownValue(tester, 'Parish', 'KATEREIGA');
    await selectDropdownValue(tester, 'Village', 'KASAMBYA I');

    expect(selected, isNotNull);
    expect(selected!.village, 'KASAMBYA I');
    expect(selected!.parish, 'KATEREIGA');
    expect(selected!.subcounty, 'BUHANIKA');
    expect(selected!.district, 'HOIMA');
  });

  testWidgets('default picker has no Region/Sub-region dropdowns', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPicker(locations: Future.value(ug), onSelected: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.widgetWithText(DropdownButtonFormField<String>, 'District'));

    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Region'), findsNothing);
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Sub-region'), findsNothing);
  });

  testWidgets(
    'includeRegionHierarchy cascades region -> sub-region -> district -> ... -> village',
    (tester) async {
      UgandaLocation? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPicker(
              locations: Future.value(ug),
              includeRegionHierarchy: true,
              onSelected: (loc) => selected = loc,
            ),
          ),
        ),
      );
      await tester.pump();
      await pumpUntilFound(tester, find.widgetWithText(DropdownButtonFormField<String>, 'Region'));

      await selectDropdownValue(tester, 'Region', 'WESTERN');
      await selectDropdownValue(tester, 'Sub-region', 'BUNYORO');
      await selectDropdownValue(tester, 'District', 'HOIMA');
      await selectDropdownValue(tester, 'Subcounty', 'BUHANIKA');
      await selectDropdownValue(tester, 'Parish', 'KATEREIGA');
      await selectDropdownValue(tester, 'Village', 'KASAMBYA I');

      expect(selected, isNotNull);
      expect(selected!.village, 'KASAMBYA I');
      expect(selected!.region, 'WESTERN');
      expect(selected!.subRegion, 'BUNYORO');
    },
  );
}
