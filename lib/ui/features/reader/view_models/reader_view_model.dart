import 'dart:async';

import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/models/reader_session.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/domain/repositories/table_of_contents_repository.dart';
import 'package:flow_reading/domain/repositories/utc_clock.dart';
import 'package:flow_reading/domain/use_cases/load_reader_session.dart';
import 'package:flow_reading/domain/use_cases/manage_reader_annotations.dart';
import 'package:flow_reading/domain/use_cases/reader_content_index.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_annotations_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_search_view_model.dart';
import 'package:flutter/foundation.dart';

/// Presentation state for one reader session.
final class ReaderSessionState {
  ReaderSessionState({
    required this.book,
    ReaderSettings? settings,
    this.locator,
    List<Chapter> chapters = const [],
    List<TableOfContentsEntry> tableOfContents = const [],
    this.loadErrorMessage,
    this.readerGeneration = 0,
    this.isLoaded = false,
  }) : settings = settings ?? ReaderSettings.defaults,
       chapters = List.unmodifiable(chapters),
       tableOfContents = List.unmodifiable(tableOfContents);

  final BookSummary book;
  final ReaderSettings settings;
  final ReadingLocator? locator;
  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final String? loadErrorMessage;
  final int readerGeneration;
  final bool isLoaded;
}

/// Presentation state for one reader session.
final class ReaderViewModel extends ChangeNotifier {
  factory ReaderViewModel({
    required BookSummary book,
    required BookRepository bookRepository,
    required ReadingPositionRepository positionRepository,
    required ReaderSettingsRepository settingsRepository,
    BookmarkRepository? bookmarkRepository,
    BookSearchRepository? bookSearchRepository,
    HighlightRepository? highlightRepository,
    NoteRepository? noteRepository,
    TableOfContentsRepository? tableOfContentsRepository,
    LoadReaderSessionUseCase? loadSession,
    UtcClock clock = const _SystemUtcClock(),
    UiFailureMapper failureMapper = const UiFailureMapper(),
  }) {
    final annotations = ReaderAnnotationsViewModel(
      bookId: book.id,
      bookmarkRepository: bookmarkRepository,
      highlightRepository: highlightRepository,
      noteRepository: noteRepository,
      toggleBookmark: bookmarkRepository == null
          ? null
          : ToggleBookmarkUseCase(bookmarkRepository, clock),
      deleteBookmark: bookmarkRepository == null
          ? null
          : DeleteBookmarkUseCase(bookmarkRepository),
      toggleHighlight: highlightRepository == null
          ? null
          : ToggleHighlightUseCase(highlightRepository, clock),
      upsertNote: noteRepository == null
          ? null
          : UpsertNoteUseCase(noteRepository, clock),
      deleteNote: noteRepository == null
          ? null
          : DeleteNoteUseCase(noteRepository),
      failureMapper: failureMapper,
    );
    final search = ReaderSearchViewModel(
      bookId: book.id,
      repository: bookSearchRepository,
      failureMapper: failureMapper,
    );
    return ReaderViewModel._(
      book,
      bookRepository,
      positionRepository,
      settingsRepository,
      tableOfContentsRepository,
      loadSession,
      annotations,
      search,
      clock,
      failureMapper,
    );
  }

  ReaderViewModel._(
    this.book,
    this._bookRepository,
    this._positionRepository,
    this._settingsRepository,
    this._tableOfContentsRepository,
    this._loadSession,
    this.annotations,
    this.search,
    this._clock,
    this._failureMapper,
  ) {
    annotations.addListener(_notify);
    search.addListener(_notify);
  }

  final BookSummary book;
  final BookRepository _bookRepository;
  final ReadingPositionRepository _positionRepository;
  final ReaderSettingsRepository _settingsRepository;
  final TableOfContentsRepository? _tableOfContentsRepository;
  final LoadReaderSessionUseCase? _loadSession;
  final UtcClock _clock;
  final UiFailureMapper _failureMapper;
  final ReaderAnnotationsViewModel annotations;
  final ReaderSearchViewModel search;

  Future<void>? _loading;
  Future<void> _saveTail = Future<void>.value();
  ReaderSettings _settings = ReaderSettings.defaults;
  ReadingLocator? _locator;
  List<Chapter> _chapters = const [];
  List<TableOfContentsEntry> _tableOfContents = const [];
  Object? _loadError;
  String? _loadErrorMessage;
  int _readerGeneration = 0;
  bool _loaded = false;
  bool _disposed = false;
  ReaderContentIndex? _contentIndex;

