import 'dart:convert';

import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteNoteRepository implements NoteRepository {
  SqliteNoteRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<List<ReaderNote>> listForBook(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  });

  @override
  Future<void> save(ReaderNote note) => _guard(() async {
    final database = await appDatabase.open();
    await database.insert('notes', {
      'id': note.id,
      'book_id': note.bookId,
      'range_json': jsonEncode(note.range.toJson()),
      'note': note.body,
      'created_at': note.createdAt.toUtc().toIso8601String(),
      'updated_at': note.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  @override
  Future<void> delete(String noteId) => _guard(() async {
    final database = await appDatabase.open();
    await database.delete('notes', where: 'id = ?', whereArgs: [noteId]);
  });

  static ReaderNote _fromRow(Map<String, Object?> row) => ReaderNote(
    range: TextAnchor.fromJson(
      (jsonDecode(row['range_json'] as String) as Map).cast<String, Object?>(),
    ),
    body: row['note'] as String,
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
