import 'dart:async';
import 'dart:typed_data';

import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/content_identifiers.dart';
import 'package:flow_reading/domain/repositories/book_file_storage.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/epub_content_parser.dart';
import 'package:flow_reading/domain/use_cases/detect_book_language.dart';

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

/// Imports an EPUB into canonical storage as one recoverable workflow.
final class ImportBookUseCase {
  const ImportBookUseCase({
    required this.repository,
    required this.storage,
    required this.parser,
    this.languageDetection,
  });

  final BookRepository repository;
  final BookFileStorage storage;
  final EpubContentParser parser;
  final DetectBookLanguageUseCase? languageDetection;

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
      final parsed = await parser.parse(
        bytes: bytes,
        fileName: fileName,
        bookId: bookId,
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
      for (final parsedAsset in parsed.assets) {
        controller.checkCancelled();
        final sourceHref = parsedAsset.asset.sourceHref ?? '';
        final localPath = await storage.stageAsset(
          staged,
          assetId: parsedAsset.asset.id,
          extension: _extension(sourceHref),
          bytes: parsedAsset.bytes,
        );
        assets.add(
          BookAsset(
            id: parsedAsset.asset.id,
            bookId: bookId,
            mediaType: parsedAsset.asset.mediaType,
            localPath: localPath,
            sourceHref: parsedAsset.asset.sourceHref,
          ),
        );
      }

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
