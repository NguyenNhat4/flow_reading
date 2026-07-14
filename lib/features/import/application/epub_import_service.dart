import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';

class PickedEpub {
  const PickedEpub({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

abstract interface class EpubPicker {
  Future<PickedEpub?> pick();
}

class AndroidEpubPicker implements EpubPicker {
  const AndroidEpubPicker();

  @override
  Future<PickedEpub?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedEpub(name: file.name, bytes: bytes);
  }
}

class EpubImportDraft {
  const EpubImportDraft({required this.book, required this.sourceBytes});
  final Book book;
  final Uint8List sourceBytes;

  EpubImportDraft withLanguage(String languageCode) {
    final code = languageCode.trim().toLowerCase();
    return EpubImportDraft(
      sourceBytes: sourceBytes,
      book: book.withMetadata(
        BookMetadata(
          title: book.metadata.title,
          authors: book.metadata.authors,
          language: code,
          languageConfidence: code == book.metadata.language
              ? book.metadata.languageConfidence
              : 1,
          languageSource: code == book.metadata.language
              ? book.metadata.languageSource
              : 'user-confirmed',
          publisher: book.metadata.publisher,
          description: book.metadata.description,
          coverImageId: book.metadata.coverImageId,
        ),
      ),
    );
  }
}

enum ImportProgressStage {
  reading,
  validating,
  awaitingLanguage,
  saving,
  complete,
}

class EpubImportService {
  EpubImportService({
    required this._picker,
    required this._parser,
    required this._repository,
  });

  final EpubPicker _picker;
  final CanonicalBookParser _parser;
  final BookRepository _repository;

  Future<EpubImportDraft?> prepare({
    void Function(ImportProgressStage stage)? onProgress,
  }) async {
    onProgress?.call(ImportProgressStage.reading);
    final picked = await _picker.pick();
    if (picked == null) return null;
    onProgress?.call(ImportProgressStage.validating);
    final book = await _parser.parse(picked.bytes, sourcePath: picked.name);
    if (await _repository.getBySourceFingerprint(book.sourceFingerprint) !=
        null) {
      throw StateError('This EPUB is already in your library.');
    }
    onProgress?.call(ImportProgressStage.awaitingLanguage);
    return EpubImportDraft(book: book, sourceBytes: picked.bytes);
  }

  Future<void> commit(
    EpubImportDraft draft, {
    void Function(ImportProgressStage stage)? onProgress,
  }) async {
    onProgress?.call(ImportProgressStage.saving);
    await _repository.import(draft.book, draft.sourceBytes);
    onProgress?.call(ImportProgressStage.complete);
  }
}
