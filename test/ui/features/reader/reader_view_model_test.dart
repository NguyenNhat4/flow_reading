import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
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

  test('creates, edits, deletes, previews, and navigates to notes', () async {
    final notes = _NoteRepository();
    final positions = _PositionRepository();
    final viewModel = _viewModel(notes: notes, positions: positions);
    await viewModel.load();
    final range = TextAnchor(
      bookId: 'book',
      chapterId: 'chapter',
      blockId: 'block',
      startOffset: 0,
      endOffset: 4,
    );

    expect(await viewModel.saveNote(range, ' First note '), isTrue);
    expect(viewModel.notes.single.body, 'First note');
    expect(viewModel.passagePreview(range), 'Text');
    expect(viewModel.chapterTitleFor(range), 'Chapter');

    final createdAt = viewModel.notes.single.createdAt;
    expect(await viewModel.saveNote(range, 'Edited note'), isTrue);
    expect(viewModel.notes.single.body, 'Edited note');
    expect(viewModel.notes.single.createdAt, createdAt);

    expect(viewModel.navigateToAnchor(range), isTrue);
    await viewModel.savePosition();
    expect(viewModel.locator?.anchor.startOffset, 0);
    expect(positions.saved.last.locator.anchor.endOffset, 0);

    expect(await viewModel.deleteNote(range.id), isTrue);
    expect(viewModel.notes, isEmpty);
    expect(notes.deleted, [range.id]);
    viewModel.dispose();
  });

  test('toggles, removes, previews, and opens logical bookmarks', () async {
    final bookmarks = _BookmarkRepository();
    final viewModel = _viewModel(bookmarks: bookmarks);
    await viewModel.load();
    final anchor = TextAnchor(
      bookId: 'book',
      chapterId: 'chapter',
      blockId: 'block',
      startOffset: 2,
      endOffset: 2,
    );
    viewModel.showPosition(anchor);

    expect(await viewModel.toggleBookmark(), isTrue);
    expect(viewModel.isCurrentPositionBookmarked, isTrue);
    expect(viewModel.passagePreview(anchor), 'Text');
    expect(bookmarks.saved.single.locator.anchor.id, anchor.id);

    expect(viewModel.navigateToAnchor(anchor), isTrue);
    expect(viewModel.locator?.anchor.id, anchor.id);

    expect(await viewModel.deleteBookmark(anchor.id), isTrue);
    expect(viewModel.bookmarks, isEmpty);
    expect(bookmarks.deleted, [anchor.id]);
    viewModel.dispose();
  });
}

ReaderViewModel _viewModel({
  _PositionRepository? positions,
  _HighlightRepository? highlights,
  _NoteRepository? notes,
  _BookmarkRepository? bookmarks,
}) => ReaderViewModel(
  book: _summary,
  bookRepository: _BookRepository(),
  positionRepository: positions ?? _PositionRepository(),
  settingsRepository: _SettingsRepository(),
  bookmarkRepository: bookmarks,
  highlightRepository: highlights,
  noteRepository: notes,
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

final class _NoteRepository implements NoteRepository {
  final List<ReaderNote> saved = [];
  final List<String> deleted = [];

  @override
  Future<void> delete(String noteId) async => deleted.add(noteId);

  @override
  Future<List<ReaderNote>> listForBook(String bookId) async =>
      List.unmodifiable(saved);

  @override
  Future<void> save(ReaderNote note) async {
    saved
      ..removeWhere((candidate) => candidate.id == note.id)
      ..add(note);
  }
}

final class _BookmarkRepository implements BookmarkRepository {
  final List<Bookmark> saved = [];
  final List<String> deleted = [];

  @override
  Future<void> delete(String bookmarkId) async => deleted.add(bookmarkId);

  @override
  Future<List<Bookmark>> listForBook(String bookId) async =>
      List.unmodifiable(saved);

  @override
  Future<void> save(Bookmark bookmark) async {
    saved
      ..removeWhere((candidate) => candidate.id == bookmark.id)
      ..add(bookmark);
  }
}
