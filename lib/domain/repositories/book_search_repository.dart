import 'package:flow_reading/domain/models/book_search.dart';

/// Searches canonical book content without requiring network access.
abstract interface class BookSearchRepository {
  Future<List<BookSearchResult>> search({
    required String bookId,
    required String query,
    int limit = 50,
  });
}
