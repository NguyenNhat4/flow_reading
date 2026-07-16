import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production imports follow the layered dependency direction', () {
    final violations = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final path = file.path.replaceAll(r'\', '/');
      final source = file.readAsStringSync();
      final imports = RegExp(
        r"^import\s+'package:flow_reading/([^']+)'",
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)!);

      for (final import in imports) {
        if (path.startsWith('lib/domain/') &&
            (import.startsWith('data/') || import.startsWith('ui/'))) {
          violations.add('$path imports $import');
        }
        if (path.startsWith('lib/data/') && import.startsWith('ui/')) {
          violations.add('$path imports $import');
        }
        if (path.startsWith('lib/ui/features/') && import.startsWith('data/')) {
          violations.add('$path imports $import');
        }
      }
      if (path.startsWith('lib/domain/') &&
          RegExp(
            r"^import\s+'package:flutter/",
            multiLine: true,
          ).hasMatch(source)) {
        violations.add('$path imports Flutter');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
