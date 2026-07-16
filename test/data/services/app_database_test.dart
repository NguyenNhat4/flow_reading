import 'dart:convert';
import 'dart:io';

import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/book_models.dart';
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
        'search_segments',
        'search_terms',
      }),
    );
    expect(tables, isNot(contains('pages')));
    expect(
      (await database.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
      1,
    );
  });

  test('legacy migration backfills the local search index', () async {
    final path = '${root.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
CREATE TABLE books (
  id TEXT PRIMARY KEY,
  content_hash TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  authors_json TEXT NOT NULL,
  metadata_json TEXT NOT NULL,
  original_file TEXT NOT NULL,
  toc_json TEXT NOT NULL,
  assets_json TEXT NOT NULL,
  detected_language TEXT,
  imported_at TEXT NOT NULL
)''');
          await database.execute('''
CREATE TABLE chapters (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  title TEXT NOT NULL,
  spine_order INTEGER NOT NULL,
  source_href TEXT
)''');
          await database.execute('''
CREATE TABLE chapter_content (
  chapter_id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  content_json TEXT NOT NULL
)''');
          await database.execute('''
CREATE TABLE ai_artifacts (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  source_range_json TEXT,
  response_json TEXT NOT NULL,
  provider TEXT,
  model TEXT,
  created_at TEXT NOT NULL
)''');
        },
      ),
    );
    await legacy.insert('books', _book('legacy'));
    await legacy.insert('chapters', {
      'id': 'chapter',
      'book_id': 'legacy',
      'title': 'Chapter',
      'spine_order': 0,
    });
    await legacy.insert('chapter_content', {
      'chapter_id': 'chapter',
      'schema_version': 1,
      'content_json': jsonEncode(_legacyChapter.toJson()),
    });
    await legacy.close();

    final upgraded = AppDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(upgraded.close);
    final database = await upgraded.open();
    final rows = await database.rawQuery(
      '''SELECT segment_id FROM search_terms WHERE term = ?''',
      ['backfilled'],
    );

    expect(await database.getVersion(), AppDatabase.schemaVersion);
    expect(rows.single['segment_id'], 'block');
  });

  test('version 3 migration adds AI cache compatibility columns', () async {
    final path = '${root.path}/version-2.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await database.execute('''
CREATE TABLE ai_artifacts (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  source_range_json TEXT,
  response_json TEXT NOT NULL,
  provider TEXT,
  model TEXT,
  created_at TEXT NOT NULL
)''');
        },
      ),
    );
    await legacy.insert('ai_artifacts', {
      'id': 'legacy',
      'book_id': 'book',
      'kind': 'summary',
      'response_json': '{}',
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    await legacy.close();

    final upgraded = AppDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(upgraded.close);
    final database = await upgraded.open();
    final columns = await database.rawQuery('PRAGMA table_info(ai_artifacts)');
    final names = columns.map((column) => column['name']).toSet();
    final row = (await database.query('ai_artifacts')).single;

    expect(
      names,
      containsAll([
        'content_hash',
        'context_fingerprint',
        'prompt_id',
        'prompt_version',
      ]),
    );
    expect(row['content_hash'], isNull);
    expect(await database.getVersion(), AppDatabase.schemaVersion);
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

const _legacyChapter = Chapter(
  id: 'chapter',
  bookId: 'legacy',
  title: 'Chapter',
  order: 0,
  blocks: [
    ParagraphBlock(
      id: 'block',
      chapterId: 'chapter',
      order: 0,
      spans: [InlineTextSpan(text: 'Backfilled canonical text.')],
    ),
  ],
);

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
