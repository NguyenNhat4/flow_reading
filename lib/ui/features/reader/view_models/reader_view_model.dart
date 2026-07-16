import 'dart:async';

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
import 'package:flutter/foundation.dart';

/// Presentation state for one reader session.
final class ReaderViewModel extends ChangeNotifier {
  factory ReaderViewModel({
    required BookSummary book,
    required BookRepository bookRepository,
    required ReadingPositionRepository positionRepository,
    required ReaderSettingsRepository settingsRepository,
    BookmarkRepository? bookmarkRepository,
    HighlightRepository? highlightRepository,
    NoteRepository? noteRepository,
    TableOfContentsRepository? tableOfContentsRepository,
  }) => ReaderViewModel._(
    book,
    bookRepository,
    positionRepository,
    settingsRepository,
    bookmarkRepository,
    highlightRepository,
    noteRepository,
    tableOfContentsRepository,
  );

  ReaderViewModel._(
    this.book,
    this._bookRepository,
    this._positionRepository,
    this._settingsRepository,
    this._bookmarkRepository,
    this._highlightRepository,
    this._noteRepository,
    this._tableOfContentsRepository,
  );

  final BookSummary book;
  final BookRepository _bookRepository;
  final ReadingPositionRepository _positionRepository;
  final ReaderSettingsRepository _settingsRepository;
  final BookmarkRepository? _bookmarkRepository;
  final HighlightRepository? _highlightRepository;
  final NoteRepository? _noteRepository;
  final TableOfContentsRepository? _tableOfContentsRepository;

  Future<void>? _loading;
  Future<void> _saveTail = Future<void>.value();
  ReaderSettings _settings = ReaderSettings.defaults;
  ReadingLocator? _locator;
  List<Chapter> _chapters = const [];
  List<TableOfContentsEntry> _tableOfContents = const [];
  List<Bookmark> _bookmarks = const [];
  List<Highlight> _highlights = const [];
  List<ReaderNote> _notes = const [];
  Object? _highlightLoadError;
  Object? _noteLoadError;
  Object? _bookmarkLoadError;
  Object? _loadError;
  int _readerGeneration = 0;
  bool _loaded = false;
  bool _disposed = false;

