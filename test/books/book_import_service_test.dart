import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/books/book_file_storage.dart';
import 'package:flow_reading/books/book_import_service.dart';
import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/shared/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports all stages and saves a completed canonical book', () async {
    final repository = _FakeRepository();
    final storage = _FakeStorage();
    final service = BookImportService(repository: repository, storage: storage);
    final operation = service.start(_epub(), 'book.epub');
    final stages = <ImportStage>[];
    final subscription = operation.progress.listen(
      (progress) => stages.add(progress.stage),
    );

    final book = await operation.result;
    await subscription.cancel();

    expect(stages, ImportStage.values);
    expect(repository.saved, same(book));
    expect(book.chapters.single.blocks.single, isA<ParagraphBlock>());
    expect(storage.committed, isTrue);
    expect(storage.rolledBack, isFalse);
  });

  test('cancellation stops persistence without leaving copied data', () async {
    final repository = _FakeRepository();
    final storage = _FakeStorage();
    final operation = BookImportService(
      repository: repository,
      storage: storage,
    ).start(_epub(), 'book.epub');

    operation.cancel();

    await expectLater(operation.result, throwsA(isA<ImportCancelledFailure>()));
    expect(repository.saved, isNull);
    expect(storage.committed, isFalse);
  });

  test('cancellation after copying rolls back staged files', () async {
    final repository = _FakeRepository();
    final storage = _FakeStorage();
    final operation = BookImportService(
      repository: repository,
      storage: storage,
    ).start(_epub(), 'book.epub');
    final subscription = operation.progress.listen((progress) {
      if (progress.stage == ImportStage.copyingBook) operation.cancel();
    });

    await expectLater(operation.result, throwsA(isA<ImportCancelledFailure>()));
    await subscription.cancel();

    expect(storage.rolledBack, isTrue);
    expect(repository.saved, isNull);
  });

  test('database failure removes finalized import files', () async {
    final repository = _FakeRepository(failSave: true);
    final storage = _FakeStorage();
    final operation = BookImportService(
      repository: repository,
      storage: storage,
    ).start(_epub(), 'book.epub');

    await expectLater(operation.result, throwsA(isA<DatabaseFailure>()));

    expect(storage.committed, isTrue);
    expect(storage.deleted, isTrue);
  });

  test('duplicate content is rejected before copying', () async {
    final repository = _FakeRepository(duplicate: true);
    final storage = _FakeStorage();
    final operation = BookImportService(
      repository: repository,
      storage: storage,
    ).start(_epub(), 'book.epub');

    await expectLater(operation.result, throwsA(isA<DuplicateBookFailure>()));
    expect(storage.stageCalls, 0);
  });
}

final class _FakeStorage implements BookFileStorage {
  bool committed = false;
  bool rolledBack = false;
  bool deleted = false;
  int stageCalls = 0;

  @override
  Future<BookFileStageResult> stageOriginal(Uint8List bytes) async {
    stageCalls++;
    return const StagedBookFiles(
      bookId: 'book_id',
      stagingDirectory: '/tmp/staged',
      finalDirectory: '/books/book_id',
      originalFilePath: '/books/book_id/original.epub',
    );
  }

  @override
  Future<String> stageAsset(
    StagedBookFiles stage, {
    required String assetId,
    required String extension,
    required Uint8List bytes,
  }) async => '/books/book_id/assets/$assetId.$extension';

  @override
  Future<void> commit(StagedBookFiles stage) async => committed = true;

  @override
  Future<void> rollback(StagedBookFiles stage) async => rolledBack = true;

  @override
  Future<void> delete(String bookId) async => deleted = true;

  @override
  Future<bool> contains(String bookId) async => false;

  @override
  Future<Uint8List?> readBytes(String localPath) async => null;
}

final class _FakeRepository implements BookRepository {
  _FakeRepository({this.duplicate = false, this.failSave = false});

  final bool duplicate;
  final bool failSave;
  Book? saved;

  @override
  Future<void> save(Book book) async {
    if (failSave) throw const DatabaseFailure();
    saved = book;
  }

  @override
  Future<bool> containsContentHash(String contentHash) async => duplicate;

  @override
  Future<void> delete(String bookId) async {}

  @override
  Future<List<Chapter>> loadChapters(String bookId) async => const [];

  @override
  Future<List<BookSummary>> listBooks() async => const [];

  @override
  Future<BookMetadata?> readMetadata(String bookId) async => null;

  @override
  Future<void> updateDetectedLanguage(String bookId, String? language) async {}
}

Uint8List _epub() {
  final archive = Archive()
    ..add(
      ArchiveFile.noCompress(
        'mimetype',
        20,
        utf8.encode('application/epub+zip'),
      ),
    )
    ..add(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<container><rootfiles><rootfile full-path="EPUB/content.opf"/></rootfiles></container>',
      ),
    )
    ..add(
      ArchiveFile.string(
        'EPUB/content.opf',
        '''<package><metadata><title>Book</title><language>en</language></metadata>
<manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
<spine><itemref idref="chapter"/></spine></package>''',
      ),
    )
    ..add(
      ArchiveFile.string(
        'EPUB/chapter.xhtml',
        '<html><body><p>Hello world.</p></body></html>',
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
