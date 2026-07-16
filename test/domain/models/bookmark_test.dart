import 'dart:convert';

import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes a collapsed logical locator with derived identity', () {
    final bookmark = Bookmark(
      locator: ReadingLocator(anchor: _anchor(3, 3)),
      createdAt: DateTime.utc(2026, 3, 1),
    );

    final restored = Bookmark.fromJson(
      (jsonDecode(jsonEncode(bookmark.toJson())) as Map)
          .cast<String, Object?>(),
    );

    expect(restored.id, bookmark.locator.anchor.id);
    expect(restored.locator.anchor.startOffset, 3);
    expect(restored.createdAt, DateTime.utc(2026, 3, 1));
  });

  test('rejects a non-collapsed range', () {
    expect(
      () => Bookmark(
        locator: ReadingLocator(anchor: _anchor(1, 4)),
        createdAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });
}

TextAnchor _anchor(int start, int end) => TextAnchor(
  bookId: 'book',
  chapterId: 'chapter',
  blockId: 'block',
  startOffset: start,
  endOffset: end,
);
