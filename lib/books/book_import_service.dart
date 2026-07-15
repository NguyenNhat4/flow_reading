import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flow_reading/books/book_file_storage.dart';
import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_language_detector.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/canonical_html_converter.dart';
import 'package:flow_reading/books/content_identifiers.dart';
import 'package:flow_reading/books/epub_package_parser.dart';
import 'package:flow_reading/books/epub_validator.dart';
import 'package:flow_reading/shared/app_failure.dart';

enum ImportStage {
  validatingFile('Validating file'),
  copyingBook('Copying book'),
  readingMetadata('Reading metadata'),
  parsingChapters('Parsing chapters'),
  detectingLanguage('Detecting language'),
  extractingImages('Extracting images'),
  savingBook('Saving book'),
  complete('Complete');

  const ImportStage(this.label);
  final String label;
}

final class ImportProgress {
  const ImportProgress(this.stage);

  final ImportStage stage;
}

final class ImportOperation {
  ImportOperation._(this._controller, this._result);

  final _ImportController _controller;
  final Future<Book> _result;

  Stream<ImportProgress> get progress => _controller.progress.stream;
  Future<Book> get result => _result;

  void cancel() => _controller.cancelled = true;
}

final class BookImportService {
  const BookImportService({
    required this.repository,
    required this.storage,
    this.languageDetection,
  });

  final BookRepository repository;
  final BookFileStorage storage;
  final BookLanguageDetectionService? languageDetection;

  ImportOperation start(Uint8List bytes, String fileName) {
    final controller = _ImportController();
    final result = Future<Book>(() => _run(controller, bytes, fileName));
    return ImportOperation._(controller, result);
  }

  Future<Book> _run(
    _ImportController controller,
    Uint8List bytes,
    String fileName,
  ) async {
    StagedBookFiles? staged;
    var committed = false;
    var saved = false;
    try {
      controller.emit(ImportStage.validatingFile);
      await Isolate.run(
        () => EpubValidator.validate(bytes).packageDocumentPath,
      );
      controller.checkCancelled();

      final bookId = ContentIdentifiers.book(bytes);
      if (await repository.containsContentHash(bookId)) {
        throw const DuplicateBookFailure();
      }

      controller.emit(ImportStage.copyingBook);
      final stageResult = await storage.stageOriginal(bytes);
      if (stageResult is DuplicateBookFiles) {
        throw const DuplicateBookFailure();
      }
      staged = stageResult as StagedBookFiles;
      controller.checkCancelled();

      controller.emit(ImportStage.readingMetadata);
      controller.emit(ImportStage.parsingChapters);
      final parsed = await Isolate.run(
        () => _parseImport(bytes, fileName, bookId),
      );
      controller.checkCancelled();

      controller.emit(ImportStage.detectingLanguage);
      final detectedLanguage = await languageDetection?.detect(
        chapters: parsed.chapters,
        declaredLanguage: parsed.metadata.language,
      );
      controller.checkCancelled();

      controller.emit(ImportStage.extractingImages);
      final assets = <BookAsset>[];
      for (final canonicalAsset in parsed.assets) {
        controller.checkCancelled();
        final sourceHref = canonicalAsset.asset.sourceHref ?? '';
        final localPath = await storage.stageAsset(
          staged,
          assetId: canonicalAsset.asset.id,
          extension: _extension(sourceHref),
          bytes: canonicalAsset.bytes,
        );
        assets.add(
          BookAsset(
            id: canonicalAsset.asset.id,
            bookId: bookId,
            mediaType: canonicalAsset.asset.mediaType,
            localPath: localPath,
            sourceHref: canonicalAsset.asset.sourceHref,
          ),
        );
      }
      controller.checkCancelled();

      final book = Book(
        id: bookId,
        metadata: parsed.metadata,
        originalFile: staged.originalFilePath,
        chapters: parsed.chapters,
        tableOfContents: parsed.tableOfContents,
        assets: assets,
        detectedLanguage: detectedLanguage ?? parsed.metadata.language,
        importedAt: DateTime.now().toUtc(),
      );

      controller.emit(ImportStage.savingBook);
      await storage.commit(staged);
      committed = true;
      await repository.save(book);
      saved = true;
      controller.emit(ImportStage.complete);
      return book;
    } catch (_) {
      if (staged != null && !saved) {
        if (committed) {
          await storage.delete(staged.bookId);
        } else {
          await storage.rollback(staged);
        }
      }
      rethrow;
    } finally {
      await controller.progress.close();
    }
  }

  static String _extension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1);
  }
}

final class _ImportController {
  final progress = StreamController<ImportProgress>.broadcast();
  bool cancelled = false;

  void emit(ImportStage stage) {
    checkCancelled();
    progress.add(ImportProgress(stage));
  }

  void checkCancelled() {
    if (cancelled) throw const ImportCancelledFailure();
  }
}

final class _ParsedImport {
  const _ParsedImport({
    required this.metadata,
    required this.chapters,
    required this.tableOfContents,
    required this.assets,
  });

  final BookMetadata metadata;
  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final List<CanonicalAsset> assets;
}

_ParsedImport _parseImport(Uint8List bytes, String fileName, String bookId) {
  final validated = EpubValidator.validate(bytes);
  final draft = EpubPackageParser.parse(
    validated,
    bookId: bookId,
    sourceFileName: fileName,
  );
  final content = CanonicalHtmlConverter.convert(
    validated,
    draft,
    assetLocalPath: (assetId, sourceHref) => '',
  );
  return _ParsedImport(
    metadata: draft.metadata,
    chapters: content.chapters,
    tableOfContents: content.tableOfContents,
    assets: content.assets,
  );
}
