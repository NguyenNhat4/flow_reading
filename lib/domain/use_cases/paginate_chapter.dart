import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';

final class PageBoundary {
  const PageBoundary({
    required this.pageIndex,
    required this.start,
    required this.end,
    required this.layoutKey,
  });

  final int pageIndex;
  final TextAnchor start;
  final TextAnchor end;
  final String layoutKey;
}

final class PaginationResult {
  const PaginationResult({
    required this.chapterId,
    required this.layoutKey,
    required this.pages,
  });

  final String chapterId;
  final String layoutKey;
  final List<PageBoundary> pages;
}

final class BlockMeasurement {
  const BlockMeasurement({required this.endOffset, required this.height});

  final int endOffset;
  final double height;
}

abstract interface class ContentMeasurer {
  int sourceLength(ContentBlock block);

  BlockMeasurement measure({
    required ContentBlock block,
    required int startOffset,
    required double maxWidth,
    required double maxHeight,
    required ReaderLayout layout,
  });
}

final class PaginationEngine {
  const PaginationEngine({this.blockSpacing = 16});

  final double blockSpacing;

  static double usableContentHeight(ReaderLayout layout) =>
      layout.contentHeight;

  PaginationResult paginate({
    required Chapter chapter,
    required ReaderLayout layout,
    required ContentMeasurer measurer,
  }) {
    final contentHeight = usableContentHeight(layout);
    if (layout.contentWidth <= 0 || contentHeight <= 0) {
      throw ArgumentError('Reader margins leave no usable viewport.');
    }
    if (!blockSpacing.isFinite || blockSpacing < 0) {
      throw ArgumentError.value(
        blockSpacing,
        'blockSpacing',
        'must be finite and non-negative',
      );
    }

    final blocks = [...chapter.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    final pages = <PageBoundary>[];
    TextAnchor? pageStart;
    TextAnchor? pageEnd;
    var usedHeight = 0.0;

    void finishPage() {
      final start = pageStart;
      final end = pageEnd;
      if (start == null || end == null) return;
      pages.add(
        PageBoundary(
          pageIndex: pages.length,
          start: start,
          end: end,
          layoutKey: layout.paginationCacheKey,
        ),
      );
      pageStart = null;
      pageEnd = null;
      usedHeight = 0;
    }

    for (final block in blocks) {
      final sourceLength = measurer.sourceLength(block);
      if (sourceLength < 0) {
        throw StateError('Content measurer returned a negative source length.');
      }
      if (sourceLength == 0) continue;

      var offset = 0;
      while (offset < sourceLength) {
        final spacing = pageStart != null && offset == 0 ? blockSpacing : 0.0;
        final availableHeight = contentHeight - usedHeight - spacing;
        final measurement = availableHeight > 0
            ? measurer.measure(
                block: block,
                startOffset: offset,
                maxWidth: layout.contentWidth,
                maxHeight: availableHeight,
                layout: layout,
              )
            : BlockMeasurement(endOffset: offset, height: 0);

        if (measurement.endOffset == offset) {
          if (pageStart != null) {
            finishPage();
            continue;
          }
          throw ArgumentError(
            'The viewport is too small to fit content from block ${block.id}.',
          );
        }
        if (measurement.endOffset < offset ||
            measurement.endOffset > sourceLength ||
            !measurement.height.isFinite ||
            measurement.height <= 0 ||
            measurement.height > availableHeight + 0.001) {
          throw StateError('Content measurer returned an invalid fragment.');
        }

        if (spacing > 0) usedHeight += spacing;
        pageStart ??= _anchor(chapter, block, offset);
        pageEnd = _anchor(chapter, block, measurement.endOffset);
        usedHeight += measurement.height;
        offset = measurement.endOffset;

        if (offset < sourceLength) finishPage();
      }
    }
    finishPage();

    return PaginationResult(
      chapterId: chapter.id,
      layoutKey: layout.paginationCacheKey,
      pages: List.unmodifiable(pages),
    );
  }

  static TextAnchor _anchor(Chapter chapter, ContentBlock block, int offset) {
    return TextAnchor(
      bookId: chapter.bookId,
      chapterId: chapter.id,
      blockId: block.id,
      startOffset: offset,
      endOffset: offset,
    );
  }
}
