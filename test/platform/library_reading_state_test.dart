import 'dart:io';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/platform/sqlite_book_repository.dart';
import 'package:flow_reading/platform/sqlite_reading_position_repository.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteBookRepository books;
  late SqliteReadingPositionRepository positions;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-library-state-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/library.db',
    );
    books = SqliteBookRepository(database);
    positions = SqliteReadingPositionRepository(database);
    await books.save(_book());
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('unopened books have empty reading activity', () async {
    final summary = (await books.listBooks()).single;

    expect(summary.readingProgress, 0);
    expect(summary.lastOpenedAt, isNull);
  });

  test('position round-trips and contributes canonical progress', () async {
    final updatedAt = DateTime.utc(2026, 7, 15, 8, 30);
    final position = ReadingPosition(
      bookId: 'book-id',
      locator: ReadingLocator(
        anchor: TextAnchor(
          bookId: 'book-id',
          chapterId: 'chapter-2',
          blockId: 'block-2',
          startOffset: 0,
          endOffset: 0,
        ),
      ),
      updatedAt: updatedAt,
    );

    await positions.save(position);

    final restored = await positions.load('book-id');
    final summary = (await books.listBooks()).single;
    expect(restored?.bookId, 'book-id');
    expect(restored?.locator.anchor.bookId, 'book-id');
    expect(restored?.locator.anchor.chapterId, 'chapter-2');
    expect(restored?.locator.anchor.blockId, 'block-2');
    expect(restored?.locator.anchor.startOffset, 0);
    expect(restored?.locator.anchor.endOffset, 0);
    expect(restored?.locator.anchor.id, position.locator.anchor.id);
    expect(restored?.updatedAt, updatedAt);
    expect(restored?.updatedAt.isUtc, isTrue);
    expect(summary.readingProgress, 0.5);
    expect(summary.lastOpenedAt?.toUtc(), updatedAt);
  });

  test('summary clamps offsets and ignores malformed anchors', () async {
    await positions.save(
      ReadingPosition(
        bookId: 'book-id',
        locator: ReadingLocator(
          anchor: TextAnchor(
            bookId: 'book-id',
            chapterId: 'chapter-2',
            blockId: 'block-2',
            startOffset: 999,
            endOffset: 999,
          ),
        ),
        updatedAt: DateTime.utc(2026, 7, 15),
      ),
    );

    expect((await books.listBooks()).single.readingProgress, 1);

    final sqlite = await database.open();
    await sqlite.update(
      'reading_states',
      {'anchor_json': '{invalid'},
      where: 'book_id = ?',
      whereArgs: ['book-id'],
    );
    expect((await books.listBooks()).single.readingProgress, 0);
  });
}

Book _book() => Book(
  id: 'book-id',
  metadata: const BookMetadata(title: 'Local Book', authors: ['Writer']),
  originalFile: '/books/book-id/original.epub',
  chapters: const [
    Chapter(
      id: 'chapter-1',
      bookId: 'book-id',
      title: 'First',
      order: 0,
      blocks: [
        ParagraphBlock(
          id: 'block-1',
          chapterId: 'chapter-1',
          order: 0,
          spans: [InlineTextSpan(text: '0123456789')],
        ),
      ],
    ),
    Chapter(
      id: 'chapter-2',
      bookId: 'book-id',
      title: 'Second',
      order: 1,
      blocks: [
        ParagraphBlock(
          id: 'block-2',
          chapterId: 'chapter-2',
          order: 0,
          spans: [InlineTextSpan(text: 'abcdefghij')],
        ),
      ],
    ),
  ],
  tableOfContents: const [],
  assets: const [],
  importedAt: DateTime.utc(2026),
);
