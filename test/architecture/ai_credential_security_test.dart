import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production sources contain no developer-owned OpenAI key', () {
    final credentialPattern = RegExp(r'sk-[A-Za-z0-9_-]{20,}');
    final matches = <String>[];
    for (final root in ['lib', 'android']) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (file) => !file.path.contains(
                  '${Platform.pathSeparator}build${Platform.pathSeparator}',
                ),
              )
              .where(
                (file) => const {
                  '.dart',
                  '.java',
                  '.kt',
                  '.kts',
                  '.xml',
                  '.properties',
                  '.gradle',
                }.any(file.path.endsWith),
              )) {
        final source = file.readAsStringSync();
        if (credentialPattern.hasMatch(source)) matches.add(file.path);
      }
    }

    expect(matches, isEmpty, reason: matches.join('\n'));
  });

  test('normal database schema has no API-key column', () {
    final databaseSource = File(
      'lib/data/services/app_database.dart',
    ).readAsStringSync();

    expect(databaseSource.toLowerCase(), isNot(contains('api_key')));
  });
}
