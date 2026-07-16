import 'dart:io';

import 'package:flow_reading/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase appDatabase;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-db-');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/flow_reading.db',
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('creates versioned milestone schema without permanent pages', () async {
    final database = await appDatabase.open();
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = rows.map((row) => row['name']).toSet();

    expect(await database.getVersion(), AppDatabase.schemaVersion);
    expect(
      tables,
      containsAll(<String>{
        'books',
        'chapters',
        'chapter_content',
        'reading_states',
        'annotations',
        'bookmarks',
        'notes',
        'ai_artifacts',
        'chat_sessions',
        'chat_messages',
        'glossary_terms',
        'reader_preferences',
        'sync_outbox',
      }),
    );
    expect(tables, isNot(contains('pages')));
    expect(
      (await database.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
      1,
    );
  });

  test('failed transaction preserves previously stored books', () async {
    final database = await appDatabase.open();
    final original = _book('book-1');
    await database.insert('books', original);

    await expectLater(
      database.transaction((transaction) async {
        await transaction.insert('books', _book('book-2'));
        await transaction.insert('books', _book('book-1'));
      }),
      throwsA(anything),
    );

    final rows = await database.query('books', orderBy: 'id');
    expect(rows.map((row) => row['id']), ['book-1']);
  });
}

Map<String, Object?> _book(String id) => {
  'id': id,
  'content_hash': id,
  'title': id,
  'authors_json': '[]',
  'metadata_json': '{}',
  'original_file': '/books/$id/original.epub',
  'toc_json': '[]',
  'assets_json': '[]',
  'imported_at': DateTime.utc(2026).toIso8601String(),
};
