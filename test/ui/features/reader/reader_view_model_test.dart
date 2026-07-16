import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
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
}

ReaderViewModel _viewModel({_PositionRepository? positions}) => ReaderViewModel(
  book: _summary,
  bookRepository: _BookRepository(),
  positionRepository: positions ?? _PositionRepository(),
  settingsRepository: _SettingsRepository(),
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
