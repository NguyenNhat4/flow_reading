import 'dart:io';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/platform/sqlite_book_repository.dart';
import 'package:flow_reading/platform/sqlite_table_of_contents_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-toc-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/books.db',
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('loads every nested canonical TOC reference from SQLite', () async {
    const entries = [
      TableOfContentsEntry(
        title: 'Part one',
        reference: ChapterReference(chapterId: 'chapter-1'),
        children: [
          TableOfContentsEntry(
            title: 'A stable section',
            reference: ChapterReference(
              chapterId: 'chapter-1',
              blockId: 'block-2',
              fragment: 'section',
            ),
          ),
        ],
      ),
    ];
    await SqliteBookRepository(database).save(
      Book(
        id: 'book-id',
        metadata: const BookMetadata(title: 'Book'),
        originalFile: '/books/book-id/original.epub',
        chapters: const [
          Chapter(
            id: 'chapter-1',
            bookId: 'book-id',
            title: 'Chapter',
            order: 0,
            blocks: [],
          ),
        ],
        tableOfContents: entries,
        assets: const [],
        importedAt: DateTime.utc(2026),
      ),
    );

    final restored = await SqliteTableOfContentsRepository(
      database,
    ).load('book-id');

    expect(restored.map((entry) => entry.toJson()), [entries.single.toJson()]);
  });
}
