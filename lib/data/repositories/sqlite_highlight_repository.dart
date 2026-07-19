import 'dart:convert';

import 'package:flow_reading/data/models/reader_state_record_codec.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteHighlightRepository implements HighlightRepository {
  SqliteHighlightRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<List<Highlight>> listForBook(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'annotations',
      where: 'book_id = ? AND type = ?',
      whereArgs: [bookId, 'highlight'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  });

  @override
  Future<void> save(Highlight highlight) => _guard(() async {
    final database = await appDatabase.open();
    await database.insert('annotations', {
      'id': highlight.id,
      'book_id': highlight.bookId,
      'type': 'highlight',
      'range_json': jsonEncode(
        ReaderStateRecordCodec.encodeAnchor(highlight.range),
      ),
      'note': null,
      'created_at': highlight.createdAt.toUtc().toIso8601String(),
      'updated_at': highlight.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  @override
  Future<void> delete(String highlightId) => _guard(() async {
    final database = await appDatabase.open();
    await database.delete(
      'annotations',
      where: 'id = ? AND type = ?',
      whereArgs: [highlightId, 'highlight'],
    );
  });

  static Highlight _fromRow(Map<String, Object?> row) => Highlight(
    range: ReaderStateRecordCodec.decodeAnchor(
      (jsonDecode(row['range_json'] as String) as Map).cast<String, Object?>(),
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

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
