import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/saved_items_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists note context and delegates open and edit actions', (
    tester,
  ) async {
    final note = ReaderNote(
      range: _range,
      body: 'My note',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final viewModel = _viewModel(_Notes([note]));
    await viewModel.load();
    ReaderNote? opened;
    ReaderNote? edited;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSavedItemsPanel(
            viewModel: viewModel,
            onOpenNote: (note) => opened = note,
            onOpenBookmark: (_) {},
            onEditNote: (note) => edited = note,
            onDeleteNote: (_) async => true,
            onDeleteBookmark: (_) async => true,
          ),
        ),
      ),
    );

    expect(find.text('My note'), findsOneWidget);
    expect(find.textContaining('Chapter'), findsOneWidget);
    expect(find.textContaining('Text'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('saved-note-${note.id}')));
    expect(opened, same(note));

    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    expect(edited, same(note));
    expect(tester.takeException(), isNull);
    viewModel.dispose();
  });

  testWidgets('lists, opens, and removes bookmarks from their tab', (
    tester,
  ) async {
    final bookmark = Bookmark(
      locator: ReadingLocator(
        anchor: TextAnchor(
          bookId: 'book',
          chapterId: 'chapter',
          blockId: 'block',
          startOffset: 2,
          endOffset: 2,
        ),
      ),
      createdAt: DateTime.utc(2026),
    );
    final viewModel = _viewModel(
      _Notes(const []),
      bookmarks: _Bookmarks([bookmark]),
    );
    await viewModel.load();
    Bookmark? opened;
    Bookmark? removed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSavedItemsPanel(
            viewModel: viewModel,
            onOpenNote: (_) {},
            onOpenBookmark: (value) => opened = value,
            onEditNote: (_) {},
            onDeleteNote: (_) async => true,
            onDeleteBookmark: (value) async {
              removed = value;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter'), findsOneWidget);
    expect(find.textContaining('Text passage'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('saved-bookmark-${bookmark.id}')));
    expect(opened, same(bookmark));

    await tester.tap(find.byTooltip('Remove bookmark'));
    await tester.pump();
    expect(removed, same(bookmark));
    viewModel.dispose();
  });

  testWidgets('uses a bounded panel in portrait and landscape', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    final viewModel = _viewModel(_Notes(const []));
    await viewModel.load();

    for (final size in [const Size(400, 800), const Size(800, 400)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSavedItemsPanel(
              viewModel: viewModel,
              onOpenNote: (_) {},
              onOpenBookmark: (_) {},
              onEditNote: (_) {},
              onDeleteNote: (_) async => true,
              onDeleteBookmark: (_) async => true,
            ),
          ),
        ),
      );
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    viewModel.dispose();
  });
}

ReaderViewModel _viewModel(
  NoteRepository notes, {
  BookmarkRepository? bookmarks,
}) => ReaderViewModel(
  book: BookSummary(
    id: 'book',
    title: 'Book',
    authors: const [],
    importedAt: DateTime.utc(2026),
  ),
  bookRepository: _Books(),
  positionRepository: _Positions(),
  settingsRepository: _Settings(),
  bookmarkRepository: bookmarks,
  noteRepository: notes,
);

final _range = TextAnchor(
  bookId: 'book',
  chapterId: 'chapter',
  blockId: 'block',
  startOffset: 0,
  endOffset: 4,
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
      spans: [InlineTextSpan(text: 'Text passage')],
    ),
  ],
);

final class _Notes implements NoteRepository {
  _Notes(this.notes);
  final List<ReaderNote> notes;

  @override
  Future<void> delete(String noteId) async {}

  @override
  Future<List<ReaderNote>> listForBook(String bookId) async => notes;

  @override
  Future<void> save(ReaderNote note) async {}
}

final class _Bookmarks implements BookmarkRepository {
  _Bookmarks(this.bookmarks);
  final List<Bookmark> bookmarks;

  @override
  Future<void> delete(String bookmarkId) async {}

  @override
  Future<List<Bookmark>> listForBook(String bookId) async => bookmarks;

  @override
  Future<void> save(Bookmark bookmark) async {}
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
