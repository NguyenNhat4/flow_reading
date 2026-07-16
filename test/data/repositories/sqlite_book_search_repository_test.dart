import 'dart:io';

import 'package:flow_reading/data/repositories/sqlite_book_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_book_search_repository.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteBookRepository books;
  late SqliteBookSearchRepository search;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-search-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/flow_reading.db',
    );
    books = SqliteBookRepository(database);
    search = SqliteBookSearchRepository(database);
    await books.save(_book('book', 'Intro 😀 quick brown fox by the brook.'));
    await books.save(_book('other', 'Another quick brown fox.'));
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('searches one book offline with all terms and final prefix', () async {
    final results = await search.search(bookId: 'book', query: 'quick bro');

    expect(results, hasLength(1));
    final result = results.single;
    expect(result.segment.segmentId, 'book-block');
    expect(result.segment.bookId, 'book');
    expect(result.segment.chapterId, 'book-chapter');
    expect(result.segment.blockId, 'book-block');
    expect(result.segment.plainText, contains('quick brown'));
    expect(result.excerpt, contains('quick brown fox'));
    expect(
      result.locator.anchor.startOffset,
      'Intro 😀 '.length,
      reason: 'indexed match offsets must use Dart UTF-16 positions',
    );
  });

  test('returns no cross-book, empty-query, or deleted-book results', () async {
    expect(await search.search(bookId: 'book', query: 'Another'), isEmpty);
    expect(await search.search(bookId: 'book', query: '   '), isEmpty);

    await books.delete('book');

    expect(await search.search(bookId: 'book', query: 'quick'), isEmpty);
    expect(await search.search(bookId: 'other', query: 'quick'), hasLength(1));
  });
}

Book _book(String id, String text) => Book(
  id: id,
  metadata: BookMetadata(title: id),
  originalFile: '/books/$id/original.epub',
  chapters: [
    Chapter(
      id: '$id-chapter',
      bookId: id,
      title: 'Chapter',
      order: 0,
      blocks: [
        ParagraphBlock(
          id: '$id-block',
          chapterId: '$id-chapter',
          order: 0,
          spans: [InlineTextSpan(text: text)],
        ),
      ],
    ),
  ],
  tableOfContents: const [],
  assets: const [],
  importedAt: DateTime.utc(2026),
);
