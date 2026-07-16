import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/use_cases/paginate_chapter.dart';
import 'package:flow_reading/ui/features/reader/view_models/flutter_content_measurer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const measurer = FlutterContentMeasurer();
  const engine = PaginationEngine();

  test('paginates styled Unicode text at contiguous source offsets', () {
    const text = 'Read 😀 carefully. Read 😀 carefully. Read 😀 carefully.';
    final result = engine.paginate(
      chapter: _chapter([
        ParagraphBlock(
          id: 'paragraph',
          chapterId: 'chapter',
          order: 0,
          spans: const [
            InlineTextSpan(text: 'Read 😀 ', bold: true),
            InlineTextSpan(
              text: 'carefully. Read 😀 carefully. Read 😀 carefully.',
            ),
          ],
        ),
      ]),
      layout: _layout(width: 120, height: 65),
      measurer: measurer,
    );

    expect(result.pages.length, greaterThan(1));
    expect(result.pages.first.start.startOffset, 0);
    expect(result.pages.last.end.startOffset, text.length);
    for (var index = 1; index < result.pages.length; index++) {
      expect(
        result.pages[index - 1].end.startOffset,
        result.pages[index].start.startOffset,
      );
    }
    for (final page in result.pages) {
      final offset = page.end.startOffset;
      if (offset > 0 && offset < text.length) {
        expect(_splitsSurrogatePair(text, offset), isFalse);
      }
    }
  });

  test('nested lists have deterministic source coverage and can split', () {
    const list = ListBlock(
      id: 'list',
      chapterId: 'chapter',
      order: 0,
      ordered: true,
      items: [
        BookListItem(
          spans: [InlineTextSpan(text: 'First item with enough text to wrap')],
          children: [
            BookListItem(spans: [InlineTextSpan(text: 'Nested item')]),
          ],
        ),
        BookListItem(spans: [InlineTextSpan(text: 'Second item')]),
      ],
    );
    final result = engine.paginate(
      chapter: _chapter(const [list]),
      layout: _layout(width: 130, height: 70),
      measurer: measurer,
    );

    expect(result.pages.length, greaterThan(1));
    expect(result.pages.first.start.startOffset, 0);
    expect(result.pages.last.end.startOffset, measurer.sourceLength(list));
  });

  test('mixed block types preserve order and atomic image placement', () {
    const image = ImageBlock(
      id: 'image',
      chapterId: 'chapter',
      order: 1,
      assetId: 'asset',
    );
    final result = engine.paginate(
      chapter: _chapter([
        _paragraph('before', 'A short paragraph.', 0),
        image,
        const QuoteBlock(
          id: 'after',
          chapterId: 'chapter',
          order: 2,
          spans: [InlineTextSpan(text: 'After image.')],
        ),
      ]),
      layout: _layout(width: 220, height: 170),
      measurer: measurer,
    );

    expect(result.pages.length, greaterThanOrEqualTo(2));
    final imagePage = result.pages.singleWhere(
      (page) => page.start.blockId == 'image' || page.end.blockId == 'image',
    );
    expect(imagePage.start.blockId, 'image');
    expect(imagePage.start.startOffset, 0);
    expect(imagePage.end.startOffset, 1);
  });

  test('smaller viewport and larger type produce more pages and new keys', () {
    final chapter = _chapter([_paragraph('paragraph', 'word ' * 120, 0)]);
    final large = _layout(width: 260, height: 320);
    final small = _layout(
      width: 180,
      height: 180,
      settings: ReaderSettings(
        fontSize: 24,
        margins: ReaderMargins(left: 0, top: 0, right: 0, bottom: 0),
      ),
    );

    final largeResult = engine.paginate(
      chapter: chapter,
      layout: large,
      measurer: measurer,
    );
    final smallResult = engine.paginate(
      chapter: chapter,
      layout: small,
      measurer: measurer,
    );

    expect(smallResult.pages.length, greaterThan(largeResult.pages.length));
    expect(smallResult.layoutKey, isNot(largeResult.layoutKey));
  });

  test('image height is capped to the usable viewport', () {
    const image = ImageBlock(
      id: 'image',
      chapterId: 'chapter',
      order: 0,
      assetId: 'asset',
    );
    final layout = _layout(width: 100, height: 80);
    final measurement = measurer.measure(
      block: image,
      startOffset: 0,
      maxWidth: layout.contentWidth,
      maxHeight: layout.contentHeight,
      layout: layout,
    );

    expect(measurement.endOffset, 1);
    expect(measurement.height, layout.contentHeight);
  });
}

bool _splitsSurrogatePair(String text, int offset) {
  final previous = text.codeUnitAt(offset - 1);
  final next = text.codeUnitAt(offset);
  return previous >= 0xD800 &&
      previous <= 0xDBFF &&
      next >= 0xDC00 &&
      next <= 0xDFFF;
}

ReaderLayout _layout({
  required double width,
  required double height,
  ReaderSettings? settings,
}) => ReaderLayout(
  settings:
      settings ??
      ReaderSettings(
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
