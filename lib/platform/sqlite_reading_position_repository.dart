import 'dart:convert';

import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flow_reading/shared/app_failure.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteReadingPositionRepository
    implements ReadingPositionRepository {
  SqliteReadingPositionRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<ReadingPosition?> load(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'reading_states',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ReadingPosition(
      bookId: bookId,
      locator: ReadingLocator.fromJson(
        (jsonDecode(row['anchor_json'] as String) as Map)
            .cast<String, Object?>(),
      ),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  });

  @override
  Future<void> save(ReadingPosition position) => _guard(() async {
    final database = await appDatabase.open();
    await database.insert('reading_states', {
      'book_id': position.bookId,
      'anchor_json': jsonEncode(position.locator.toJson()),
      'updated_at': position.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
