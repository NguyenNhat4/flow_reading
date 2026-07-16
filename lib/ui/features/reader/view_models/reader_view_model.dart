import 'dart:async';

import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
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
    TableOfContentsRepository? tableOfContentsRepository,
  }) => ReaderViewModel._(
    book,
    bookRepository,
    positionRepository,
    settingsRepository,
    tableOfContentsRepository,
  );

  ReaderViewModel._(
    this.book,
    this._bookRepository,
    this._positionRepository,
    this._settingsRepository,
    this._tableOfContentsRepository,
  );

  final BookSummary book;
  final BookRepository _bookRepository;
  final ReadingPositionRepository _positionRepository;
  final ReaderSettingsRepository _settingsRepository;
  final TableOfContentsRepository? _tableOfContentsRepository;

  Future<void>? _loading;
  Future<void> _saveTail = Future<void>.value();
  ReaderSettings _settings = ReaderSettings.defaults;
  ReadingLocator? _locator;
  List<Chapter> _chapters = const [];
  List<TableOfContentsEntry> _tableOfContents = const [];
  Object? _loadError;
  int _readerGeneration = 0;
  bool _loaded = false;
  bool _disposed = false;

  ReaderSettings get settings => _settings;
  ReadingLocator? get locator => _locator;
  List<Chapter> get chapters => _chapters;
  List<TableOfContentsEntry> get tableOfContents => _tableOfContents;
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
    } catch (error) {
      _loadError = error;
    } finally {
      _loaded = true;
      _notify();
    }
  }

  void showPosition(TextAnchor anchor) {
    _locator = ReadingLocator(anchor: anchor);
    unawaited(savePosition().catchError((Object _) {}));
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
    _locator = ReadingLocator(
      anchor: TextAnchor(
        bookId: book.id,
        chapterId: chapter.id,
        blockId: block.id,
        startOffset: 0,
        endOffset: 0,
      ),
    );
    _readerGeneration++;
    _notify();
    unawaited(savePosition().catchError((Object _) {}));
    return true;
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
