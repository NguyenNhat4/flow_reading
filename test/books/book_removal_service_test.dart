import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_removal_service.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commits staged files after database deletion succeeds', () async {
    final repository = _RemovalRepository();
    final storage = _RemovalStorage();
    final service = BookRemovalService(
      repository: repository,
      storage: storage,
    );

    await service.remove('book-a');

    expect(repository.deletedBookIds, ['book-a']);
    expect(storage.stagedBookIds, ['book-a']);
    expect(storage.committedBookIds, ['book-a']);
    expect(storage.rolledBackBookIds, isEmpty);
  });

  test('restores staged files when database deletion fails', () async {
    final repository = _RemovalRepository(shouldFail: true);
    final storage = _RemovalStorage();
    final service = BookRemovalService(
      repository: repository,
      storage: storage,
    );

    await expectLater(service.remove('book-b'), throwsStateError);

    expect(storage.committedBookIds, isEmpty);
    expect(storage.rolledBackBookIds, ['book-b']);
  });
}

final class _RemovalRepository implements BookRepository {
  _RemovalRepository({this.shouldFail = false});

  final bool shouldFail;
  final List<String> deletedBookIds = [];

  @override
  Future<void> delete(String bookId) async {
    deletedBookIds.add(bookId);
    if (shouldFail) throw StateError('database failed');
  }

  @override
  Future<bool> containsContentHash(String contentHash) async => false;

  @override
  Future<List<Chapter>> loadChapters(String bookId) async => const [];

  @override
  Future<List<BookSummary>> listBooks() async => const [];

  @override
  Future<BookMetadata?> readMetadata(String bookId) async => null;

  @override
  Future<void> save(Book book) async {}

  @override
  Future<void> updateDetectedLanguage(String bookId, String? language) async {}
}

final class _RemovalStorage implements BookRemovalStorage {
  final List<String> stagedBookIds = [];
  final List<String> committedBookIds = [];
  final List<String> rolledBackBookIds = [];

  @override
  Future<StagedBookRemoval> stageBookRemoval(String bookId) async {
    stagedBookIds.add(bookId);
    return StagedBookRemoval(bookId: bookId);
  }

  @override
  Future<void> commitBookRemoval(StagedBookRemoval stage) async {
    committedBookIds.add(stage.bookId);
  }

  @override
  Future<void> rollbackBookRemoval(StagedBookRemoval stage) async {
    rolledBackBookIds.add(stage.bookId);
  }
}
