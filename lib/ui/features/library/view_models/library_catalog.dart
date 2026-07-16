import 'package:flow_reading/domain/repositories/book_repository.dart';

enum LibrarySort {
  title('Title'),
  author('Author'),
  recentActivity('Recent activity'),
  readingProgress('Reading progress'),
  importDate('Import date');

  const LibrarySort(this.label);

  final String label;
}

List<BookSummary> filterAndSortBooks(
  Iterable<BookSummary> books, {
  required String query,
  required LibrarySort sort,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final result = books.where((book) {
    if (normalizedQuery.isEmpty) return true;
    return book.title.toLowerCase().contains(normalizedQuery) ||
        book.authors.any(
          (author) => author.toLowerCase().contains(normalizedQuery),
        );
  }).toList();
  result.sort((left, right) {
    final comparison = switch (sort) {
      LibrarySort.title => _text(left.title).compareTo(_text(right.title)),
      LibrarySort.author => _compareAuthors(left, right),
      LibrarySort.recentActivity => _activity(right).compareTo(_activity(left)),
      LibrarySort.readingProgress => right.readingProgress.compareTo(
        left.readingProgress,
      ),
      LibrarySort.importDate => right.importedAt.compareTo(left.importedAt),
    };
    return comparison != 0
        ? comparison
        : _text(left.title).compareTo(_text(right.title));
  });
  return result;
}

String _text(String value) => value.toLowerCase();

int _compareAuthors(BookSummary left, BookSummary right) {
  if (left.authors.isEmpty) return right.authors.isEmpty ? 0 : 1;
  if (right.authors.isEmpty) return -1;
  return _text(left.authors.first).compareTo(_text(right.authors.first));
}

DateTime _activity(BookSummary book) => book.lastOpenedAt ?? book.importedAt;