  ReaderSettings get settings => _settings;
  ReadingLocator? get locator => _locator;
  List<Chapter> get chapters => _chapters;
  List<TableOfContentsEntry> get tableOfContents => _tableOfContents;
  List<Bookmark> get bookmarks => _bookmarks;
  List<Highlight> get highlights => _highlights;
  List<ReaderNote> get notes => _notes;
  Object? get highlightLoadError => _highlightLoadError;
  Object? get noteLoadError => _noteLoadError;
  Object? get bookmarkLoadError => _bookmarkLoadError;
  Object? get loadError => _loadError;
  int get readerGeneration => _readerGeneration;
  bool get isLoaded => _loaded;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        _bookRepository.loadChapters(book.id),
        _positionRepository.load(book.id),
        _settingsRepository.load(),
        _tableOfContentsRepository?.load(book.id) ??
            Future<List<TableOfContentsEntry>>.value(const []),
      ]);
      _chapters = List.unmodifiable(results[0]! as List<Chapter>);
      _locator = (results[1] as ReadingPosition?)?.locator;
      _settings = results[2]! as ReaderSettings;
      _tableOfContents = List.unmodifiable(
        results[3]! as List<TableOfContentsEntry>,
      );
      final bookmarkRepository = _bookmarkRepository;
      if (bookmarkRepository != null) {
        try {
          _bookmarks = List.unmodifiable(
            await bookmarkRepository.listForBook(book.id),
          );
        } catch (error) {
          _bookmarkLoadError = error;
        }
      }
      final repository = _highlightRepository;
      if (repository != null) {
        try {
          _highlights = List.unmodifiable(
            await repository.listForBook(book.id),
          );
        } catch (error) {
          _highlightLoadError = error;
        }
      }
      final noteRepository = _noteRepository;
      if (noteRepository != null) {
        try {
          _notes = List.unmodifiable(await noteRepository.listForBook(book.id));
        } catch (error) {
          _noteLoadError = error;
        }
      }
    } catch (error) {
      _loadError = error;
    } finally {
      _loaded = true;
      _notify();
    }
  }

  void showPosition(TextAnchor anchor) {
    _locator = ReadingLocator(anchor: anchor);
    _notify();
    unawaited(savePosition().catchError((Object _) {}));
  }

  bool get isCurrentPositionBookmarked {
    final locator = _locator;
    return locator != null &&
        _bookmarks.any((bookmark) => bookmark.id == locator.anchor.id);
  }

  Future<bool> toggleBookmark() async {
    final repository = _bookmarkRepository;
    final locator = _locator;
    if (repository == null || locator == null) return false;
    final index = _bookmarks.indexWhere(
      (bookmark) => bookmark.id == locator.anchor.id,
    );
    try {
      if (index >= 0) {
        await repository.delete(locator.anchor.id);
        _bookmarks = List.unmodifiable([
          ..._bookmarks.take(index),
          ..._bookmarks.skip(index + 1),
        ]);
      } else {
        final bookmark = Bookmark(
          locator: locator,
          createdAt: DateTime.now().toUtc(),
        );
        await repository.save(bookmark);
        _bookmarks = List.unmodifiable([bookmark, ..._bookmarks]);
      }
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    final repository = _bookmarkRepository;
    if (repository == null) return false;
    try {
      await repository.delete(bookmarkId);
      _bookmarks = List.unmodifiable(
        _bookmarks.where((bookmark) => bookmark.id != bookmarkId),
      );
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool isHighlighted(TextAnchor range) =>
      _highlights.any((highlight) => highlight.id == range.id);

  Future<bool> toggleHighlight(TextAnchor range) async {
    final repository = _highlightRepository;
    if (repository == null || range.bookId != book.id) return false;
    final index = _highlights.indexWhere(
      (highlight) => highlight.id == range.id,
    );
    try {
      if (index >= 0) {
        await repository.delete(range.id);
        _highlights = List.unmodifiable([
          ..._highlights.take(index),
          ..._highlights.skip(index + 1),
        ]);
      } else {
        final now = DateTime.now().toUtc();
        final highlight = Highlight(
          range: range,
          createdAt: now,
          updatedAt: now,
        );
        await repository.save(highlight);
        _highlights = List.unmodifiable([highlight, ..._highlights]);
      }
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  ReaderNote? noteFor(TextAnchor range) =>
      _notes.where((note) => note.id == range.id).firstOrNull;

  Future<bool> saveNote(TextAnchor range, String body) async {
    final repository = _noteRepository;
    if (repository == null || range.bookId != book.id) return false;
    final existing = noteFor(range);
    try {
      final now = DateTime.now().toUtc();
      final note = ReaderNote(
        range: range,
        body: body,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await repository.save(note);
      _notes = List.unmodifiable([
        note,
        ..._notes.where((candidate) => candidate.id != note.id),
      ]);
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNote(String noteId) async {
    final repository = _noteRepository;
    if (repository == null) return false;
    try {
      await repository.delete(noteId);
      _notes = List.unmodifiable(_notes.where((note) => note.id != noteId));
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool navigateToAnchor(TextAnchor anchor) {
    if (anchor.bookId != book.id) return false;
    final chapter = _chapters
        .where((candidate) => candidate.id == anchor.chapterId)
        .firstOrNull;
    if (chapter == null) return false;
    final block = chapter.blocks
        .where((candidate) => candidate.id == anchor.blockId)
        .firstOrNull;
    if (block == null) return false;
    final extent = _canonicalText(block).length;
    if (anchor.startOffset < 0 ||
        anchor.endOffset < anchor.startOffset ||
        anchor.endOffset > extent) {
      return false;
    }
    _locator = ReadingLocator(
      anchor: TextAnchor(
        bookId: anchor.bookId,
        chapterId: anchor.chapterId,
        blockId: anchor.blockId,
        startOffset: anchor.startOffset,
        endOffset: anchor.startOffset,
      ),
    );
    _readerGeneration++;
    _notify();
    unawaited(savePosition().catchError((Object _) {}));
    return true;
  }

  String chapterTitleFor(TextAnchor anchor) =>
      _chapters
          .where((chapter) => chapter.id == anchor.chapterId)
          .map((chapter) => chapter.title)
          .firstOrNull ??
      'Unknown chapter';

  String passagePreview(TextAnchor anchor) {
    final block = _chapters
        .expand((chapter) => chapter.blocks)
        .where((candidate) => candidate.id == anchor.blockId)
        .firstOrNull;
    if (block == null) return 'Passage unavailable';
    final text = _canonicalText(block);
    if (text.isEmpty) return 'Passage unavailable';
    final start = anchor.startOffset.clamp(0, text.length);
    final end = anchor.endOffset.clamp(start, text.length);
    final previewStart = start == end
        ? (start - 40).clamp(0, text.length)
        : start;
    final previewEnd = start == end ? (start + 80).clamp(0, text.length) : end;
    final preview = text
        .substring(previewStart, previewEnd)
        .replaceAll(RegExp(r'\s+'), ' ');
    if (preview.isEmpty) return 'Passage unavailable';
    return preview.length <= 120 ? preview : '${preview.substring(0, 117)}…';
  }

  Future<void> savePosition() {
    final locator = _locator;
    if (locator == null) return Future<void>.value();
    final position = ReadingPosition(
      bookId: book.id,
      locator: locator,
      updatedAt: DateTime.now().toUtc(),
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
    final matchingChapters = _chapters.where(
      (chapter) => chapter.id == reference.chapterId,
    );
    if (matchingChapters.isEmpty) return false;
    final chapter = matchingChapters.single;
    final blocks = [...chapter.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    if (blocks.isEmpty) return false;

    final requestedBlockId = reference.blockId;
    final matchingBlocks = requestedBlockId == null
        ? const <ContentBlock>[]
        : blocks.where((block) => block.id == requestedBlockId).toList();
    if (requestedBlockId != null && matchingBlocks.isEmpty) return false;
    final block = matchingBlocks.isEmpty ? blocks.first : matchingBlocks.single;
    return navigateToAnchor(
      TextAnchor(
        bookId: book.id,
        chapterId: chapter.id,
        blockId: block.id,
        startOffset: 0,
        endOffset: 0,
      ),
    );
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
    super.dispose();
  }
}

String _canonicalText(ContentBlock block) => switch (block) {
  ParagraphBlock() => block.text,
  HeadingBlock() => block.text,
  QuoteBlock() => block.text,
  ListBlock() => block.items.map(_listItemText).join('\n'),
  ImageBlock() => '\uFFFC',
};

String _listItemText(BookListItem item) =>
    [item.text, ...item.children.map(_listItemText)].join('\n');
