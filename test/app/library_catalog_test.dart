import 'package:flow_reading/app/library_catalog.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('searches title and author without case sensitivity', () {
    final books = [
      _summary(id: 'one', title: 'The River', authors: ['Ursula Le Guin']),
      _summary(id: 'two', title: 'Distant Hills', authors: ['Octavia Butler']),
      _summary(id: 'three', title: 'Ocean Light', authors: ['N. K. Jemisin']),
    ];

    expect(
      filterAndSortBooks(
        books,
        query: '  RIVER ',
        sort: LibrarySort.title,
      ).map((book) => book.id),
      ['one'],
    );
    expect(
      filterAndSortBooks(
        books,
        query: 'butLER',
        sort: LibrarySort.title,
      ).map((book) => book.id),
      ['two'],
    );
  });

  test('supports every library sort order', () {
    final books = [
      _summary(
        id: 'b',
        title: 'Beta',
        authors: ['Zed'],
        importedAt: DateTime.utc(2026, 1, 2),
        lastOpenedAt: DateTime.utc(2026, 1, 4),
        progress: 0.25,
      ),
      _summary(
        id: 'a',
        title: 'Alpha',
        authors: ['Amy'],
        importedAt: DateTime.utc(2026, 1, 3),
        progress: 0.75,
      ),
      _summary(
        id: 'c',
        title: 'Gamma',
        importedAt: DateTime.utc(2026, 1, 1),
        lastOpenedAt: DateTime.utc(2026, 1, 5),
        progress: 0.5,
      ),
    ];

    expect(_ids(books, LibrarySort.title), ['a', 'b', 'c']);
    expect(_ids(books, LibrarySort.author), ['a', 'b', 'c']);
    expect(_ids(books, LibrarySort.recentActivity), ['c', 'b', 'a']);
    expect(_ids(books, LibrarySort.readingProgress), ['a', 'c', 'b']);
    expect(_ids(books, LibrarySort.importDate), ['a', 'b', 'c']);
  });

  test('filters a moderately sized local library correctly', () {
    final books = [
      for (var index = 0; index < 500; index++)
        _summary(
          id: '$index',
          title: index % 50 == 0 ? 'Needle $index' : 'Book $index',
          authors: ['Author ${499 - index}'],
        ),
    ];

    final result = filterAndSortBooks(
      books,
      query: 'needle',
      sort: LibrarySort.title,
    );

    expect(result, hasLength(10));
    expect(result.every((book) => book.title.startsWith('Needle')), isTrue);
  });
}

List<String> _ids(List<BookSummary> books, LibrarySort sort) =>
    filterAndSortBooks(
      books,
      query: '',
      sort: sort,
    ).map((book) => book.id).toList();

BookSummary _summary({
  required String id,
  required String title,
  List<String> authors = const [],
  DateTime? importedAt,
  DateTime? lastOpenedAt,
  double progress = 0,
}) => BookSummary(
  id: id,
  title: title,
  authors: authors,
  importedAt: importedAt ?? DateTime.utc(2026),
  lastOpenedAt: lastOpenedAt,
  readingProgress: progress,
);
