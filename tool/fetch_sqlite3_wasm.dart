// Downloads the prebuilt sqlite3.wasm binary matching the `sqlite3` package
// version pinned in pubspec.yaml, for the web backend
// (lib/src/web/ug_locations_database_web.dart).
//
// `package:sqlite3/wasm.dart` requires a specially-compiled sqlite3 binary -
// existing wasm builds (e.g. from sql.js) don't work. The matching build is
// published on the sqlite3.dart GitHub releases, tagged `sqlite3-<version>`.
//
// Run with: dart run tool/fetch_sqlite3_wasm.dart
import 'dart:io';

Future<void> main() async {
  final String pubspecText = File('pubspec.yaml').readAsStringSync();
  final RegExpMatch? match = RegExp(
    r'^\s*sqlite3:\s*\^?([\d.]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecText);
  if (match == null) {
    throw StateError('Could not find a sqlite3 dependency version in pubspec.yaml.');
  }
  final String version = match.group(1)!;

  final Uri url = Uri.parse(
    'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$version/sqlite3.wasm',
  );
  stdout.writeln('Downloading $url ...');

  final HttpClient client = HttpClient();
  final HttpClientRequest request = await client.getUrl(url);
  final HttpClientResponse response = await request.close();
  if (response.statusCode != 200) {
    throw StateError(
      'Failed to download sqlite3.wasm for version $version '
      '(HTTP ${response.statusCode}). Check that a sqlite3-$version release '
      'exists at https://github.com/simolus3/sqlite3.dart/releases.',
    );
  }

  final File outFile = File('assets/sqlite3.wasm');
  outFile.parent.createSync(recursive: true);
  await response.pipe(outFile.openWrite());
  client.close();

  stdout.writeln('Wrote ${outFile.path} (${outFile.lengthSync()} bytes).');
}
