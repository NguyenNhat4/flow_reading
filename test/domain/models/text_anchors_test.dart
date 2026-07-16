import 'dart:convert';

import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextAnchor', () {
    test('serializes and restores stable content IDs and offsets', () {
      final anchor = TextAnchor(
        bookId: 'book_id',
        chapterId: 'chapter_id',
        blockId: 'block_id',
        startOffset: 7,
        endOffset: 19,
      );

      final encoded = jsonEncode(anchor.toJson());
      final restored = TextAnchor.fromJson(
        (jsonDecode(encoded) as Map).cast<String, Object?>(),
      );

      expect(restored.id, anchor.id);
      expect(restored.bookId, 'book_id');
      expect(restored.chapterId, 'chapter_id');
      expect(restored.blockId, 'block_id');
      expect(restored.startOffset, 7);
      expect(restored.endOffset, 19);
      expect(encoded.toLowerCase(), isNot(contains('page')));
    });

    test('rejects negative and reversed offset ranges', () {
      expect(
        () => TextAnchor(
          bookId: 'book_id',
          chapterId: 'chapter_id',
          blockId: 'block_id',
          startOffset: -1,
          endOffset: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => TextAnchor(
          bookId: 'book_id',
          chapterId: 'chapter_id',
          blockId: 'block_id',
          startOffset: 4,
          endOffset: 3,
        ),
        throwsArgumentError,
      );
    });

    test('allows a collapsed range for a reading position', () {
      final anchor = TextAnchor(
        bookId: 'book_id',
        chapterId: 'chapter_id',
        blockId: 'block_id',
        startOffset: 8,
        endOffset: 8,
      );

      expect(anchor.startOffset, anchor.endOffset);
    });
  });

  test('ReadingLocator survives serialization and repagination', () {
    final locator = ReadingLocator(
      anchor: TextAnchor(
        bookId: 'book_id',
        chapterId: 'chapter_id',
        blockId: 'block_id',
        startOffset: 12,
        endOffset: 12,
      ),
    );

    final restored = ReadingLocator.fromJson(
      (jsonDecode(jsonEncode(locator.toJson())) as Map).cast<String, Object?>(),
    );

    expect(restored.anchor.id, locator.anchor.id);
    expect(restored.toJson().toString().toLowerCase(), isNot(contains('page')));
  });

  test('word and passage selections preserve source snapshots', () {
    final wordAnchor = TextAnchor(
      bookId: 'book_id',
      chapterId: 'chapter_id',
      blockId: 'block_id',
      startOffset: 0,
      endOffset: 4,
    );
    final passageAnchor = TextAnchor(
      bookId: 'book_id',
      chapterId: 'chapter_id',
      blockId: 'block_id',
      startOffset: 0,
      endOffset: 15,
    );
    final word = WordSelection(anchor: wordAnchor, textSnapshot: 'Read');
    final passage = PassageSelection(
      anchor: passageAnchor,
      textSnapshot: 'Read carefully.',
    );

    final restoredWord = WordSelection.fromJson(word.toJson());
    final restoredPassage = PassageSelection.fromJson(passage.toJson());

    expect(restoredWord.anchor.id, word.anchor.id);
    expect(restoredWord.textSnapshot, 'Read');
    expect(restoredPassage.anchor.id, passage.anchor.id);
    expect(restoredPassage.textSnapshot, 'Read carefully.');
  });
}
