import 'dart:math' as math;

import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/use_cases/paginate_chapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = PaginationEngine(blockSpacing: 0);

  test('empty chapter produces no temporary pages', () {
    final result = engine.paginate(
      chapter: _chapter(const []),
      layout: _layout(),
      measurer: const _FixedMeasurer(),
    );

    expect(result.pages, isEmpty);
  });

  test('short blocks share a page in canonical order', () {
    final result = engine.paginate(
      chapter: _chapter([
        _paragraph('second', 'BBBB', 1),
        _paragraph('first', 'AAAA', 0),
      ]),
      layout: _layout(height: 100),
      measurer: const _FixedMeasurer(),
    );

    expect(result.pages, hasLength(1));
    expect(result.pages.single.start.blockId, 'first');
    expect(result.pages.single.end.blockId, 'second');
    expect(result.pages.single.end.startOffset, 4);
  });

  test('long block splits with contiguous stable offsets', () {
    final result = engine.paginate(
      chapter: _chapter([_paragraph('long', 'abcdefghijkl', 0)]),
      layout: _layout(height: 50),
      measurer: const _FixedMeasurer(unitHeight: 10),
    );

    expect(result.pages, hasLength(3));
    expect(result.pages.map((page) => page.start.startOffset), [0, 4, 8]);
    expect(result.pages.map((page) => page.end.startOffset), [4, 8, 12]);
    expect(
      result.pages.every((page) => page.layoutKey == result.layoutKey),
      isTrue,
    );
  });

  test('unusable viewport and non-progressing measurement are rejected', () {
    expect(
      () => engine.paginate(
        chapter: _chapter([_paragraph('block', 'text', 0)]),
        layout: ReaderLayout(
          settings: ReaderSettings(margins: ReaderMargins(left: 64, right: 64)),
          viewportWidth: 100,
          viewportHeight: 100,
        ),
        measurer: const _FixedMeasurer(),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.paginate(
        chapter: _chapter([_paragraph('block', 'text', 0)]),
        layout: _layout(height: 5),
        measurer: const _FixedMeasurer(unitHeight: 10),
      ),
      throwsArgumentError,
    );
  });
}

final class _FixedMeasurer implements ContentMeasurer {
  const _FixedMeasurer({this.unitHeight = 10});

  final double unitHeight;

  @override
  int sourceLength(ContentBlock block) => switch (block) {
    ParagraphBlock() => block.text.length,
    HeadingBlock() => block.text.length,
    QuoteBlock() => block.text.length,
    ListBlock() => block.items.fold(
      0,
      (sum, item) => sum + item.text.length + 1,
    ),
    ImageBlock() => 1,
  };

  @override
  BlockMeasurement measure({
    required ContentBlock block,
    required int startOffset,
    required double maxWidth,
    required double maxHeight,
    required ReaderLayout layout,
  }) {
    final capacity = maxHeight ~/ unitHeight;
    if (capacity == 0) {
      return BlockMeasurement(endOffset: startOffset, height: 0);
    }
    final end = math.min(sourceLength(block), startOffset + capacity);
    return BlockMeasurement(
      endOffset: end,
      height: (end - startOffset) * unitHeight,
    );
  }
}

ReaderLayout _layout({double width = 300, double height = 300}) => ReaderLayout(
  settings: ReaderSettings(
    margins: ReaderMargins(left: 0, top: 0, right: 0, bottom: 0),
  ),
  viewportWidth: width,
  viewportHeight: height,
);

Chapter _chapter(List<ContentBlock> blocks) => Chapter(
  id: 'chapter',
  bookId: 'book',
  title: 'Chapter',
  order: 0,
  blocks: blocks,
);

ParagraphBlock _paragraph(String id, String text, int order) => ParagraphBlock(
  id: id,
  chapterId: 'chapter',
  order: order,
  spans: [InlineTextSpan(text: text)],
);
