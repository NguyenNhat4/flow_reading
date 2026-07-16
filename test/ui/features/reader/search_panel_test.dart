import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('searches locally and delegates result navigation', (
    tester,
  ) async {
    final result = BookSearchResult(
      segment: const SearchableSegment(
        segmentId: 'block',
        bookId: 'book',
        chapterId: 'chapter',
        blockId: 'block',
        plainText: 'Searchable local passage.',
      ),
      excerpt: 'Searchable local passage.',
      locator: ReadingLocator(
        anchor: TextAnchor(
          bookId: 'book',
          chapterId: 'chapter',
          blockId: 'block',
          startOffset: 0,
          endOffset: 0,
        ),
      ),
    );
    final repository = _SearchRepository(result);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    BookSearchResult? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSearchPanel(
            viewModel: viewModel,
            onOpenResult: (result) => opened = result,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('reader-search-field')),
      'search loc',
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(repository.queries, ['search loc']);
    expect(find.text('Chapter'), findsOneWidget);
    expect(find.text('Searchable local passage.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reader-search-result-block')));
    expect(opened, same(result));
    expect(tester.takeException(), isNull);
    viewModel.dispose();
  });
}

ReaderViewModel _viewModel(BookSearchRepository search) => ReaderViewModel(
  book: BookSummary(
    id: 'book',
    title: 'Book',
    authors: const [],
    importedAt: DateTime.utc(2026),
  ),
  bookRepository: _Books(),
  positionRepository: _Positions(),
  settingsRepository: _Settings(),
  bookSearchRepository: search,
);

const _chapter = Chapter(
  id: 'chapter',
  bookId: 'book',
  title: 'Chapter',
  order: 0,
  blocks: [
    ParagraphBlock(
      id: 'block',
      chapterId: 'chapter',
      order: 0,
      spans: [InlineTextSpan(text: 'Searchable local passage.')],
    ),
  ],
);

final class _SearchRepository implements BookSearchRepository {
  _SearchRepository(this.result);

  final BookSearchResult result;
  final List<String> queries = [];

  @override
  Future<List<BookSearchResult>> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) async {
    queries.add(query);
    return [result];
  }
}

final class _Books implements BookRepository {
  @override
  Future<List<Chapter>> loadChapters(String bookId) async => const [_chapter];
  @override
  Future<List<BookSummary>> listBooks() async => const [];
  @override
  Future<BookMetadata?> readMetadata(String bookId) async => null;
  @override
  Future<bool> containsContentHash(String contentHash) async => false;
  @override
  Future<void> delete(String bookId) async {}
  @override
  Future<void> save(Book book) async {}
  @override
  Future<void> updateDetectedLanguage(String bookId, String? language) async {}
}

final class _Positions implements ReadingPositionRepository {
  @override
  Future<ReadingPosition?> load(String bookId) async => null;
  @override
  Future<void> save(ReadingPosition position) async {}
}

final class _Settings implements ReaderSettingsRepository {
  @override
  Future<ReaderSettings> load() async => ReaderSettings.defaults;
  @override
  Future<void> save(ReaderSettings settings) async {}
}
