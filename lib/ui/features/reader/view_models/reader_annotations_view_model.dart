import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:flow_reading/domain/use_cases/manage_reader_annotations.dart';
import 'package:flow_reading/ui/core/ui_command_result.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flutter/foundation.dart';

/// Immutable reader annotation state with independent load failures.
final class ReaderAnnotationsState {
  ReaderAnnotationsState({
    List<Bookmark> bookmarks = const [],
    List<Highlight> highlights = const [],
    List<ReaderNote> notes = const [],
    this.bookmarkErrorMessage,
    this.highlightErrorMessage,
    this.noteErrorMessage,
  }) : bookmarks = List.unmodifiable(bookmarks),
       highlights = List.unmodifiable(highlights),
       notes = List.unmodifiable(notes);

  final List<Bookmark> bookmarks;
  final List<Highlight> highlights;
  final List<ReaderNote> notes;
  final String? bookmarkErrorMessage;
  final String? highlightErrorMessage;
  final String? noteErrorMessage;
}

/// Owns bookmarks, highlights, and notes for one reader session.
final class ReaderAnnotationsViewModel extends ChangeNotifier {
  ReaderAnnotationsViewModel({
    required this.bookId,
    required this._bookmarkRepository,
    required this._highlightRepository,
    required this._noteRepository,
    this._toggleBookmark,
    this._deleteBookmark,
    this._toggleHighlight,
    this._upsertNote,
    this._deleteNote,
    this._failureMapper = const UiFailureMapper(),
  });

  final String bookId;
  final BookmarkRepository? _bookmarkRepository;
  final HighlightRepository? _highlightRepository;
  final NoteRepository? _noteRepository;
  final ToggleBookmarkUseCase? _toggleBookmark;
  final DeleteBookmarkUseCase? _deleteBookmark;
  final ToggleHighlightUseCase? _toggleHighlight;
  final UpsertNoteUseCase? _upsertNote;
  final DeleteNoteUseCase? _deleteNote;
  final UiFailureMapper _failureMapper;

  ReaderAnnotationsState _state = ReaderAnnotationsState();
  bool _disposed = false;

  ReaderAnnotationsState get state => _state;

  Future<void> load() async {
    var bookmarks = const <Bookmark>[];
    var highlights = const <Highlight>[];
    var notes = const <ReaderNote>[];
    String? bookmarkError;
    String? highlightError;
    String? noteError;

    try {
      bookmarks = await _bookmarkRepository?.listForBook(bookId) ?? const [];
    } catch (error) {
      bookmarkError = _failureMapper.message(
        error,
        fallback: 'Bookmarks could not be loaded.',
      );
    }
    try {
      highlights = await _highlightRepository?.listForBook(bookId) ?? const [];
    } catch (error) {
      highlightError = _failureMapper.message(
        error,
        fallback: 'Highlights could not be loaded.',
      );
    }
    try {
      notes = await _noteRepository?.listForBook(bookId) ?? const [];
    } catch (error) {
      noteError = _failureMapper.message(
        error,
        fallback: 'Notes could not be loaded.',
      );
    }
    _setState(
      ReaderAnnotationsState(
        bookmarks: bookmarks,
        highlights: highlights,
        notes: notes,
        bookmarkErrorMessage: bookmarkError,
        highlightErrorMessage: highlightError,
        noteErrorMessage: noteError,
      ),
    );
  }

  bool isBookmarked(ReadingLocator locator) =>
      _state.bookmarks.any((bookmark) => bookmark.id == locator.anchor.id);

  bool isHighlighted(TextAnchor range) =>
      _state.highlights.any((highlight) => highlight.id == range.id);

  ReaderNote? noteFor(TextAnchor range) =>
      _state.notes.where((note) => note.id == range.id).firstOrNull;

  Future<UiCommandResult<void>> toggleBookmark(ReadingLocator locator) async {
    final useCase = _toggleBookmark;
    if (useCase == null) {
      return const UiCommandFailure('Bookmarks are unavailable.');
    }
    try {
      final existing = isBookmarked(locator);
      final bookmark = await useCase(locator: locator, isBookmarked: existing);
      final bookmarks = existing
          ? _state.bookmarks.where((item) => item.id != locator.anchor.id)
          : [bookmark!, ..._state.bookmarks];
      _replace(bookmarks: bookmarks.toList());
      return const UiCommandSuccess(null);
    } catch (error) {
      return _failure(error, 'The bookmark could not be updated.');
    }
  }

  Future<UiCommandResult<void>> deleteBookmark(String id) async {
    final useCase = _deleteBookmark;
    if (useCase == null) {
      return const UiCommandFailure('Bookmarks are unavailable.');
    }
    try {
      await useCase(id);
      _replace(
        bookmarks: _state.bookmarks.where((item) => item.id != id).toList(),
      );
      return const UiCommandSuccess(null);
    } catch (error) {
      return _failure(error, 'The bookmark could not be removed.');
    }
  }

  Future<UiCommandResult<void>> toggleHighlight(TextAnchor range) async {
    if (range.bookId != bookId || _toggleHighlight == null) {
      return const UiCommandFailure('Highlights are unavailable.');
    }
    try {
      final existing = isHighlighted(range);
      final highlight = await _toggleHighlight(
        range: range,
        isHighlighted: existing,
      );
      final highlights = existing
          ? _state.highlights.where((item) => item.id != range.id)
          : [highlight!, ..._state.highlights];
      _replace(highlights: highlights.toList());
      return const UiCommandSuccess(null);
    } catch (error) {
      return _failure(error, 'The highlight could not be updated.');
    }
  }

  Future<UiCommandResult<void>> saveNote(TextAnchor range, String body) async {
    if (range.bookId != bookId || _upsertNote == null) {
      return const UiCommandFailure('Notes are unavailable.');
    }
    try {
      final note = await _upsertNote(
        range: range,
        body: body,
        existing: noteFor(range),
      );
      _replace(
        notes: [
          note,
          ..._state.notes.where((candidate) => candidate.id != note.id),
        ],
      );
      return const UiCommandSuccess(null);
    } catch (error) {
      return _failure(error, 'The note could not be saved.');
    }
  }

  Future<UiCommandResult<void>> deleteNote(String id) async {
    final useCase = _deleteNote;
    if (useCase == null) {
      return const UiCommandFailure('Notes are unavailable.');
    }
    try {
      await useCase(id);
      _replace(notes: _state.notes.where((item) => item.id != id).toList());
      return const UiCommandSuccess(null);
    } catch (error) {
      return _failure(error, 'The note could not be removed.');
    }
  }

  UiCommandFailure<void> _failure(Object error, String fallback) =>
      UiCommandFailure(_failureMapper.message(error, fallback: fallback));

  void _replace({
    List<Bookmark>? bookmarks,
    List<Highlight>? highlights,
    List<ReaderNote>? notes,
  }) => _setState(
    ReaderAnnotationsState(
      bookmarks: bookmarks ?? _state.bookmarks,
      highlights: highlights ?? _state.highlights,
      notes: notes ?? _state.notes,
      bookmarkErrorMessage: _state.bookmarkErrorMessage,
      highlightErrorMessage: _state.highlightErrorMessage,
      noteErrorMessage: _state.noteErrorMessage,
    ),
  );

  void _setState(ReaderAnnotationsState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
