import 'dart:io';

import 'package:flow_reading/data/repositories/sqlite_highlight_repository.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteHighlightRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-highlight-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/flow_reading.db',
    );
    repository = SqliteHighlightRepository(database);
    final sqlite = await database.open();
    await sqlite.insert('books', _bookRow);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('saves, lists, replaces, and deletes highlights', () async {
    final original = _highlight(DateTime.utc(2026, 1, 1));
    await repository.save(original);

    final saved = await repository.listForBook('book');
    expect(saved.single.id, original.id);
    expect(saved.single.range.endOffset, 6);

    final updated = Highlight(
      range: original.range,
      createdAt: original.createdAt,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await repository.save(updated);
    expect(
      (await repository.listForBook('book')).single.updatedAt,
      DateTime.utc(2026, 1, 2),
    );

    await repository.delete(original.id);
    expect(await repository.listForBook('book'), isEmpty);
  });

  test(
    'only returns highlight annotation rows for the requested book',
    () async {
      final sqlite = await database.open();
      await repository.save(_highlight(DateTime.utc(2026)));
      await sqlite.insert('annotations', {
        'id': 'note-row',
        'book_id': 'book',
        'type': 'note',
        'range_json': '{}',
        'created_at': DateTime.utc(2026).toIso8601String(),
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });

      expect(await repository.listForBook('book'), hasLength(1));
      expect(await repository.listForBook('missing'), isEmpty);
    },
  );
}

Highlight _highlight(DateTime updatedAt) => Highlight(
  range: TextAnchor(
    bookId: 'book',
    chapterId: 'chapter',
    blockId: 'block',
    startOffset: 1,
    endOffset: 6,
  ),
  createdAt: DateTime.utc(2026),
  updatedAt: updatedAt,
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
