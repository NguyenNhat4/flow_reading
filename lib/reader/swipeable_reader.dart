import 'dart:async';
import 'dart:math' as math;

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/reader/flutter_content_measurer.dart';
import 'package:flow_reading/reader/pagination_engine.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';

class SwipeableReader extends StatefulWidget {
  const SwipeableReader({
    required this.chapters,
    required this.settings,
    required this.onPositionChanged,
    this.initialLocator,
    super.key,
  });

  final List<Chapter> chapters;
  final ReaderSettings settings;
  final ReadingLocator? initialLocator;
  final ValueChanged<TextAnchor> onPositionChanged;

  @override
  State<SwipeableReader> createState() => _SwipeableReaderState();
}

class _SwipeableReaderState extends State<SwipeableReader> {
  static const _engine = PaginationEngine();
  static const _measurer = FlutterContentMeasurer();

  List<_BookPage>? _pages;
  PageController? _pageController;
  String? _requestedLayoutKey;
  String? _activeLayoutKey;
  Object? _paginationError;
  int _currentPage = 0;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant SwipeableReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chapters, widget.chapters) ||
        oldWidget.settings != widget.settings) {
      _generation++;
      _requestedLayoutKey = null;
      _activeLayoutKey = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!constraints.hasBoundedWidth ||
                  !constraints.hasBoundedHeight ||
                  constraints.maxWidth <= 0 ||
                  constraints.maxHeight <= 0) {
                return const Center(
                  child: Text('The reader viewport is not available.'),
                );
              }
              final layout = ReaderLayout(
                settings: widget.settings,
                viewportWidth: constraints.maxWidth,
                viewportHeight: constraints.maxHeight,
                textScale: MediaQuery.textScalerOf(context).scale(1),
              );
              _ensurePagination(layout);
              if (_paginationError != null &&
                  _requestedLayoutKey == layout.paginationCacheKey) {
                return const Center(
                  child: Text('This book could not be paginated.'),
                );
              }
              if (_activeLayoutKey != layout.paginationCacheKey ||
                  pages == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (pages.isEmpty) {
                return const Center(
                  child: Text('This book has no readable content.'),
                );
              }
              return PageView.builder(
                key: const ValueKey('reader-page-view'),
                controller: _pageController,
                itemCount: pages.length,
                allowImplicitScrolling: true,
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                onPageChanged: _showPage,
                itemBuilder: (context, index) => _ReaderPageContent(
                  key: ValueKey(
                    'reader-page-${pages[index].chapter.id}-${pages[index].boundary.pageIndex}',
                  ),
                  page: pages[index],
                  layout: layout,
                  measurer: _measurer,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: Center(
              child: pages == null || pages.isEmpty
                  ? const SizedBox.shrink()
                  : Semantics(
                      liveRegion: true,
                      label:
                          '${pages[_currentPage].chapter.title}, page ${_currentPage + 1} of ${pages.length}',
                      child: Text(
                        '${pages[_currentPage].chapter.title} · Page ${_currentPage + 1} of ${pages.length}',
                        key: const ValueKey('reader-page-indicator'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _ensurePagination(ReaderLayout layout) {
    final key = layout.paginationCacheKey;
    if (_requestedLayoutKey == key) return;
    _requestedLayoutKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedLayoutKey == key) {
        unawaited(_paginate(layout));
      }
    });
  }

  Future<void> _paginate(ReaderLayout layout) async {
    final generation = ++_generation;
    final previousPages = _pages;
    final target = previousPages != null && previousPages.isNotEmpty
        ? ReadingLocator(anchor: previousPages[_currentPage].boundary.start)
        : widget.initialLocator;
    setState(() {
      _paginationError = null;
      _activeLayoutKey = null;
    });

    try {
      final chapters = [...widget.chapters]
        ..sort((left, right) => left.order.compareTo(right.order));
      final pages = <_BookPage>[];
      for (final chapter in chapters) {
        final result = _engine.paginate(
          chapter: chapter,
          layout: layout,
          measurer: _measurer,
        );
        for (final boundary in result.pages) {
          pages.add(_BookPage(chapter: chapter, boundary: boundary));
        }
        await Future<void>.delayed(Duration.zero);
        if (!mounted || generation != _generation) return;
      }

      final initialPage = _pageForLocator(pages, target);
      final oldController = _pageController;
      final controller = PageController(initialPage: initialPage);
      setState(() {
        _pages = List.unmodifiable(pages);
        _pageController = controller;
        _currentPage = initialPage;
        _activeLayoutKey = layout.paginationCacheKey;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController?.dispose();
        if (mounted && pages.isNotEmpty && generation == _generation) {
          widget.onPositionChanged(pages[initialPage].boundary.start);
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _pages = const [];
        _paginationError = error;
        _activeLayoutKey = layout.paginationCacheKey;
      });
    }
  }

  void _showPage(int index) {
    final pages = _pages;
    if (pages == null || index < 0 || index >= pages.length) return;
    setState(() => _currentPage = index);
    widget.onPositionChanged(pages[index].boundary.start);
  }

  static int _pageForLocator(List<_BookPage> pages, ReadingLocator? locator) {
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
      if (_isAtOrAfter(pages[index].chapter, anchor, start)) return index;
    }
    return chapterPages.first;
  }

  static bool _contains(_BookPage page, TextAnchor anchor) {
    final boundary = page.boundary;
    return _isAtOrAfter(page.chapter, anchor, boundary.start) &&
        _isBefore(page.chapter, anchor, boundary.end);
  }

  static bool _isAtOrAfter(
    Chapter chapter,
    TextAnchor anchor,
    TextAnchor position,
  ) {
    final comparison = _compare(chapter, anchor, position);
    return comparison >= 0;
  }

  static bool _isBefore(
    Chapter chapter,
    TextAnchor anchor,
    TextAnchor position,
  ) {
    return _compare(chapter, anchor, position) < 0;
  }

  static int _compare(Chapter chapter, TextAnchor left, TextAnchor right) {
    final blocks = [...chapter.blocks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final leftIndex = blocks.indexWhere((block) => block.id == left.blockId);
    final rightIndex = blocks.indexWhere((block) => block.id == right.blockId);
    if (leftIndex != rightIndex) return leftIndex.compareTo(rightIndex);
    return left.startOffset.compareTo(right.startOffset);
  }
}

final class _BookPage {
  const _BookPage({required this.chapter, required this.boundary});

  final Chapter chapter;
  final PageBoundary boundary;
}

class _ReaderPageContent extends StatelessWidget {
  const _ReaderPageContent({
    required this.page,
    required this.layout,
    required this.measurer,
    super.key,
  });

  final _BookPage page;
  final ReaderLayout layout;
  final FlutterContentMeasurer measurer;

  @override
  Widget build(BuildContext context) {
    final blocks = [...page.chapter.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    final startIndex = blocks.indexWhere(
      (block) => block.id == page.boundary.start.blockId,
    );
    final endIndex = blocks.indexWhere(
      (block) => block.id == page.boundary.end.blockId,
    );
    if (startIndex < 0 || endIndex < startIndex) {
      return const Center(child: Text('This page could not be displayed.'));
    }

    final fragments = <Widget>[];
    for (var index = startIndex; index <= endIndex; index++) {
      final block = blocks[index];
      final startOffset = index == startIndex
          ? page.boundary.start.startOffset
          : 0;
      final endOffset = index == endIndex
          ? page.boundary.end.startOffset
          : measurer.sourceLength(block);
      if (endOffset <= startOffset) continue;
      fragments.add(
        _BlockFragment(
          block: block,
          startOffset: startOffset,
          endOffset: endOffset,
          layout: layout,
          measurer: measurer,
        ),
      );
    }

    final margins = layout.settings.margins;
    return ClipRect(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margins.left,
          margins.top,
          margins.right,
          margins.bottom,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fragments.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                fragments[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockFragment extends StatelessWidget {
  const _BlockFragment({
    required this.block,
    required this.startOffset,
    required this.endOffset,
    required this.layout,
    required this.measurer,
  });

  final ContentBlock block;
  final int startOffset;
  final int endOffset;
  final ReaderLayout layout;
  final FlutterContentMeasurer measurer;

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    if (block is ImageBlock) {
      return SizedBox(
        height: math.min(
          FlutterContentMeasurer.imagePlaceholderHeight,
          layout.contentHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(block.caption ?? block.altText ?? 'Book image'),
            ),
          ),
        ),
      );
    }

    final span = measurer.textSpanForRange(
      block: block,
      settings: layout.settings,
      startOffset: startOffset,
      endOffset: endOffset,
    );
    final text = RichText(
      text: TextSpan(
        style: TextStyle(color: DefaultTextStyle.of(context).style.color),
        children: [span],
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(layout.textScale),
    );
    if (block is QuoteBlock) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: FlutterContentMeasurer.quoteInset,
          ),
          child: text,
        ),
      );
    }
    return text;
  }
}
