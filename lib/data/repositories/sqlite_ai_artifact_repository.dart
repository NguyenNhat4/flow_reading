import 'dart:convert';

import 'package:flow_reading/data/models/ai_artifact_record_codec.dart';
import 'package:flow_reading/data/models/reader_state_record_codec.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteAiArtifactRepository implements AiArtifactRepository {
  const SqliteAiArtifactRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<AiCacheEntry?> read(String cacheId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'ai_artifacts',
      where: '''
id = ?
AND content_hash IS NOT NULL
AND context_fingerprint IS NOT NULL
AND prompt_id IS NOT NULL
AND prompt_version IS NOT NULL''',
      whereArgs: [cacheId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return _fromRow(rows.single);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  });

  @override
  Future<void> save(AiCacheEntry entry) => _guard(() async {
    final database = await appDatabase.open();
    await database.insert('ai_artifacts', {
      'id': entry.id,
      'book_id': entry.bookId,
      'kind': entry.requestType.name,
      'source_range_json': entry.sourceRange == null
          ? null
          : jsonEncode(ReaderStateRecordCodec.encodeAnchor(entry.sourceRange!)),
      'response_json': jsonEncode(entry.response),
      'provider': entry.provider,
      'model': entry.model,
      'created_at': entry.createdAt.toUtc().toIso8601String(),
      'content_hash': entry.contentHash,
      'context_fingerprint': entry.contextFingerprint,
      'prompt_id': entry.promptId,
      'prompt_version': entry.promptVersion,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  static AiCacheEntry _fromRow(Map<String, Object?> row) =>
      AiArtifactRecordCodec.decode({
        'id': row['id'],
        'bookId': row['book_id'],
        'requestType': row['kind'],
        'sourceRange': switch (row['source_range_json']) {
          final String value =>
            (jsonDecode(value) as Map).cast<String, Object?>(),
          _ => null,
        },
        'contentHash': row['content_hash'],
        'contextFingerprint': row['context_fingerprint'],
        'promptId': row['prompt_id'],
        'promptVersion': row['prompt_version'],
        'response': (jsonDecode(row['response_json'] as String) as Map)
            .cast<String, Object?>(),
        'provider': row['provider'],
        'model': row['model'],
        'createdAt': row['created_at'],
      });

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure();
    }
  }
}
