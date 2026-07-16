import 'package:flow_reading/domain/repositories/book_repository.dart';

final class StagedBookRemoval {
  const StagedBookRemoval({
    required this.bookId,
    this.activeDirectory,
    this.stagingDirectory,
  });

  final String bookId;
  final String? activeDirectory;
  final String? stagingDirectory;
}

abstract interface class BookRemovalStorage {
  Future<StagedBookRemoval> stageBookRemoval(String bookId);

  Future<void> commitBookRemoval(StagedBookRemoval stage);

  Future<void> rollbackBookRemoval(StagedBookRemoval stage);
}

final class RemoveBookUseCase {
  const RemoveBookUseCase({required this.repository, required this.storage});

  final BookRepository repository;
  final BookRemovalStorage storage;

  Future<void> remove(String bookId) async {
    final stage = await storage.stageBookRemoval(bookId);
    try {
      await repository.delete(bookId);
    } catch (_) {
      await storage.rollbackBookRemoval(stage);
      rethrow;
    }
    await storage.commitBookRemoval(stage);
  }
}
