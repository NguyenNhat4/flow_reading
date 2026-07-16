import 'dart:io';

import 'package:flow_reading/data/repositories/sqlite_note_repository.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteNoteRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-note-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/flow_reading.db',
    );
    repository = SqliteNoteRepository(database);
    final sqlite = await database.open();
    await sqlite.insert('books', _bookRow);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('creates, edits, lists, and deletes a note', () async {
    final original = _note('First', DateTime.utc(2026, 1, 1));
    await repository.save(original);
    expect((await repository.listForBook('book')).single.body, 'First');

    await repository.save(
      ReaderNote(
        range: original.range,
        body: 'Edited',
        createdAt: original.createdAt,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    final edited = (await repository.listForBook('book')).single;
    expect(edited.body, 'Edited');
    expect(edited.createdAt, original.createdAt);

    await repository.delete(original.id);
    expect(await repository.listForBook('book'), isEmpty);
  });
}

ReaderNote _note(String body, DateTime updatedAt) => ReaderNote(
  range: TextAnchor(
    bookId: 'book',
    chapterId: 'chapter',
    blockId: 'block',
    startOffset: 0,
    endOffset: 4,
  ),
  body: body,
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
