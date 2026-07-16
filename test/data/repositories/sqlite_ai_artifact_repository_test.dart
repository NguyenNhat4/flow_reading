import 'dart:io';

import 'package:flow_reading/data/repositories/sqlite_ai_artifact_repository.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteAiArtifactRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-ai-cache-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/cache.db',
    );
    repository = SqliteAiArtifactRepository(database);
    final sqlite = await database.open();
    await sqlite.insert('books', _bookRow);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('saves and reads a successful artifact offline', () async {
    final entry = _entry();

    await repository.save(entry);
    await database.close();
    final restored = await repository.read(entry.id);

    expect(restored?.id, entry.id);
    expect(restored?.response, {'meaning': 'contextual'});
    expect(restored?.promptVersion, 1);
  });

  test('prompt-version changes do not reuse an older artifact', () async {
    final first = _entry();
    final updated = _entry(promptVersion: 2);

    await repository.save(first);

    expect(await repository.read(updated.id), isNull);
    expect(await repository.read(first.id), isNotNull);
  });

  test('ignores legacy and malformed incompatible rows', () async {
    final sqlite = await database.open();
    await sqlite.insert('ai_artifacts', {
      'id': 'legacy',
      'book_id': 'book',
      'kind': 'wordExplanation',
      'response_json': '{}',
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    final entry = _entry();
    await repository.save(entry);
    await sqlite.update(
      'ai_artifacts',
      {'response_json': '[]'},
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    expect(await repository.read('legacy'), isNull);
    expect(await repository.read(entry.id), isNull);
  });

  test('book deletion cascades cached artifacts', () async {
    final entry = _entry();
    await repository.save(entry);
    final sqlite = await database.open();

    await sqlite.delete('books', where: 'id = ?', whereArgs: ['book']);

    expect(await repository.read(entry.id), isNull);
  });
}

AiCacheEntry _entry({int promptVersion = 1}) => AiCacheEntry.create(
  bookId: 'book',
  requestType: AiRequestType.wordExplanation,
  sourceRange: TextAnchor(
    bookId: 'book',
    chapterId: 'chapter',
    blockId: 'block',
    startOffset: 0,
    endOffset: 4,
  ),
  contentHash: 'content-hash',
  contextFingerprint: 'context-fingerprint',
  promptId: 'word_explanation',
  promptVersion: promptVersion,
  response: const {'meaning': 'contextual'},
  provider: 'openai',
  model: 'gpt-5.6-luna',
  createdAt: DateTime.utc(2026),
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
