import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/domain/repositories/table_of_contents_repository.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads an immutable reader session from domain repositories', () async {
    final viewModel = _viewModel();

    await viewModel.load();

    expect(viewModel.isLoaded, isTrue);
    expect(viewModel.loadError, isNull);
    expect(viewModel.chapters.single.id, 'chapter');
    expect(viewModel.tableOfContents.single.title, 'Chapter');
    expect(viewModel.settings, ReaderSettings.defaults);
    viewModel.dispose();
  });

  test('TOC navigation resolves a stable locator and persists it', () async {
    final positions = _PositionRepository();
    final viewModel = _viewModel(positions: positions);
    await viewModel.load();

    final navigated = viewModel.navigateTo(
      const ChapterReference(chapterId: 'chapter', blockId: 'block'),
    );
    await viewModel.savePosition();

    expect(navigated, isTrue);
    expect(viewModel.locator?.anchor.blockId, 'block');
    expect(positions.saved.last.locator.anchor.startOffset, 0);
    viewModel.dispose();
  });

  test('loads and toggles exact anchored highlights', () async {
    final highlights = _HighlightRepository();
    final viewModel = _viewModel(highlights: highlights);
    await viewModel.load();
    final range = TextAnchor(
      bookId: 'book',
      chapterId: 'chapter',
      blockId: 'block',
      startOffset: 0,
      endOffset: 4,
    );

    expect(await viewModel.toggleHighlight(range), isTrue);
    expect(viewModel.isHighlighted(range), isTrue);
    expect(highlights.saved.single.range.id, range.id);

    expect(await viewModel.toggleHighlight(range), isTrue);
    expect(viewModel.isHighlighted(range), isFalse);
    expect(highlights.deleted, [range.id]);
    viewModel.dispose();
  });

  test('highlight loading failure does not prevent reading', () async {
    final viewModel = _viewModel(
      highlights: _HighlightRepository(loadError: StateError('broken')),
    );

    await viewModel.load();

    expect(viewModel.isLoaded, isTrue);
    expect(viewModel.loadError, isNull);
    expect(viewModel.highlightLoadError, isA<StateError>());
    expect(viewModel.chapters, isNotEmpty);
    viewModel.dispose();
  });
}

ReaderViewModel _viewModel({
  _PositionRepository? positions,
  _HighlightRepository? highlights,
}) => ReaderViewModel(
  book: _summary,
  bookRepository: _BookRepository(),
  positionRepository: positions ?? _PositionRepository(),
  settingsRepository: _SettingsRepository(),
  highlightRepository: highlights,
  tableOfContentsRepository: _TocRepository(),
);

final _summary = BookSummary(
  id: 'book',
  title: 'Book',
  authors: const [],
  importedAt: DateTime.utc(2026),
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
      spans: [InlineTextSpan(text: 'Text')],
    ),
  ],
);

final class _BookRepository implements BookRepository {
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

final class _PositionRepository implements ReadingPositionRepository {
  final List<ReadingPosition> saved = [];

  @override
  Future<ReadingPosition?> load(String bookId) async => null;

  @override
  Future<void> save(ReadingPosition position) async => saved.add(position);
}

final class _SettingsRepository implements ReaderSettingsRepository {
  @override
  Future<ReaderSettings> load() async => ReaderSettings.defaults;

  @override
  Future<void> save(ReaderSettings settings) async {}
}

final class _TocRepository implements TableOfContentsRepository {
  @override
  Future<List<TableOfContentsEntry>> load(String bookId) async => const [
    TableOfContentsEntry(
      title: 'Chapter',
      reference: ChapterReference(chapterId: 'chapter', blockId: 'block'),
    ),
  ];
}

final class _HighlightRepository implements HighlightRepository {
  _HighlightRepository({this.loadError});

  final Object? loadError;
  final List<Highlight> saved = [];
  final List<String> deleted = [];

  @override
  Future<void> delete(String highlightId) async => deleted.add(highlightId);

  @override
  Future<List<Highlight>> listForBook(String bookId) async {
    final error = loadError;
    if (error != null) throw error;
    return List.unmodifiable(saved);
  }

  @override
  Future<void> save(Highlight highlight) async => saved.add(highlight);
}
