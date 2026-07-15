import 'dart:convert';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/shared/app_failure.dart';

final class SqliteBookRepository implements BookRepository {
  SqliteBookRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<void> save(Book book) => _guard(() async {
    final database = await appDatabase.open();
    await database.transaction((transaction) async {
      await transaction.insert('books', {
        'id': book.id,
        'content_hash': book.id,
        'title': book.metadata.title,
        'authors_json': jsonEncode(book.metadata.authors),
        'metadata_json': jsonEncode(book.metadata.toJson()),
        'original_file': book.originalFile,
        'toc_json': jsonEncode(
          book.tableOfContents.map((entry) => entry.toJson()).toList(),
        ),
        'assets_json': jsonEncode(
          book.assets.map((asset) => asset.toJson()).toList(),
        ),
        'detected_language': book.detectedLanguage,
        'imported_at': book.importedAt.toIso8601String(),
      });
      for (final chapter in book.chapters) {
        await transaction.insert('chapters', {
          'id': chapter.id,
          'book_id': book.id,
          'title': chapter.title,
          'spine_order': chapter.order,
          'source_href': chapter.sourceHref,
        });
        await transaction.insert('chapter_content', {
          'chapter_id': chapter.id,
          'schema_version': 1,
          'content_json': jsonEncode(chapter.toJson()),
        });
      }
    });
  });

  @override
  Future<List<BookSummary>> listBooks() => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query('books', orderBy: 'imported_at DESC');
    return rows.map((row) {
      final authors = (jsonDecode(row['authors_json'] as String) as List)
          .cast<String>();
      final assets = (jsonDecode(row['assets_json'] as String) as List)
          .map(
            (value) =>
                BookAsset.fromJson((value as Map).cast<String, Object?>()),
          )
          .toList();
      final metadata = BookMetadata.fromJson(
        (jsonDecode(row['metadata_json'] as String) as Map)
            .cast<String, Object?>(),
      );
      final coverId = metadata.coverAssetId;
      final cover = coverId == null
          ? null
          : assets.where((asset) => asset.id == coverId).firstOrNull;
      return BookSummary(
        id: row['id'] as String,
        title: row['title'] as String,
        authors: List.unmodifiable(authors),
        importedAt: DateTime.parse(row['imported_at'] as String),
        coverPath: cover?.localPath,
        detectedLanguage: row['detected_language'] as String?,
      );
    }).toList();
  });

  @override
  Future<BookMetadata?> readMetadata(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'books',
      columns: ['metadata_json'],
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BookMetadata.fromJson(
      (jsonDecode(rows.single['metadata_json'] as String) as Map)
          .cast<String, Object?>(),
    );
  });

  @override
  Future<List<Chapter>> loadChapters(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.rawQuery(
      '''SELECT chapter_content.content_json
FROM chapters
JOIN chapter_content ON chapter_content.chapter_id = chapters.id
WHERE chapters.book_id = ?
ORDER BY chapters.spine_order''',
      [bookId],
    );
    return rows
        .map(
          (row) => Chapter.fromJson(
            (jsonDecode(row['content_json'] as String) as Map)
                .cast<String, Object?>(),
          ),
        )
        .toList();
  });

  @override
  Future<bool> containsContentHash(String contentHash) => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'books',
      columns: ['id'],
      where: 'content_hash = ?',
      whereArgs: [contentHash],
      limit: 1,
    );
    return rows.isNotEmpty;
  });

  @override
  Future<void> updateDetectedLanguage(String bookId, String? language) =>
      _guard(() async {
        final database = await appDatabase.open();
        await database.update(
          'books',
          {'detected_language': language},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      });

  @override
  Future<void> delete(String bookId) => _guard(() async {
    final database = await appDatabase.open();
    await database.transaction((transaction) async {
      await transaction.delete('books', where: 'id = ?', whereArgs: [bookId]);
    });
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
