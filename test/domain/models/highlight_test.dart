import 'dart:convert';

import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes with identity derived from the stable source range', () {
    final highlight = Highlight(
      range: TextAnchor(
        bookId: 'book',
        chapterId: 'chapter',
        blockId: 'block',
        startOffset: 2,
        endOffset: 8,
      ),
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 3),
    );

    final restored = Highlight.fromJson(
      (jsonDecode(jsonEncode(highlight.toJson())) as Map)
          .cast<String, Object?>(),
    );

    expect(restored.id, highlight.range.id);
    expect(restored.bookId, 'book');
    expect(restored.range.startOffset, 2);
    expect(restored.updatedAt, DateTime.utc(2026, 1, 3));
  });

  test('rejects stored identity that does not match the range', () {
    final range = TextAnchor(
      bookId: 'book',
      chapterId: 'chapter',
      blockId: 'block',
      startOffset: 0,
      endOffset: 4,
    );

    expect(
      () => Highlight.fromJson({
        'id': 'wrong',
        'bookId': range.bookId,
        'range': range.toJson(),
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
      }),
      throwsFormatException,
    );
  });
}
