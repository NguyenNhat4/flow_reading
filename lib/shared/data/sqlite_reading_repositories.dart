import 'dart:async';
import 'dart:convert';

import 'package:flow_reading/shared/data/local_database.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:sqflite/sqflite.dart';

class SqliteReadingStateRepository implements ReadingStateRepository {
  SqliteReadingStateRepository(this._localDatabase);
  final LocalDatabase _localDatabase;

  @override
  Future<ReadingState?> get(String bookId) async {
    final db = await _localDatabase.database;
    final rows = await db.query(
      'reading_states',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ReadingState(
      bookId: bookId,
      locator: ReadingLocator.fromJson(
        (jsonDecode(row['locator_json']! as String) as Map)
            .cast<String, Object?>(),
      ),
      progress: (row['progress']! as num).toDouble(),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      lastOpenedAt: row['last_opened_at'] == null
          ? null
          : DateTime.parse(row['last_opened_at']! as String),
    );
  }

  @override
  Future<void> save(ReadingState state) async {
    final db = await _localDatabase.database;
    await db.insert('reading_states', {
      'book_id': state.bookId,
      'content_id': state.locator.contentId,
      'character_offset': state.locator.characterOffset,
      'word_offset': state.locator.wordOffset,
      'locator_json': jsonEncode(state.locator.toJson()),
      'progress': state.progress,
      'last_opened_at': state.lastOpenedAt?.toUtc().toIso8601String(),
      'updated_at': state.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class SqliteAnnotationRepository implements AnnotationRepository {
  SqliteAnnotationRepository(this._localDatabase);
  final LocalDatabase _localDatabase;
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<List<Annotation>> watchForBook(String bookId) async* {
    yield await _list(bookId);
    await for (final changedBookId in _changes.stream) {
      if (changedBookId == bookId) yield await _list(bookId);
    }
  }

  Future<List<Annotation>> _list(String bookId) async {
    final db = await _localDatabase.database;
    final rows = await db.query(
      'annotations',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at',
    );
    return rows
        .map(
          (row) => Annotation.fromJson(
            (jsonDecode(row['annotation_json']! as String) as Map)
                .cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(Annotation annotation) async {
    final db = await _localDatabase.database;
    await db.insert('annotations', {
      'id': annotation.id,
      'book_id': annotation.bookId,
      'kind': annotation.kind.name,
      'start_content_id': annotation.start.contentId,
      'end_content_id': annotation.end.contentId,
      'annotation_json': jsonEncode(annotation.toJson()),
      'created_at': annotation.createdAt.toUtc().toIso8601String(),
      'updated_at': annotation.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changes.add(annotation.bookId);
  }

  @override
  Future<void> delete(String annotationId) async {
    final db = await _localDatabase.database;
    final rows = await db.query(
      'annotations',
      columns: ['book_id'],
      where: 'id = ?',
      whereArgs: [annotationId],
      limit: 1,
    );
    await db.delete('annotations', where: 'id = ?', whereArgs: [annotationId]);
    if (rows.isNotEmpty) _changes.add(rows.single['book_id']! as String);
  }
}
