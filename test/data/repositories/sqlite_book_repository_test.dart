import 'dart:io';

import 'package:flow_reading/data/models/book_record_codec.dart';
import 'package:flow_reading/data/repositories/sqlite_book_repository.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteBookRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-repository-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/books.db',
    );
    repository = SqliteBookRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('saves and restores book metadata and ordered chapters', () async {
    final book = _book();
    await repository.save(book);

    final summaries = await repository.listBooks();
    final metadata = await repository.readMetadata(book.id);
    final chapters = await repository.loadChapters(book.id);

    expect(summaries.single.title, 'Book');
    expect(summaries.single.authors, ['Author']);
    expect(summaries.single.coverPath, '/books/book_id/cover.jpg');
    expect(
      BookRecordCodec.encodeMetadata(metadata!),
      BookRecordCodec.encodeMetadata(book.metadata),
    );
    expect(chapters.map((chapter) => chapter.order), [0, 1]);
    expect(chapters.map((chapter) => chapter.id), ['chapter-1', 'chapter-2']);
    expect(await repository.containsContentHash(book.id), isTrue);
  });

  test('updates detected language and deletes all book rows', () async {
    final book = _book();
    final otherBook = _otherBook();
    await repository.save(book);
    await repository.save(otherBook);

    await repository.updateDetectedLanguage(book.id, 'vi');
    final updatedBook = (await repository.listBooks()).firstWhere(
      (summary) => summary.id == book.id,
    );
    expect(updatedBook.detectedLanguage, 'vi');

    await repository.delete(book.id);
    expect((await repository.listBooks()).map((book) => book.id), [
      otherBook.id,
    ]);
    expect(await repository.loadChapters(book.id), isEmpty);
    expect(await repository.loadChapters(otherBook.id), isNotEmpty);
  });

  test(
    'partial import rolls back and exposes an application failure',
    () async {
      final validBook = _book();
      await repository.save(validBook);
      final invalidBook = Book(
        id: 'other-book',
        metadata: const BookMetadata(title: 'Other'),
        originalFile: '/books/other-book/original.epub',
        chapters: const [
          Chapter(
            id: 'chapter-1',
            bookId: 'other-book',
            title: 'Conflicting chapter',
            order: 0,
            blocks: [],
          ),
        ],
        tableOfContents: const [],
        assets: const [],
        importedAt: DateTime.utc(2026),
      );

      await expectLater(
        repository.save(invalidBook),
        throwsA(isA<DatabaseFailure>()),
      );

      expect(await repository.containsContentHash('other-book'), isFalse);
      expect(await repository.containsContentHash(validBook.id), isTrue);
    },
  );
}

Book _book() => Book(
  id: 'book_id',
  metadata: const BookMetadata(
    title: 'Book',
    authors: ['Author'],
    coverAssetId: 'cover',
  ),
  originalFile: '/books/book_id/original.epub',
  chapters: const [
    Chapter(
      id: 'chapter-1',
      bookId: 'book_id',
      title: 'First',
      order: 0,
      blocks: [],
    ),
    Chapter(
      id: 'chapter-2',
      bookId: 'book_id',
      title: 'Second',
      order: 1,
      blocks: [],
    ),
  ],
  tableOfContents: const [],
  assets: const [
    BookAsset(
      id: 'cover',
      bookId: 'book_id',
      mediaType: 'image/jpeg',
      localPath: '/books/book_id/cover.jpg',
    ),
  ],
  importedAt: DateTime.utc(2026),
);

Book _otherBook() => Book(
  id: 'other_book',
  metadata: const BookMetadata(title: 'Other Book'),
  originalFile: '/books/other_book/original.epub',
  chapters: const [
    Chapter(
      id: 'other-chapter',
      bookId: 'other_book',
      title: 'Other chapter',
      order: 0,
      blocks: [],
    ),
  ],
  tableOfContents: const [],
  assets: const [],
  importedAt: DateTime.utc(2025),
);
