import 'package:flow_reading/books/book_models.dart';

final class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    required this.authors,
    required this.importedAt,
    this.coverPath,
    this.detectedLanguage,
  });

  final String id;
  final String title;
  final List<String> authors;
  final DateTime importedAt;
  final String? coverPath;
  final String? detectedLanguage;
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