  ReaderSettings get settings => _settings;
  ReadingLocator? get locator => _locator;
  List<Chapter> get chapters => _chapters;
  List<TableOfContentsEntry> get tableOfContents => _tableOfContents;
  ReaderSessionState get state => ReaderSessionState(
    book: book,
    settings: _settings,
    locator: _locator,
    chapters: _chapters,
    tableOfContents: _tableOfContents,
    loadErrorMessage: _loadErrorMessage,
    readerGeneration: _readerGeneration,
    isLoaded: _loaded,
  );
  List<Bookmark> get bookmarks => annotations.state.bookmarks;
  List<Highlight> get highlights => annotations.state.highlights;
  List<ReaderNote> get notes => annotations.state.notes;
  String? get highlightLoadError => annotations.state.highlightErrorMessage;
  String? get noteLoadError => annotations.state.noteErrorMessage;
  String? get bookmarkLoadError => annotations.state.bookmarkErrorMessage;
  Object? get loadError => _loadError;
  List<BookSearchResult> get searchResults => search.state.results;
  String? get searchError => search.state.errorMessage;
  String get searchQuery => search.state.query;
  bool get isSearching => search.state.isSearching;
  int get readerGeneration => _readerGeneration;
  bool get isLoaded => _loaded;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final session =
          await _loadSession?.call(book.id) ?? await _loadLegacySession();
      _chapters = session.chapters;
      _locator = session.position?.locator;
      _settings = session.settings;
      _tableOfContents = session.tableOfContents;
      _contentIndex = ReaderContentIndex(_chapters);
      await annotations.load();
    } catch (error) {
      _loadError = error;
      _loadErrorMessage = _failureMapper.message(
        error,
        fallback: 'The book could not be opened.',
      );
    } finally {
      _loaded = true;
      _notify();
    }
  }

  Future<ReaderSession> _loadLegacySession() async {
    final results = await Future.wait<Object?>([
      _bookRepository.loadChapters(book.id),
      _positionRepository.load(book.id),
      _settingsRepository.load(),
      _tableOfContentsRepository?.load(book.id) ??
          Future<List<TableOfContentsEntry>>.value(const []),
    ]);
    return ReaderSession(
      chapters: results[0]! as List<Chapter>,
      position: results[1] as ReadingPosition?,
      settings: results[2]! as ReaderSettings,
      tableOfContents: results[3]! as List<TableOfContentsEntry>,
    );
  }

  void showPosition(TextAnchor anchor) {
    _locator = ReadingLocator(anchor: anchor);
    _notify();
    unawaited(savePosition().catchError((Object _) {}));
  }

  bool get isCurrentPositionBookmarked {
    final locator = _locator;
    return locator != null && annotations.isBookmarked(locator);
  }

  Future<bool> toggleBookmark() async {
    final locator = _locator;
    if (locator == null) return false;
    return (await annotations.toggleBookmark(locator)).isSuccess;
  }

  Future<bool> deleteBookmark(String bookmarkId) async =>
      (await annotations.deleteBookmark(bookmarkId)).isSuccess;

  Future<void> searchBook(String query) => search.search(query);

  bool isHighlighted(TextAnchor range) => annotations.isHighlighted(range);

  Future<bool> toggleHighlight(TextAnchor range) async =>
      (await annotations.toggleHighlight(range)).isSuccess;

  ReaderNote? noteFor(TextAnchor range) => annotations.noteFor(range);

  Future<bool> saveNote(TextAnchor range, String body) async =>
      (await annotations.saveNote(range, body)).isSuccess;

  Future<bool> deleteNote(String noteId) async =>
      (await annotations.deleteNote(noteId)).isSuccess;

  bool navigateToAnchor(TextAnchor anchor) {
    final collapsed = _contentIndex?.collapsedAnchor(book.id, anchor);
    if (collapsed == null) return false;
    _locator = ReadingLocator(anchor: collapsed);
    _readerGeneration++;
    _notify();
    unawaited(savePosition().catchError((Object _) {}));
    return true;
  }

  String chapterTitleFor(TextAnchor anchor) =>
      _contentIndex?.chapterTitle(anchor) ?? 'Unknown chapter';

  String passagePreview(TextAnchor anchor) =>
      _contentIndex?.passagePreview(anchor) ?? 'Passage unavailable';

  Future<void> savePosition() {
    final locator = _locator;
    if (locator == null) return Future<void>.value();
    final position = ReadingPosition(
      bookId: book.id,
      locator: locator,
      updatedAt: _clock.now(),
    );
    final save = _saveTail.then((_) => _positionRepository.save(position));
    _saveTail = save.catchError((Object _) {});
    return save;
  }

  Future<bool> updateSettings(ReaderSettings updated) async {
    if (updated == _settings) return true;
    try {
      await savePosition();
      await _settingsRepository.save(updated);
      _settings = updated;
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool navigateTo(ChapterReference reference) {
    final anchor = _contentIndex?.anchorForReference(book.id, reference);
    return anchor != null && navigateToAnchor(anchor);
  }

  void saveForLifecycleChange() {
    unawaited(savePosition().catchError((Object _) {}));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    annotations
      ..removeListener(_notify)
      ..dispose();
    search
      ..removeListener(_notify)
      ..dispose();
    super.dispose();
  }
}

final class _SystemUtcClock implements UtcClock {
  const _SystemUtcClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
