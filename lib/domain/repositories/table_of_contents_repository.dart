import 'package:flow_reading/domain/models/book_models.dart';

/// Loads canonical EPUB navigation entries for a book.
abstract interface class TableOfContentsRepository {
  Future<List<TableOfContentsEntry>> load(String bookId);
}
