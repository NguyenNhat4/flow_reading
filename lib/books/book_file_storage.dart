import 'dart:typed_data';

sealed class BookFileStageResult {
  const BookFileStageResult({required this.bookId});

  final String bookId;
}

final class DuplicateBookFiles extends BookFileStageResult {
  const DuplicateBookFiles({required super.bookId});
}

final class StagedBookFiles extends BookFileStageResult {
  const StagedBookFiles({
    required super.bookId,
    required this.stagingDirectory,
    required this.finalDirectory,
    required this.originalFilePath,
  });

  final String stagingDirectory;
  final String finalDirectory;
  final String originalFilePath;
}

abstract interface class BookFileStorage {
  Future<BookFileStageResult> stageOriginal(Uint8List bytes);

  Future<String> stageAsset(
    StagedBookFiles stage, {
    required String assetId,
    required String extension,
    required Uint8List bytes,
  });

  Future<void> commit(StagedBookFiles stage);

  Future<void> rollback(StagedBookFiles stage);

  Future<void> delete(String bookId);

  Future<bool> contains(String bookId);
}
