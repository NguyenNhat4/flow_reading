import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flow_reading/shared/data/local_database.dart';
import 'package:flow_reading/shared/data/source_file_storage.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:sqflite/sqflite.dart';

class DuplicateBookException implements Exception {
  const DuplicateBookException(this.fingerprint);
  final String fingerprint;
  @override
  String toString() =>
      'A book with source fingerprint $fingerprint already exists.';
}

class SqliteBookRepository implements BookRepository {
  SqliteBookRepository(this._localDatabase, this._sourceStorage);

  final LocalDatabase _localDatabase;
  final SourceFileStorage _sourceStorage;
  final StreamController<List<Book>> _libraryChanges =
      StreamController<List<Book>>.broadcast();

  @override
  Stream<List<Book>> watchLibrary() async* {
    yield await _listBooks();
    yield* _libraryChanges.stream;
  }

  Future<List<Book>> _listBooks() async {
    final db = await _localDatabase.database;
    final rows = await db.query('books', orderBy: 'title COLLATE NOCASE');
    return rows.map(_bookFromRow).toList(growable: false);
  }

  @override
  Future<Book?> getById(String id) async {
    final db = await _localDatabase.database;
    final rows = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _bookFromRow(rows.single);
  }

  @override
  Future<Book?> getBySourceFingerprint(String fingerprint) async {
    final db = await _localDatabase.database;
    final rows = await db.query(
      'books',
      where: 'source_fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    return rows.isEmpty ? null : _bookFromRow(rows.single);
  }

  @override
  Future<void> import(Book book, Uint8List untouchedSourceBytes) async {
    if (await getBySourceFingerprint(book.sourceFingerprint) != null) {
      throw DuplicateBookException(book.sourceFingerprint);
    }
    final staged = await _sourceStorage.stage(book.id, untouchedSourceBytes);
    final persistedBook = book.withSourcePath(staged.finalPath);
    try {
      final db = await _localDatabase.database;
      await db.transaction((transaction) async {
        await _insertBook(transaction, persistedBook);
        await _sourceStorage.commit(staged);
      });
      _libraryChanges.add(await _listBooks());
    } catch (_) {
      await _sourceStorage.discard(staged);
      rethrow;
    }
  }

  Future<void> _insertBook(Transaction transaction, Book book) async {
    await transaction.insert('books', {
      'id': book.id,
      'source_fingerprint': book.sourceFingerprint,
      'source_path': book.sourcePath,
      'title': book.metadata.title,
      'authors': jsonEncode(book.metadata.authors),
      'language': book.metadata.language,
      'cover_image_id': book.metadata.coverImageId,
      'imported_at': book.importedAt.toUtc().toIso8601String(),
      'model_version': book.modelVersion,
      'model_json': jsonEncode(book.toJson()),
    });
    for (final chapter in book.chapters) {
      await transaction.insert('chapters', {
        'id': chapter.id,
        'book_id': book.id,
        'title': chapter.title,
        'source_href': chapter.sourceHref,
        'spine_order': chapter.order,
        'chapter_json': jsonEncode(chapter.toJson()),
      });
      var ordinal = 0;
      for (final block in chapter.blocks) {
        await _insertContent(
          transaction,
          bookId: book.id,
          chapterId: chapter.id,
          parentId: chapter.id,
          id: block.id,
          type: 'block',
          ordinal: ordinal++,
          text: block.paragraph?.text,
          json: block.toJson(),
        );
        final paragraph = block.paragraph;
        if (paragraph == null) continue;
        await _insertContent(
          transaction,
          bookId: book.id,
          chapterId: chapter.id,
          parentId: block.id,
          id: paragraph.id,
          type: 'paragraph',
          ordinal: ordinal++,
          text: paragraph.text,
          json: paragraph.toJson(),
        );
        for (final sentence in paragraph.sentences) {
          await _insertContent(
            transaction,
            bookId: book.id,
            chapterId: chapter.id,
            parentId: paragraph.id,
            id: sentence.id,
            type: 'sentence',
            ordinal: ordinal++,
            text: sentence.text,
            json: sentence.toJson(),
          );
          for (final word in sentence.words) {
            await _insertContent(
              transaction,
              bookId: book.id,
              chapterId: chapter.id,
              parentId: sentence.id,
              id: word.id,
              type: 'word',
              ordinal: ordinal++,
              text: word.text,
              json: word.toJson(),
            );
          }
        }
      }
    }
    if (book.readingState case final state?) {
      await transaction.insert('reading_states', _readingStateRow(state));
    }
    for (final annotation in book.annotations) {
      await transaction.insert('annotations', _annotationRow(annotation));
    }
    for (final entry in book.glossary) {
      await transaction.insert('glossary_entries', {
        'id': entry.id,
        'book_id': entry.bookId,
        'source_term': entry.sourceTerm,
        'target_language': entry.targetLanguage,
        'revision': entry.revision,
        'entry_json': jsonEncode(entry.toJson()),
        'updated_at': entry.updatedAt.toUtc().toIso8601String(),
      });
    }
    for (final overview in book.chapterOverviews) {
      await transaction.insert('chapter_overviews', {
        'chapter_id': overview.chapterId,
        'book_id': book.id,
        'overview_json': jsonEncode(overview.toJson()),
        'generated_at': overview.generatedAt.toUtc().toIso8601String(),
      });
    }
  }

  Future<void> _insertContent(
    Transaction transaction, {
    required String bookId,
    required String chapterId,
    required String parentId,
    required String id,
    required String type,
    required int ordinal,
    required String? text,
    required Json json,
  }) async {
    await transaction.insert('canonical_content', {
      'id': id,
      'book_id': bookId,
      'chapter_id': chapterId,
      'parent_id': parentId,
      'node_type': type,
      'ordinal': ordinal,
      'plain_text': text,
      'content_json': jsonEncode(json),
    });
    if (text != null && text.trim().isNotEmpty && type != 'word') {
      await transaction.insert('content_fts', {
        'content_id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'plain_text': text,
      });
    }
  }

  @override
  Future<void> delete(
    String bookId, {
    required bool deleteAssociatedData,
  }) async {
    final book = await getById(bookId);
    if (book == null) return;
    final trashPath = await _sourceStorage.moveToTrash(book.sourcePath);
    try {
      final db = await _localDatabase.database;
      await db.transaction((transaction) async {
        await transaction.delete(
          'content_fts',
          where: 'book_id = ?',
          whereArgs: [bookId],
        );
        await transaction.delete('books', where: 'id = ?', whereArgs: [bookId]);
        if (deleteAssociatedData) {
          for (final table in [
            'annotations',
            'ai_cache',
            'translations',
            'glossary_entries',
            'chapter_overviews',
            'conversations',
          ]) {
            await transaction.delete(
              table,
              where: 'book_id = ?',
              whereArgs: [bookId],
            );
          }
        }
      });
      await _sourceStorage.purgeTrash(trashPath);
      _libraryChanges.add(await _listBooks());
    } catch (_) {
      if (trashPath != null) {
        await _sourceStorage.restoreFromTrash(trashPath, book.sourcePath);
      }
      rethrow;
    }
  }

  Book _bookFromRow(Map<String, Object?> row) => Book.fromJson(
    (jsonDecode(row['model_json']! as String) as Map<String, Object?>)
      ..['sourcePath'] = row['source_path'],
  );

  Map<String, Object?> _readingStateRow(ReadingState state) => {
    'book_id': state.bookId,
    'content_id': state.locator.contentId,
    'character_offset': state.locator.characterOffset,
    'word_offset': state.locator.wordOffset,
    'locator_json': jsonEncode(state.locator.toJson()),
    'progress': state.progress,
    'last_opened_at': state.lastOpenedAt?.toUtc().toIso8601String(),
    'updated_at': state.updatedAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> _annotationRow(Annotation annotation) => {
    'id': annotation.id,
    'book_id': annotation.bookId,
    'kind': annotation.kind.name,
    'start_content_id': annotation.start.contentId,
    'end_content_id': annotation.end.contentId,
    'annotation_json': jsonEncode(annotation.toJson()),
    'created_at': annotation.createdAt.toUtc().toIso8601String(),
    'updated_at': annotation.updatedAt.toUtc().toIso8601String(),
  };
}
