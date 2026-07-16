import 'package:flow_reading/domain/models/book_models.dart';

final class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    required this.authors,
    required this.importedAt,
    this.coverPath,
    this.detectedLanguage,
    this.readingProgress = 0,
    this.lastOpenedAt,
  });

  final String id;
  final String title;
  final List<String> authors;
  final DateTime importedAt;
  final String? coverPath;
  final String? detectedLanguage;
  final double readingProgress;
  final DateTime? lastOpenedAt;
}

abstract interface class BookRepository {
  Future<void> save(Book book);

  Future<List<BookSummary>> listBooks();

  Future<BookMetadata?> readMetadata(String bookId);

  Future<List<Chapter>> loadChapters(String bookId);

  Future<bool> containsContentHash(String contentHash);

  Future<void> updateDetectedLanguage(String bookId, String? language);

  Future<void> delete(String bookId);
}
