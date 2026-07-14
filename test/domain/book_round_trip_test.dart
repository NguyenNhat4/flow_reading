import 'dart:convert';

import 'package:flow_reading/shared/domain/book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/sample_book.dart';

void main() {
  test('canonical book JSON round-trips without data loss', () {
    final original = sampleBook();
    final decoded = Book.fromJson(
      (jsonDecode(jsonEncode(original.toJson())) as Map)
          .cast<String, Object?>(),
    );
    expect(jsonEncode(decoded.toJson()), jsonEncode(original.toJson()));
    expect(decoded.readingState!.locator.formatVersion, 1);
    expect(decoded.modelVersion, 1);
  });
}
