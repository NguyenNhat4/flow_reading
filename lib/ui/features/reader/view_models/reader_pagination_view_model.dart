import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/use_cases/paginate_chapter.dart';
import 'package:flutter/foundation.dart';

enum PaginationStatus { initial, loading, ready, failure }

final class ReaderPage {
  const ReaderPage({required this.chapter, required this.boundary});

  final Chapter chapter;
  final PageBoundary boundary;
}

/// Immutable temporary layout state for the reader pager.
final class PaginationState {
  PaginationState({
    this.status = PaginationStatus.initial,
    List<ReaderPage> pages = const [],
    this.requestedLayoutKey,
    this.activeLayoutKey,
    this.currentPage = 0,
    this.errorMessage,
  }) : pages = List.unmodifiable(pages);

  final PaginationStatus status;
  final List<ReaderPage> pages;
  final String? requestedLayoutKey;
  final String? activeLayoutKey;
  final int currentPage;
  final String? errorMessage;
}

/// Coordinates asynchronous pagination independently from widget rendering.
final class ReaderPaginationViewModel extends ChangeNotifier {
  ReaderPaginationViewModel({
    required this._measurer,
    this._engine = const PaginationEngine(),
  });

  final ContentMeasurer _measurer;
  final PaginationEngine _engine;
  PaginationState _state = PaginationState();
  int _generation = 0;
  bool _disposed = false;

  PaginationState get state => _state;

  void invalidate() {
    _generation++;
    _setState(PaginationState());
  }

  Future<void> paginate({
    required List<Chapter> chapters,
    required ReaderLayout layout,
    required ReadingLocator? target,
  }) async {
    final key = layout.paginationCacheKey;
    if (_state.requestedLayoutKey == key) return;
    final generation = ++_generation;
    _setState(
      PaginationState(
        status: PaginationStatus.loading,
        requestedLayoutKey: key,
      ),
    );
    try {
      final orderedChapters = [...chapters]
        ..sort((left, right) => left.order.compareTo(right.order));
      final pages = <ReaderPage>[];
      for (final chapter in orderedChapters) {
        final result = _engine.paginate(
          chapter: chapter,
          layout: layout,
          measurer: _measurer,
        );
        pages.addAll(
          result.pages.map(
            (boundary) => ReaderPage(chapter: chapter, boundary: boundary),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        if (_disposed || generation != _generation) return;
      }
      final initialPage = _pageForLocator(pages, target);
      _setState(
        PaginationState(
          status: PaginationStatus.ready,
          pages: pages,
          requestedLayoutKey: key,
          activeLayoutKey: key,
          currentPage: initialPage,
        ),
      );
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _setState(
        PaginationState(
          status: PaginationStatus.failure,
          requestedLayoutKey: key,
          activeLayoutKey: key,
          errorMessage: 'This book could not be paginated.',
        ),
      );
    }
  }

  TextAnchor? showPage(int index) {
    if (index < 0 || index >= _state.pages.length) return null;
    _setState(
      PaginationState(
        status: _state.status,
        pages: _state.pages,
        requestedLayoutKey: _state.requestedLayoutKey,
        activeLayoutKey: _state.activeLayoutKey,
        currentPage: index,
      ),
    );
    return _state.pages[index].boundary.start;
  }

  void _setState(PaginationState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  static int _pageForLocator(List<ReaderPage> pages, ReadingLocator? locator) {
    if (pages.isEmpty || locator == null) return 0;
    final anchor = locator.anchor;
    final chapterPages = <int>[];
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      if (page.chapter.id != anchor.chapterId) continue;
      chapterPages.add(index);
      if (_contains(page, anchor)) return index;
    }
    if (chapterPages.isEmpty) return 0;
    final lastIndex = chapterPages.last;
    final last = pages[lastIndex];
    if (last.boundary.end.blockId == anchor.blockId &&
        anchor.startOffset >= last.boundary.end.startOffset) {
      return lastIndex;
    }
    for (final index in chapterPages.reversed) {
      final start = pages[index].boundary.start;
      if (_compare(pages[index].chapter, anchor, start) >= 0) return index;
    }
    return chapterPages.first;
  }

  static bool _contains(ReaderPage page, TextAnchor anchor) =>
      _compare(page.chapter, anchor, page.boundary.start) >= 0 &&
      _compare(page.chapter, anchor, page.boundary.end) < 0;

  static int _compare(Chapter chapter, TextAnchor left, TextAnchor right) {
    final blocks = [...chapter.blocks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final leftIndex = blocks.indexWhere((block) => block.id == left.blockId);
    final rightIndex = blocks.indexWhere((block) => block.id == right.blockId);
    if (leftIndex != rightIndex) return leftIndex.compareTo(rightIndex);
    return left.startOffset.compareTo(right.startOffset);
  }
}
