import 'dart:io';

import 'package:flow_reading/data/repositories/sqlite_bookmark_repository.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteBookmarkRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-bookmark-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/flow_reading.db',
    );
    repository = SqliteBookmarkRepository(database);
    final sqlite = await database.open();
    await sqlite.insert('books', _bookRow);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('saves, lists, replaces, and removes logical bookmarks', () async {
    final bookmark = _bookmark(DateTime.utc(2026, 1, 1));
    await repository.save(bookmark);
    expect(
      (await repository.listForBook('book')).single.locator.anchor.startOffset,
      4,
    );

    await repository.save(_bookmark(DateTime.utc(2026, 1, 2)));
    expect(await repository.listForBook('book'), hasLength(1));

    await repository.delete(bookmark.id);
    expect(await repository.listForBook('book'), isEmpty);
  });
}

Bookmark _bookmark(DateTime createdAt) => Bookmark(
  locator: ReadingLocator(
    anchor: TextAnchor(
      bookId: 'book',
      chapterId: 'chapter',
      blockId: 'block',
      startOffset: 4,
      endOffset: 4,
    ),
  ),
  createdAt: createdAt,
);

final _bookRow = <String, Object?>{
  'id': 'book',
  'content_hash': 'book',
  'title': 'Book',
  'authors_json': '[]',
  'metadata_json': '{}',
  'original_file': '/books/book/original.epub',
  'toc_json': '[]',
  'assets_json': '[]',
  'imported_at': DateTime.utc(2026).toIso8601String(),
};
