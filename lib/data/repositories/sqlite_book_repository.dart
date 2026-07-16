import 'dart:convert';

import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';

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
    final stateRows = await database.query('reading_states');
    final statesByBook = {
      for (final row in stateRows) row['book_id'] as String: row,
    };
    final contentRows = await database.rawQuery('''
SELECT chapters.book_id, chapters.spine_order, chapter_content.content_json
FROM chapters
JOIN chapter_content ON chapter_content.chapter_id = chapters.id
ORDER BY chapters.book_id, chapters.spine_order''');
    final chaptersByBook = <String, List<Chapter>>{};
    for (final row in contentRows) {
      final bookId = row['book_id'] as String;
      chaptersByBook
          .putIfAbsent(bookId, () => [])
          .add(
            Chapter.fromJson(
              (jsonDecode(row['content_json'] as String) as Map)
                  .cast<String, Object?>(),
            ),
          );
    }
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
      final state = statesByBook[row['id'] as String];
      return BookSummary(
        id: row['id'] as String,
        title: row['title'] as String,
        authors: List.unmodifiable(authors),
        importedAt: DateTime.parse(row['imported_at'] as String),
        coverPath: cover?.localPath,
        detectedLanguage: row['detected_language'] as String?,
        readingProgress: _readingProgress(
          chaptersByBook[row['id'] as String] ?? const [],
          state?['anchor_json'] as String?,
        ),
        lastOpenedAt: _parseDateTime(state?['updated_at'] as String?),
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

double _readingProgress(List<Chapter> chapters, String? locatorJson) {
  if (chapters.isEmpty || locatorJson == null) return 0;
  ReadingLocator locator;
  try {
    locator = ReadingLocator.fromJson(
      (jsonDecode(locatorJson) as Map).cast<String, Object?>(),
    );
  } catch (_) {
    return 0;
  }

  final blocks = chapters.expand((chapter) => chapter.blocks).toList();
  if (blocks.isEmpty) return 0;
  final total = blocks.fold<int>(0, (sum, block) => sum + _blockExtent(block));
  var before = 0;
  for (final block in blocks) {
    if (block.chapterId == locator.anchor.chapterId &&
        block.id == locator.anchor.blockId) {
      final extent = _blockExtent(block);
      final offset = locator.anchor.startOffset.clamp(0, extent);
      return ((before + offset) / total).clamp(0.0, 1.0);
    }
    before += _blockExtent(block);
  }
  return 0;
}

int _blockExtent(ContentBlock block) {
  final length = switch (block) {
    ParagraphBlock() => block.text.length,
    HeadingBlock() => block.text.length,
    QuoteBlock() => block.text.length,
    ListBlock() => block.items.fold<int>(
      0,
      (sum, item) => sum + _listItemExtent(item),
    ),
    ImageBlock() => 1,
  };
  return length < 1 ? 1 : length;
}

int _listItemExtent(BookListItem item) =>
    item.text.length +
    item.children.fold<int>(0, (sum, child) => sum + _listItemExtent(child));

DateTime? _parseDateTime(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value)?.toLocal();
}
