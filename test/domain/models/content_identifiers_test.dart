import 'dart:convert';
import 'dart:typed_data';

import 'package:flow_reading/domain/models/content_identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentIdentifiers', () {
    test('same unchanged EPUB bytes generate the same book ID', () {
      final firstImport = Uint8List.fromList(utf8.encode('unchanged epub'));
      final secondImport = Uint8List.fromList(utf8.encode('unchanged epub'));

      expect(
        ContentIdentifiers.book(firstImport),
        ContentIdentifiers.book(secondImport),
      );
      expect(ContentIdentifiers.book(firstImport), startsWith('book_'));
    });

    test('changed EPUB bytes generate a different book ID', () {
      final original = Uint8List.fromList(utf8.encode('original epub'));
      final changed = Uint8List.fromList(utf8.encode('changed epub'));

      expect(
        ContentIdentifiers.book(original),
        isNot(ContentIdentifiers.book(changed)),
      );
    });

    test('canonical hierarchy generates repeatable content IDs', () {
      final chapter = ContentIdentifiers.chapter(
        bookId: 'book_id',
        spineIndex: 2,
        sourceHref: 'text/./chapter.xhtml',
      );
      final equivalentChapter = ContentIdentifiers.chapter(
        bookId: 'book_id',
        spineIndex: 2,
        sourceHref: 'text/chapter.xhtml',
      );
      final block = ContentIdentifiers.block(
        chapterId: chapter,
        order: 3,
        type: 'paragraph',
        sourceLocator: 'body/p[4]',
      );
      final sentence = ContentIdentifiers.sentence(
        blockId: block,
        startOffset: 0,
        endOffset: 12,
        text: 'Hello world.',
      );

      expect(chapter, equivalentChapter);
      expect(
        sentence,
        ContentIdentifiers.sentence(
          blockId: block,
          startOffset: 0,
          endOffset: 12,
          text: 'Hello world.',
        ),
      );
    });

    test('text selection uses stable IDs and character offsets', () {
      final range = StableTextRange(
        bookId: 'book_id',
        chapterId: 'chapter_id',
        blockId: 'block_id',
        startOffset: 6,
        endOffset: 11,
      );
      final restored = StableTextRange.fromJson(range.toJson());

      expect(restored.id, range.id);
      expect(restored.blockId, 'block_id');
      expect(restored.startOffset, 6);
      expect(restored.endOffset, 11);
      expect(range.toJson().keys, isNot(contains('page')));
    });

    test('layout details cannot affect IDs because they are not inputs', () {
      final rangeAtAnyLayout = ContentIdentifiers.textRange(
        bookId: 'book_id',
        chapterId: 'chapter_id',
        blockId: 'block_id',
        startOffset: 10,
        endOffset: 20,
      );

      expect(
        rangeAtAnyLayout,
        ContentIdentifiers.textRange(
          bookId: 'book_id',
          chapterId: 'chapter_id',
          blockId: 'block_id',
          startOffset: 10,
          endOffset: 20,
        ),
      );
    });

    test('invalid offsets are rejected', () {
      expect(
        () => StableTextRange(
          bookId: 'book_id',
          chapterId: 'chapter_id',
          blockId: 'block_id',
          startOffset: 4,
          endOffset: 3,
        ),
        throwsArgumentError,
      );
    });
  });
}
