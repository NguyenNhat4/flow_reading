import 'dart:convert';

import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteBookmarkRepository implements BookmarkRepository {
  SqliteBookmarkRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<List<Bookmark>> listForBook(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  });

  @override
  Future<void> save(Bookmark bookmark) => _guard(() async {
    final database = await appDatabase.open();
    await database.insert('bookmarks', {
      'id': bookmark.id,
      'book_id': bookmark.bookId,
      'anchor_json': jsonEncode(bookmark.locator.toJson()),
      'created_at': bookmark.createdAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  @override
  Future<void> delete(String bookmarkId) => _guard(() async {
    final database = await appDatabase.open();
    await database.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [bookmarkId],
    );
  });

  static Bookmark _fromRow(Map<String, Object?> row) => Bookmark(
    locator: ReadingLocator.fromJson(
      (jsonDecode(row['anchor_json'] as String) as Map).cast<String, Object?>(),
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
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
